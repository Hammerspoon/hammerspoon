#import "SentrySessionReplayIntegration+Private.h"

#if SENTRY_TARGET_REPLAY_SUPPORTED

#    import "SentryClient+Private.h"
#    import "SentryDependencyContainer.h"
#    import "SentryDispatchQueueWrapper.h"
#    import "SentryDisplayLinkWrapper.h"
#    import "SentryEvent+Private.h"
#    import "SentryFileManager.h"
#    import "SentryGlobalEventProcessor.h"
#    import "SentryHub+Private.h"
#    import "SentryLog.h"
#    import "SentryNSNotificationCenterWrapper.h"
#    import "SentryOptions.h"
#    import "SentryRandom.h"
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

/**
 * We need to use this from the swizzled block
 * and using an instance property would hold reference
 * and leak memory.
 */
static SentryTouchTracker *_touchTracker;

@interface
SentrySessionReplayIntegration () <SentryReachabilityObserver>
- (void)newSceneActivate;
@end

@implementation SentrySessionReplayIntegration {
    BOOL _startedAsFullSession;
    SentryReplayOptions *_replayOptions;
    SentryNSNotificationCenterWrapper *_notificationCenter;
    SentryOnDemandReplay *_resumeReplayMaker;
}

- (BOOL)installWithOptions:(nonnull SentryOptions *)options
{
    if ([super installWithOptions:options] == NO) {
        return NO;
    }

    _replayOptions = options.experimental.sessionReplay;

    if (options.enableSwizzling) {
        _touchTracker = [[SentryTouchTracker alloc]
            initWithDateProvider:SentryDependencyContainer.sharedInstance.dateProvider
                           scale:options.experimental.sessionReplay.sizeScale];
        [self swizzleApplicationTouch];
    }

    _notificationCenter = SentryDependencyContainer.sharedInstance.notificationCenterWrapper;

    [SentrySDK.currentHub registerSessionListener:self];

    [SentryGlobalEventProcessor.shared
        addEventProcessor:^SentryEvent *_Nullable(SentryEvent *_Nonnull event) {
            if (event.isCrashEvent) {
                [self resumePreviousSessionReplay:event];
            } else {
                [self.sessionReplay captureReplayForEvent:event];
            }
            return event;
        }];

    [SentryDependencyContainer.sharedInstance.reachability addObserver:self];
    [SentryViewPhotographer.shared addIgnoreClasses:_replayOptions.ignoreRedactViewTypes];
    [SentryViewPhotographer.shared addRedactClasses:_replayOptions.redactViewTypes];

    return YES;
}

/**
 * Send the cached frames from a previous session that eventually crashed.
 * This function is called when processing an event created by SentryCrashIntegration,
 * which runs in the background. That's why we don't need to dispatch the generation of the
 * replay to the background in this function.
 */
- (void)resumePreviousSessionReplay:(SentryEvent *)event
{
    NSURL *dir = [self replayDirectory];
    NSData *lastReplay =
        [NSData dataWithContentsOfURL:[dir URLByAppendingPathComponent:@"lastreplay"]];
    if (lastReplay == nil) {
        return;
    }

    NSDictionary<NSString *, id> *jsonObject =
        [SentrySerialization deserializeDictionaryFromJsonData:lastReplay];
    if (jsonObject == nil) {
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
        float errorSampleRate = [jsonObject[@"errorSampleRate"] floatValue];
        if ([SentryDependencyContainer.sharedInstance.random nextNumber] >= errorSampleRate) {
            return;
        }
    }

    SentryOnDemandReplay *resumeReplayMaker =
        [[SentryOnDemandReplay alloc] initWithContentFrom:lastReplayURL.path];
    resumeReplayMaker.bitRate = _replayOptions.replayBitRate;
    resumeReplayMaker.videoScale = _replayOptions.sizeScale;

    NSDate *beginning = hasCrashInfo
        ? [NSDate dateWithTimeIntervalSinceReferenceDate:crashInfo.lastSegmentEnd]
        : [resumeReplayMaker oldestFrameDate];

    if (beginning == nil) {
        return; // no frames to send
    }

    SentryReplayType _type = type;
    int _segmentId = segmentId;

    NSError *error;
    NSArray<SentryVideoInfo *> *videos =
        [resumeReplayMaker createVideoWithBeginning:beginning
                                                end:[beginning dateByAddingTimeInterval:duration]
                                              error:&error];
    if (videos == nil) {
        SENTRY_LOG_ERROR(@"Could not create replay video: %@", error);
        return;
    }
    for (SentryVideoInfo *video in videos) {
        [self captureVideo:video replayId:replayId segmentId:_segmentId++ type:_type];
        // type buffer is only for the first segment
        _type = SentryReplayTypeSession;
    }

    NSMutableDictionary *eventContext = event.context.mutableCopy;
    eventContext[@"replay"] =
        [NSDictionary dictionaryWithObjectsAndKeys:replayId.sentryIdString, @"replay_id", nil];
    event.context = eventContext;
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
    [self.sessionReplay stop];

    _startedAsFullSession = [self shouldReplayFullSession:_replayOptions.sessionSampleRate];

    if (!_startedAsFullSession && _replayOptions.onErrorSampleRate == 0) {
        return;
    }

    if (SentryDependencyContainer.sharedInstance.application.windows.count > 0) {
        // If a window its already available start replay right away
        [self startWithOptions:_replayOptions fullSession:_startedAsFullSession];
    } else {
        // Wait for a scene to be available to started the replay
        if (@available(iOS 13.0, tvOS 13.0, *)) {
            [_notificationCenter addObserver:self
                                    selector:@selector(newSceneActivate)
                                        name:UISceneDidActivateNotification];
        }
    }
}

- (void)newSceneActivate
{
    [SentryDependencyContainer.sharedInstance.notificationCenterWrapper removeObserver:self];
    [self startWithOptions:_replayOptions fullSession:_startedAsFullSession];
}

- (void)startWithOptions:(SentryReplayOptions *)replayOptions
             fullSession:(BOOL)shouldReplayFullSession
{
    [self startWithOptions:replayOptions
         screenshotProvider:SentryViewPhotographer.shared
        breadcrumbConverter:[[SentrySRDefaultBreadcrumbConverter alloc] init]
                fullSession:shouldReplayFullSession];
}

- (void)startWithOptions:(SentryReplayOptions *)replayOptions
      screenshotProvider:(id<SentryViewScreenshotProvider>)screenshotProvider
     breadcrumbConverter:(id<SentryReplayBreadcrumbConverter>)breadcrumbConverter
             fullSession:(BOOL)shouldReplayFullSession
{
    NSURL *docs = [self replayDirectory];
    NSString *currentSession = [NSUUID UUID].UUIDString;
    docs = [docs URLByAppendingPathComponent:currentSession];

    if (![NSFileManager.defaultManager fileExistsAtPath:docs.path]) {
        [NSFileManager.defaultManager createDirectoryAtURL:docs
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:nil];
    }

    SentryOnDemandReplay *replayMaker = [[SentryOnDemandReplay alloc] initWithOutputPath:docs.path];
    replayMaker.bitRate = replayOptions.replayBitRate;
    replayMaker.videoScale = replayOptions.sizeScale;
    replayMaker.cacheMaxSize
        = (NSInteger)(shouldReplayFullSession ? replayOptions.sessionSegmentDuration + 1
                                              : replayOptions.errorReplayDuration + 1);

    self.sessionReplay = [[SentrySessionReplay alloc]
        initWithReplayOptions:replayOptions
             replayFolderPath:docs
           screenshotProvider:screenshotProvider
                  replayMaker:replayMaker
          breadcrumbConverter:breadcrumbConverter
                 touchTracker:_touchTracker
                 dateProvider:SentryDependencyContainer.sharedInstance.dateProvider
                     delegate:self
                dispatchQueue:[[SentryDispatchQueueWrapper alloc] init]
           displayLinkWrapper:[[SentryDisplayLinkWrapper alloc] init]];

    [self.sessionReplay
        startWithRootView:SentryDependencyContainer.sharedInstance.application.windows.firstObject
              fullSession:[self shouldReplayFullSession:replayOptions.sessionSampleRate]];

    [_notificationCenter addObserver:self
                            selector:@selector(stop)
                                name:UIApplicationDidEnterBackgroundNotification
                              object:nil];

    [_notificationCenter addObserver:self
                            selector:@selector(resume)
                                name:UIApplicationWillEnterForegroundNotification
                              object:nil];

    [self saveCurrentSessionInfo:self.sessionReplay.sessionReplayId
                            path:docs.path
                         options:replayOptions];
}

- (NSURL *)replayDirectory
{
    NSURL *dir =
        [NSURL fileURLWithPath:[SentryDependencyContainer.sharedInstance.fileManager sentryPath]];
    return [dir URLByAppendingPathComponent:SENTRY_REPLAY_FOLDER];
}

- (void)saveCurrentSessionInfo:(SentryId *)sessionId
                          path:(NSString *)path
                       options:(SentryReplayOptions *)options
{
    NSDictionary *info = [[NSDictionary alloc]
        initWithObjectsAndKeys:sessionId.sentryIdString, @"replayId", path.lastPathComponent,
        @"path", @(options.onErrorSampleRate), @"errorSampleRate", nil];

    NSData *data = [SentrySerialization dataWithJSONObject:info];

    NSString *infoPath =
        [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"lastreplay"];
    if ([NSFileManager.defaultManager fileExistsAtPath:infoPath]) {
        [NSFileManager.defaultManager removeItemAtPath:infoPath error:nil];
    }
    [data writeToFile:infoPath atomically:YES];

    sentrySessionReplaySync_start([[path stringByAppendingPathComponent:@"crashInfo"]
        cStringUsingEncoding:NSUTF8StringEncoding]);
}

- (void)stop
{
    [self.sessionReplay stop];
}

- (void)resume
{
    [self.sessionReplay resume];
}

- (void)sentrySessionEnded:(SentrySession *)session
{
    [self stop];
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
    [self startSession];
}

- (BOOL)captureReplay
{
    return [self.sessionReplay captureReplay];
}

- (void)configureReplayWith:(nullable id<SentryReplayBreadcrumbConverter>)breadcrumbConverter
         screenshotProvider:(nullable id<SentryViewScreenshotProvider>)screenshotProvider
{
    if (breadcrumbConverter) {
        self.sessionReplay.breadcrumbConverter = breadcrumbConverter;
    }

    if (screenshotProvider) {
        self.sessionReplay.screenshotProvider = screenshotProvider;
    }
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableReplay;
}

- (void)uninstall
{
    [SentrySDK.currentHub unregisterSessionListener:self];
    _touchTracker = nil;
    [self stop];
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

#    if TEST || TESTCI
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
    return [[SentryRRWebSpanEvent alloc] initWithTimestamp:timestamp
                                              endTimestamp:endTimestamp
                                                 operation:operation
                                               description:description
                                                      data:data];
}

+ (id<SentryReplayBreadcrumbConverter>)createDefaultBreadcrumbConverter
{
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
    [SentrySDK.currentHub captureReplayEvent:replayEvent
                             replayRecording:replayRecording
                                       video:videoUrl];

    sentrySessionReplaySync_updateInfo(
        (unsigned int)replayEvent.segmentId, replayEvent.timestamp.timeIntervalSinceReferenceDate);
}

- (void)sessionReplayStartedWithReplayId:(SentryId *)replayId
{
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

#    pragma mark - SentryReachabilityObserver

- (void)connectivityChanged:(BOOL)connected typeDescription:(nonnull NSString *)typeDescription
{

    if (connected) {
        [_sessionReplay resume];
    } else {
        [_sessionReplay pause];
    }
}

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
