#import "SentrySessionReplayIntegration+Private.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

#    import "SentryClient+Private.h"
#    import "SentryCrashWrapper.h"
#    import "SentryDependencyContainer.h"
#    import "SentryDispatchQueueProviderProtocol.h"
#    import "SentryDisplayLinkWrapper.h"
#    import "SentryEvent+Private.h"
#    import "SentryFileManager.h"
#    import "SentryGlobalEventProcessor.h"
#    import "SentryHub+Private.h"
#    import "SentryLogC.h"
#    import "SentryNSNotificationCenterWrapper.h"
#    import "SentryOptions.h"
#    import "SentryRandom.h"
#    import "SentryRateLimits.h"
#    import "SentryReachability.h"
#    import "SentrySDK+Private.h"
#    import "SentryScope+Private.h"
#    import "SentrySerialization.h"
#    import "SentrySessionReplaySyncC.h"
#    import "SentrySwift.h"
#    import "SentrySwizzle.h"
#    import "SentryUIApplication.h"
#    import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *SENTRY_REPLAY_FOLDER = @"replay";
static NSString *SENTRY_CURRENT_REPLAY = @"replay.current";
static NSString *SENTRY_LAST_REPLAY = @"replay.last";

@interface SentryDisplayLinkWrapper (Replay) <SentryReplayDisplayLinkWrapper>

@end

/**
 * We need to use this from the swizzled block
 * and using an instance property would hold reference
 * and leak memory.
 */
static SentryTouchTracker *_touchTracker;

@interface SentrySessionReplayIntegration () <SentryReachabilityObserver, SentrySessionListener,
    SentrySessionReplayDelegate>

@property (nonatomic, strong) SentryDispatchQueueWrapper *replayProcessingQueue;
@property (nonatomic, strong) SentryDispatchQueueWrapper *replayAssetWorkerQueue;

- (void)newSceneActivate;

@end

@implementation SentrySessionReplayIntegration {
    BOOL _startedAsFullSession;
    SentryReplayOptions *_replayOptions;
    SentryNSNotificationCenterWrapper *_notificationCenter;
    id<SentryRateLimits> _rateLimits;
    id<SentryViewScreenshotProvider> _currentScreenshotProvider;
    id<SentryReplayBreadcrumbConverter> _currentBreadcrumbConverter;
    SentryMaskingPreviewView *_previewView;
    // We need to use this variable to identify whether rate limiting was ever activated for session
    // replay in this session, instead of always looking for the rate status in `SentryRateLimits`
    // This is the easiest way to ensure segment 0 will always reach the server, because session
    // replay absolutely needs segment 0 to make replay work.
    BOOL _rateLimited;
    id<SentryCurrentDateProvider> _dateProvider;
}

- (instancetype)init
{
    self = [super init];
    return self;
}

- (instancetype)initForManualUse:(nonnull SentryOptions *)options
{
    if (self = [super init]) {
        [self setupWith:options.sessionReplay
                 enableTouchTracker:options.enableSwizzling
               enableViewRendererV2:options.sessionReplay.enableViewRendererV2
            enableFastViewRendering:options.sessionReplay.enableFastViewRendering];
        [self startWithOptions:options.sessionReplay fullSession:YES];
    }
    return self;
}

- (BOOL)installWithOptions:(nonnull SentryOptions *)options
{
    if ([super installWithOptions:options] == NO) {
        return NO;
    }

    [self setupWith:options.sessionReplay
             enableTouchTracker:options.enableSwizzling
           enableViewRendererV2:options.sessionReplay.enableViewRendererV2
        enableFastViewRendering:options.sessionReplay.enableFastViewRendering];
    return YES;
}

- (void)setupWith:(SentryReplayOptions *)replayOptions
         enableTouchTracker:(BOOL)touchTracker
       enableViewRendererV2:(BOOL)enableViewRendererV2
    enableFastViewRendering:(BOOL)enableFastViewRendering
{
    _replayOptions = replayOptions;
    _rateLimits = SentryDependencyContainer.sharedInstance.rateLimits;
    _dateProvider = SentryDependencyContainer.sharedInstance.dateProvider;

    id<SentryViewRenderer> viewRenderer;
    if (enableViewRendererV2) {
        SENTRY_LOG_DEBUG(@"[Session Replay] Setting up view renderer v2, fast view rendering: %@",
            enableFastViewRendering ? @"YES" : @"NO");
        viewRenderer =
            [[SentryViewRendererV2 alloc] initWithEnableFastViewRendering:enableFastViewRendering];
    } else {
        SENTRY_LOG_DEBUG(@"[Session Replay] Setting up default view renderer");
        viewRenderer = [[SentryDefaultViewRenderer alloc] init];
    }

    // We are using the flag for the view renderer V2 also for the mask renderer V2, as it would
    // just introduce another option without affecting the SDK user experience.
    _viewPhotographer = [[SentryViewPhotographer alloc] initWithRenderer:viewRenderer
                                                           redactOptions:replayOptions
                                                    enableMaskRendererV2:enableViewRendererV2];

    if (touchTracker) {
        SENTRY_LOG_DEBUG(
            @"[Session Replay] Setting up touch tracker, scale: %f", replayOptions.sizeScale);
        _touchTracker = [[SentryTouchTracker alloc] initWithDateProvider:_dateProvider
                                                                   scale:replayOptions.sizeScale];
        [self swizzleApplicationTouch];
    }

    _notificationCenter = SentryDependencyContainer.sharedInstance.notificationCenterWrapper;
    _dateProvider = SentryDependencyContainer.sharedInstance.dateProvider;

    // We use the dispatch queue provider as a factory to create the queues, but store the queues
    // directly in this instance, so they get deallocated when the integration is deallocated.
    id<SentryDispatchQueueProviderProtocol> dispatchQueueProvider
        = SentryDependencyContainer.sharedInstance.dispatchQueueProvider;

    // The asset worker queue is used to work on video and frames data.
    // Use a relative priority of -1 to make it lower than the default background priority.
    _replayAssetWorkerQueue =
        [dispatchQueueProvider createUtilityQueue:"io.sentry.session-replay.asset-worker"
                                 relativePriority:-1];
    // The dispatch queue is used to asynchronously wait for the asset worker queue to finish its
    // work. To avoid a deadlock, the priority of the processing queue must be lower than the asset
    // worker queue. Use a relative priority of -2 to make it lower than the asset worker queue.
    _replayProcessingQueue =
        [dispatchQueueProvider createUtilityQueue:"io.sentry.session-replay.processing"
                                 relativePriority:-2];

    // The asset worker queue is used to work on video and frames data.

    [self moveCurrentReplay];
    [self cleanUp];

    [SentrySDK.currentHub registerSessionListener:self];
    [SentryDependencyContainer.sharedInstance.globalEventProcessor
        addEventProcessor:^SentryEvent *_Nullable(SentryEvent *_Nonnull event) {
            if (event.isFatalEvent) {
                [self resumePreviousSessionReplay:event];
            } else {
                [self.sessionReplay captureReplayForEvent:event];
            }
            return event;
        }];

    [SentryDependencyContainer.sharedInstance.reachability addObserver:self];
}

- (nullable NSDictionary<NSString *, id> *)lastReplayInfo
{
    NSURL *dir = [self replayDirectory];
    NSURL *lastReplayUrl = [dir URLByAppendingPathComponent:SENTRY_LAST_REPLAY];
    NSData *lastReplay = [NSData dataWithContentsOfURL:lastReplayUrl];

    if (lastReplay == nil) {
        SENTRY_LOG_DEBUG(@"[Session Replay] No last replay info found");
        return nil;
    }

    return [SentrySerialization deserializeDictionaryFromJsonData:lastReplay];
}

/**
 * Send the cached frames from a previous session that eventually crashed.
 * This function is called when processing an event created by SentryCrashIntegration,
 * which runs in the background. That's why we don't need to dispatch the generation of the
 * replay to the background in this function.
 */
- (void)resumePreviousSessionReplay:(SentryEvent *)event
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Resuming previous session replay");
    NSURL *dir = [self replayDirectory];
    NSDictionary<NSString *, id> *jsonObject = [self lastReplayInfo];

    if (jsonObject == nil) {
        SENTRY_LOG_DEBUG(
            @"[Session Replay] No last replay info found, not resuming previous session replay");
        return;
    }

    SentryId *replayId = jsonObject[@"replayId"]
        ? [[SentryId alloc] initWithUUIDString:jsonObject[@"replayId"]]
        : [[SentryId alloc] init];
    NSURL *lastReplayURL = [dir URLByAppendingPathComponent:jsonObject[@"path"]];

    SentryCrashReplay crashInfo = { 0 };
    bool hasCrashInfo = sentrySessionReplaySync_readInfo(&crashInfo,
        [[lastReplayURL URLByAppendingPathComponent:@"crashInfo"].path
            cStringUsingEncoding:NSUTF8StringEncoding]);

    SentryReplayType type = hasCrashInfo ? SentryReplayTypeSession : SentryReplayTypeBuffer;
    NSTimeInterval duration
        = hasCrashInfo ? _replayOptions.sessionSegmentDuration : _replayOptions.errorReplayDuration;
    int segmentId = hasCrashInfo ? crashInfo.segmentId + 1 : 0;

    if (type == SentryReplayTypeBuffer) {
        SENTRY_LOG_DEBUG(
            @"[Session Replay] Previous session replay is a buffer, using error sample rate");
        float errorSampleRate = [jsonObject[@"errorSampleRate"] floatValue];
        if ([SentryDependencyContainer.sharedInstance.random nextNumber] >= errorSampleRate) {
            SENTRY_LOG_INFO(
                @"[Session Replay] Buffer session replay event not sampled, dropping replay");
            return;
        }
    }

    SentryOnDemandReplay *resumeReplayMaker =
        [[SentryOnDemandReplay alloc] initWithContentFrom:lastReplayURL.path
                                          processingQueue:_replayProcessingQueue
                                         assetWorkerQueue:_replayAssetWorkerQueue];
    resumeReplayMaker.bitRate = _replayOptions.replayBitRate;
    resumeReplayMaker.videoScale = _replayOptions.sizeScale;
    resumeReplayMaker.frameRate = _replayOptions.frameRate;

    NSDate *beginning = hasCrashInfo
        ? [NSDate dateWithTimeIntervalSinceReferenceDate:crashInfo.lastSegmentEnd]
        : [resumeReplayMaker oldestFrameDate];
    if (beginning == nil) {
        SENTRY_LOG_DEBUG(@"[Session Replay] No frames to send, dropping replay");
        return; // no frames to send
    }
    NSDate *end = [beginning dateByAddingTimeInterval:duration];

    NSArray<SentryVideoInfo *> *videos = [resumeReplayMaker createVideoWithBeginning:beginning
                                                                                 end:end];
    if (videos == nil) {
        SENTRY_LOG_ERROR(
            @"[Session Replay] Could not create replay video, reason: no videos available");
        return;
    }
    SENTRY_LOG_DEBUG(@"[Session Replay] Created replay with %lu video segments", videos.count);

    // For each segment we need to create a new event with the video.
    int _segmentId = segmentId;
    SentryReplayType _type = type;
    for (SentryVideoInfo *video in videos) {
        [self captureVideo:video replayId:replayId segmentId:_segmentId++ type:_type];
        // type buffer is only for the first segment
        _type = SentryReplayTypeSession;
    }

    NSMutableDictionary *eventContext = event.context.mutableCopy;
    eventContext[@"replay"] =
        [NSDictionary dictionaryWithObjectsAndKeys:replayId.sentryIdString, @"replay_id", nil];
    event.context = eventContext;

    NSError *_Nullable removeError;
    BOOL result = [NSFileManager.defaultManager removeItemAtURL:lastReplayURL error:&removeError];
    if (result == NO) {
        SENTRY_LOG_ERROR(
            @"[Session Replay] Can't delete '%@' with file item at url: '%@', reason: %@",
            SENTRY_LAST_REPLAY, lastReplayURL, removeError);
    } else {
        SENTRY_LOG_DEBUG(@"[Session Replay] Deleted last replay file at path: %@", lastReplayURL);
    }
}

- (void)captureVideo:(SentryVideoInfo *)video
            replayId:(SentryId *)replayId
           segmentId:(int)segment
                type:(SentryReplayType)type
{
    SentryReplayEvent *replayEvent = [[SentryReplayEvent alloc] initWithEventId:replayId
                                                           replayStartTimestamp:video.start
                                                                     replayType:type
                                                                      segmentId:segment];
    replayEvent.timestamp = video.end;
    SentryReplayRecording *recording = [[SentryReplayRecording alloc] initWithSegmentId:segment
                                                                                  video:video
                                                                            extraEvents:@[]];

    [SentrySDK.currentHub captureReplayEvent:replayEvent
                             replayRecording:recording
                                       video:video.path];

    NSError *error = nil;
    if (![[NSFileManager defaultManager] removeItemAtURL:video.path error:&error]) {
        SENTRY_LOG_DEBUG(
            @"Could not delete replay segment from disk: %@", error.localizedDescription);
    }
}

- (void)startSession
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Starting session");
    [self.sessionReplay pause];

    _startedAsFullSession = [self shouldReplayFullSession:_replayOptions.sessionSampleRate];

    if (!_startedAsFullSession && _replayOptions.onErrorSampleRate == 0) {
        SENTRY_LOG_DEBUG(
            @"[Session Replay] Not full session and onErrorSampleRate is 0, not starting session");
        return;
    }

    [self runReplayForAvailableWindow];
}

- (void)runReplayForAvailableWindow
{
    if (SentryDependencyContainer.sharedInstance.application.windows.count > 0) {
        SENTRY_LOG_DEBUG(@"[Session Replay] Running replay for available window");
        // If a window its already available start replay right away
        [self startWithOptions:_replayOptions fullSession:_startedAsFullSession];
    } else if (@available(iOS 13.0, tvOS 13.0, *)) {
        SENTRY_LOG_DEBUG(
            @"[Session Replay] Waiting for a scene to be available to started the replay");
        // Wait for a scene to be available to started the replay
        [_notificationCenter addObserver:self
                                selector:@selector(newSceneActivate)
                                    name:UISceneDidActivateNotification];
    }
}

- (void)newSceneActivate
{
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        SENTRY_LOG_DEBUG(@"[Session Replay] Scene is available, starting replay");
        [SentryDependencyContainer.sharedInstance.notificationCenterWrapper
            removeObserver:self
                      name:UISceneDidActivateNotification];
        [self startWithOptions:_replayOptions fullSession:_startedAsFullSession];
    }
}

- (void)startWithOptions:(SentryReplayOptions *)replayOptions
             fullSession:(BOOL)shouldReplayFullSession
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Starting session");
    [self startWithOptions:replayOptions
         screenshotProvider:_currentScreenshotProvider ?: _viewPhotographer
        breadcrumbConverter:_currentBreadcrumbConverter
            ?: [[SentrySRDefaultBreadcrumbConverter alloc] init]
                fullSession:shouldReplayFullSession];
}

- (void)startWithOptions:(SentryReplayOptions *)replayOptions
      screenshotProvider:(id<SentryViewScreenshotProvider>)screenshotProvider
     breadcrumbConverter:(id<SentryReplayBreadcrumbConverter>)breadcrumbConverter
             fullSession:(BOOL)shouldReplayFullSession
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Starting session");
    NSURL *docs = [self replayDirectory];
    NSString *currentSession = [NSUUID UUID].UUIDString;
    docs = [docs URLByAppendingPathComponent:currentSession];

    if (![NSFileManager.defaultManager fileExistsAtPath:docs.path]) {
        SENTRY_LOG_DEBUG(@"[Session Replay] Creating directory at path: %@", docs.path);
        [NSFileManager.defaultManager createDirectoryAtURL:docs
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:nil];
    }

    SentryOnDemandReplay *replayMaker =
        [[SentryOnDemandReplay alloc] initWithOutputPath:docs.path
                                         processingQueue:_replayProcessingQueue
                                        assetWorkerQueue:_replayAssetWorkerQueue];
    replayMaker.bitRate = replayOptions.replayBitRate;
    replayMaker.videoScale = replayOptions.sizeScale;
    replayMaker.frameRate = replayOptions.frameRate;

    // The cache should be at least the amount of frames fitting into the session segment duration
    // plus one frame to ensure that the last frame is not dropped.
    NSInteger sessionSegmentDuration
        = (NSInteger)(shouldReplayFullSession ? replayOptions.sessionSegmentDuration
                                              : replayOptions.errorReplayDuration);
    replayMaker.cacheMaxSize = (sessionSegmentDuration * replayOptions.frameRate) + 1;

    SentryDisplayLinkWrapper *displayLinkWrapper = [[SentryDisplayLinkWrapper alloc] init];
    self.sessionReplay = [[SentrySessionReplay alloc] initWithReplayOptions:replayOptions
                                                           replayFolderPath:docs
                                                         screenshotProvider:screenshotProvider
                                                                replayMaker:replayMaker
                                                        breadcrumbConverter:breadcrumbConverter
                                                               touchTracker:_touchTracker
                                                               dateProvider:_dateProvider
                                                                   delegate:self
                                                         displayLinkWrapper:displayLinkWrapper];

    [self.sessionReplay
        startWithRootView:SentryDependencyContainer.sharedInstance.application.windows.firstObject
              fullSession:shouldReplayFullSession];

    [_notificationCenter addObserver:self
                            selector:@selector(pause)
                                name:UIApplicationDidEnterBackgroundNotification
                              object:nil];

    [_notificationCenter addObserver:self
                            selector:@selector(resume)
                                name:UIApplicationDidBecomeActiveNotification
                              object:nil];

    [self saveCurrentSessionInfo:self.sessionReplay.sessionReplayId
                            path:docs.path
                         options:replayOptions];
}

- (nullable NSURL *)replayDirectory
{
    NSString *sentryPath = [SentryDependencyContainer.sharedInstance.fileManager sentryPath];
    if (!sentryPath) {
        return nil;
    }
    NSURL *dir = [NSURL fileURLWithPath:sentryPath];
    return [dir URLByAppendingPathComponent:SENTRY_REPLAY_FOLDER];
}

- (void)saveCurrentSessionInfo:(SentryId *)sessionId
                          path:(NSString *)path
                       options:(SentryReplayOptions *)options
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Saving current session info for session: %@ to path: %@",
        sessionId, path);
    NSDictionary *info =
        [[NSDictionary alloc] initWithObjectsAndKeys:sessionId.sentryIdString, @"replayId",
            path.lastPathComponent, @"path", @(options.onErrorSampleRate), @"errorSampleRate", nil];

    NSData *data = [SentrySerialization dataWithJSONObject:info];

    NSString *infoPath = [[path stringByDeletingLastPathComponent]
        stringByAppendingPathComponent:SENTRY_CURRENT_REPLAY];
    if ([NSFileManager.defaultManager fileExistsAtPath:infoPath]) {
        SENTRY_LOG_DEBUG(
            @"[Session Replay] Removing existing current replay info at path: %@", infoPath);
        [NSFileManager.defaultManager removeItemAtPath:infoPath error:nil];
    }
    [data writeToFile:infoPath atomically:YES];

    SENTRY_LOG_DEBUG(@"[Session Replay] Saved current session info at path: %@", infoPath);
    sentrySessionReplaySync_start([[path stringByAppendingPathComponent:@"crashInfo"]
        cStringUsingEncoding:NSUTF8StringEncoding]);
}

- (void)moveCurrentReplay
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Moving current replay");
    NSFileManager *fileManager = NSFileManager.defaultManager;

    NSURL *path = [self replayDirectory];
    NSURL *current = [path URLByAppendingPathComponent:SENTRY_CURRENT_REPLAY];
    NSURL *last = [path URLByAppendingPathComponent:SENTRY_LAST_REPLAY];

    NSError *error;
    if ([fileManager fileExistsAtPath:last.path]) {
        SENTRY_LOG_DEBUG(@"[Session Replay] Removing last replay file at path: %@", last);
        if ([NSFileManager.defaultManager removeItemAtURL:last error:&error] == NO) {
            SENTRY_LOG_ERROR(
                @"[Session Replay] Could not delete last replay file, reason: %@", error);
            return;
        }
        SENTRY_LOG_DEBUG(@"[Session Replay] Removed last replay file at path: %@", last);
    } else {
        SENTRY_LOG_DEBUG(@"[Session Replay] No last replay file to remove at path: %@", last);
    }

    if ([fileManager fileExistsAtPath:current.path]) {
        SENTRY_LOG_DEBUG(
            @"[Session Replay] Moving current replay file at path: %@ to: %@", current, last);
        if ([fileManager moveItemAtURL:current toURL:last error:&error] == NO) {
            SENTRY_LOG_ERROR(@"[Session Replay] Could not move replay file, reason: %@", error);
            return;
        }
        SENTRY_LOG_DEBUG(@"[Session Replay] Moved current replay file at path: %@", current);
    } else {
        SENTRY_LOG_DEBUG(@"[Session Replay] No current replay file to move at path: %@", current);
    }
}

- (void)cleanUp
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Cleaning up");
    NSURL *replayDir = [self replayDirectory];
    NSDictionary<NSString *, id> *lastReplayInfo = [self lastReplayInfo];
    NSString *lastReplayFolder = lastReplayInfo[@"path"];

    SentryFileManager *fileManager = SentryDependencyContainer.sharedInstance.fileManager;
    // Mapping replay folder here and not in dispatched queue to prevent a race condition between
    // listing files and creating a new replay session.
    NSArray *replayFiles = [fileManager allFilesInFolder:replayDir.path];
    if (replayFiles.count == 0) {
        SENTRY_LOG_DEBUG(@"[Session Replay] No replay files to clean up");
        return;
    }

    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchAsyncWithBlock:^{
        for (NSString *file in replayFiles) {
            // Skip the last replay folder.
            if ([file isEqualToString:lastReplayFolder]) {
                SENTRY_LOG_DEBUG(@"[Session Replay] Skipping last replay folder: %@", file);
                continue;
            }

            NSString *filePath = [replayDir.path stringByAppendingPathComponent:file];

            // Check if the file is a directory before deleting it.
            if ([fileManager isDirectory:filePath]) {
                SENTRY_LOG_DEBUG(
                    @"[Session Replay] Removing replay directory at path: %@", filePath);
                [fileManager removeFileAtPath:filePath];
            }
        }
    }];
}

- (void)pause
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Pausing session");
    [self.sessionReplay pause];
}

- (void)resume
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Resuming session");
    [self.sessionReplay resume];
}

- (void)start
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Starting session");
    if (_rateLimited) {
        SENTRY_LOG_WARN(@"[Session Replay] This session was rate limited. Not starting session "
                        @"replay until next app session");
        return;
    }

    if (self.sessionReplay != nil) {
        if (self.sessionReplay.isFullSession == NO) {
            SENTRY_LOG_DEBUG(@"[Session Replay] Not full session, capturing replay");
            [self.sessionReplay captureReplay];
        }
        return;
    }

    _startedAsFullSession = YES;
    [self runReplayForAvailableWindow];
}

- (void)stop
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Stopping session");
    [self.sessionReplay pause];
    self.sessionReplay = nil;
}

- (void)sentrySessionEnded:(SentrySession *)session
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Session ended");
    [self pause];
    [_notificationCenter removeObserver:self
                                   name:UIApplicationDidEnterBackgroundNotification
                                 object:nil];
    [_notificationCenter removeObserver:self
                                   name:UIApplicationWillEnterForegroundNotification
                                 object:nil];
    _sessionReplay = nil;
}

- (void)sentrySessionStarted:(SentrySession *)session
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Session started");
    _rateLimited = NO;
    [self startSession];
}

- (BOOL)captureReplay
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Capturing replay");
    return [self.sessionReplay captureReplay];
}

- (void)configureReplayWith:(nullable id<SentryReplayBreadcrumbConverter>)breadcrumbConverter
         screenshotProvider:(nullable id<SentryViewScreenshotProvider>)screenshotProvider
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Configuring replay");
    if (breadcrumbConverter) {
        _currentBreadcrumbConverter = breadcrumbConverter;
        self.sessionReplay.breadcrumbConverter = breadcrumbConverter;
    }

    if (screenshotProvider) {
        _currentScreenshotProvider = screenshotProvider;
        self.sessionReplay.screenshotProvider = screenshotProvider;
    }
}

- (void)setReplayTags:(NSDictionary<NSString *, id> *)tags
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Setting replay tags: %@", tags);
    self.sessionReplay.replayTags = [tags copy];
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableReplay;
}

- (void)uninstall
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Uninstalling");
    [SentrySDK.currentHub unregisterSessionListener:self];
    _touchTracker = nil;
    [self pause];
}

- (void)dealloc
{
    [self uninstall];
}

- (BOOL)shouldReplayFullSession:(CGFloat)rate
{
    return [SentryDependencyContainer.sharedInstance.random nextNumber] < rate;
}

- (void)swizzleApplicationTouch
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Swizzling application touch tracker");
#    pragma clang diagnostic push
#    pragma clang diagnostic ignored "-Wshadow"
    SEL selector = NSSelectorFromString(@"sendEvent:");
    SentrySwizzleInstanceMethod([UIApplication class], selector, SentrySWReturnType(void),
        SentrySWArguments(UIEvent * event), SentrySWReplacement({
            [_touchTracker trackTouchFromEvent:event];
            SentrySWCallOriginal(event);
        }),
        SentrySwizzleModeOncePerClass, (void *)selector);
#    pragma clang diagnostic pop
}

#    if SENTRY_TEST || SENTRY_TEST_CI
- (SentryTouchTracker *)getTouchTracker
{
    return _touchTracker;
}
#    endif

+ (id<SentryRRWebEvent>)createBreadcrumbwithTimestamp:(NSDate *)timestamp
                                             category:(NSString *)category
                                              message:(nullable NSString *)message
                                                level:(enum SentryLevel)level
                                                 data:(nullable NSDictionary<NSString *, id> *)data
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Creating breadcrumb with timestamp: %@, category: %@, "
                     @"message: %@, level: %lu, data: %@",
        timestamp, category, message, level, data);
    return [[SentryRRWebBreadcrumbEvent alloc] initWithTimestamp:timestamp
                                                        category:category
                                                         message:message
                                                           level:level
                                                            data:data];
}

+ (id<SentryRRWebEvent>)createNetworkBreadcrumbWithTimestamp:(NSDate *)timestamp
                                                endTimestamp:(NSDate *)endTimestamp
                                                   operation:(NSString *)operation
                                                 description:(NSString *)description
                                                        data:(NSDictionary<NSString *, id> *)data
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Creating network breadcrumb with timestamp: %@, "
                     @"endTimestamp: %@, operation: %@, description: %@, data: %@",
        timestamp, endTimestamp, operation, description, data);
    return [[SentryRRWebSpanEvent alloc] initWithTimestamp:timestamp
                                              endTimestamp:endTimestamp
                                                 operation:operation
                                               description:description
                                                      data:data];
}

+ (id<SentryReplayBreadcrumbConverter>)createDefaultBreadcrumbConverter
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Creating default breadcrumb converter");
    return [[SentrySRDefaultBreadcrumbConverter alloc] init];
}

#    pragma mark - SessionReplayDelegate

- (BOOL)sessionReplayShouldCaptureReplayForError
{
    return SentryDependencyContainer.sharedInstance.random.nextNumber
        <= _replayOptions.onErrorSampleRate;
}

- (void)sessionReplayNewSegmentWithReplayEvent:(SentryReplayEvent *)replayEvent
                               replayRecording:(SentryReplayRecording *)replayRecording
                                      videoUrl:(NSURL *)videoUrl
{
    SENTRY_LOG_DEBUG(@"[Session Replay] New segment with replay event, eventId: %@, segmentId: %lu",
        replayEvent.eventId, replayEvent.segmentId);
    if ([_rateLimits isRateLimitActive:kSentryDataCategoryReplay] ||
        [_rateLimits isRateLimitActive:kSentryDataCategoryAll]) {
        SENTRY_LOG_DEBUG(
            @"Rate limiting is active for replays. Stopping session replay until next session.");
        _rateLimited = YES;
        [self stop];
        return;
    }

    [SentrySDK.currentHub captureReplayEvent:replayEvent
                             replayRecording:replayRecording
                                       video:videoUrl];

    sentrySessionReplaySync_updateInfo(
        (unsigned int)replayEvent.segmentId, replayEvent.timestamp.timeIntervalSinceReferenceDate);
}

- (void)sessionReplayStartedWithReplayId:(SentryId *)replayId
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Session replay started with replay id: %@", replayId);
    [SentrySDK.currentHub configureScope:^(
        SentryScope *_Nonnull scope) { scope.replayId = [replayId sentryIdString]; }];
}

- (NSArray<SentryBreadcrumb *> *)breadcrumbsForSessionReplay
{
    __block NSArray<SentryBreadcrumb *> *result;
    [SentrySDK.currentHub
        configureScope:^(SentryScope *_Nonnull scope) { result = scope.breadcrumbs; }];
    return result;
}

- (nullable NSString *)currentScreenNameForSessionReplay
{
    return SentrySDK.currentHub.scope.currentScreen
        ?: [SentryDependencyContainer.sharedInstance.application relevantViewControllersNames]
               .firstObject;
}

- (void)showMaskPreview:(CGFloat)opacity
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Showing mask preview with opacity: %f", opacity);
    if ([SentryDependencyContainer.sharedInstance.crashWrapper isBeingTraced] == NO) {
        SENTRY_LOG_DEBUG(@"[Session Replay] No tracing is active, not showing mask preview");
        return;
    }

    UIWindow *window = SentryDependencyContainer.sharedInstance.application.windows.firstObject;
    if (window == nil) {
        SENTRY_LOG_WARN(@"[Session Replay] No UIWindow available to display preview");
        return;
    }

    if (_previewView == nil) {
        _previewView = [[SentryMaskingPreviewView alloc] initWithRedactOptions:_replayOptions];
    }

    _previewView.opacity = opacity;
    [_previewView setFrame:window.bounds];
    [window addSubview:_previewView];
}

- (void)hideMaskPreview
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Hiding mask preview");
    [_previewView removeFromSuperview];
    _previewView = nil;
}

#    pragma mark - SentryReachabilityObserver

- (void)connectivityChanged:(BOOL)connected typeDescription:(nonnull NSString *)typeDescription
{
    SENTRY_LOG_DEBUG(@"[Session Replay] Connectivity changed to: %@, type: %@",
        connected ? @"connected" : @"disconnected", typeDescription);
    if (connected) {
        [_sessionReplay resume];
    } else {
        [_sessionReplay pauseSessionMode];
    }
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
