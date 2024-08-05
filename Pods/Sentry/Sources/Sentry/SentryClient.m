#import "SentryClient.h"
#import "NSLocale+Sentry.h"
#import "SentryAttachment.h"
#import "SentryClient+Private.h"
#import "SentryCrashDefaultMachineContextWrapper.h"
#import "SentryCrashIntegration.h"
#import "SentryCrashStackEntryMapper.h"
#import "SentryDebugImageProvider.h"
#import "SentryDependencyContainer.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryDsn.h"
#import "SentryEnvelope+Private.h"
#import "SentryEnvelopeItemType.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryExtraContextProvider.h"
#import "SentryFileManager.h"
#import "SentryGlobalEventProcessor.h"
#import "SentryHub+Private.h"
#import "SentryHub.h"
#import "SentryInAppLogic.h"
#import "SentryInstallation.h"
#import "SentryLog.h"
#import "SentryMechanism.h"
#import "SentryMechanismMeta.h"
#import "SentryMessage.h"
#import "SentryMeta.h"
#import "SentryMsgPackSerializer.h"
#import "SentryNSDictionarySanitize.h"
#import "SentryNSError.h"
#import "SentryOptions+Private.h"
#import "SentryPropagationContext.h"
#import "SentryRandom.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"
#import "SentrySerialization.h"
#import "SentrySession.h"
#import "SentryStacktraceBuilder.h"
#import "SentrySwift.h"
#import "SentryThreadInspector.h"
#import "SentryTraceContext.h"
#import "SentryTracer.h"
#import "SentryTransaction.h"
#import "SentryTransport.h"
#import "SentryTransportAdapter.h"
#import "SentryTransportFactory.h"
#import "SentryUIApplication.h"
#import "SentryUser.h"
#import "SentryUserFeedback.h"
#import "SentryWatchdogTerminationTracker.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface
SentryClient ()

@property (nonatomic, strong) SentryTransportAdapter *transportAdapter;
@property (nonatomic, strong) SentryDebugImageProvider *debugImageProvider;
@property (nonatomic, strong) id<SentryRandom> random;
@property (nonatomic, strong) NSLocale *locale;
@property (nonatomic, strong) NSTimeZone *timezone;

@end

NSString *const DropSessionLogMessage = @"Session has no release name. Won't send it.";

@implementation SentryClient

- (_Nullable instancetype)initWithOptions:(SentryOptions *)options
{
    return [self initWithOptions:options
                   dispatchQueue:[[SentryDispatchQueueWrapper alloc] init]
          deleteOldEnvelopeItems:YES];
}

/** Internal constructor for testing purposes. */
- (nullable instancetype)initWithOptions:(SentryOptions *)options
                           dispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue
                  deleteOldEnvelopeItems:(BOOL)deleteOldEnvelopeItems
{
    NSError *error;
    SentryFileManager *fileManager = [[SentryFileManager alloc] initWithOptions:options
                                                           dispatchQueueWrapper:dispatchQueue
                                                                          error:&error];
    if (error != nil) {
        SENTRY_LOG_ERROR(@"Cannot init filesystem.");
        return nil;
    }
    return [self initWithOptions:options
                     fileManager:fileManager
          deleteOldEnvelopeItems:deleteOldEnvelopeItems];
}

/** Internal constructor for testing purposes. */
- (instancetype)initWithOptions:(SentryOptions *)options
                    fileManager:(SentryFileManager *)fileManager
         deleteOldEnvelopeItems:(BOOL)deleteOldEnvelopeItems
{
    NSArray<id<SentryTransport>> *transports = [SentryTransportFactory
             initTransports:options
          sentryFileManager:fileManager
        currentDateProvider:SentryDependencyContainer.sharedInstance.dateProvider];

    SentryTransportAdapter *transportAdapter =
        [[SentryTransportAdapter alloc] initWithTransports:transports options:options];

    return [self initWithOptions:options
                     fileManager:fileManager
          deleteOldEnvelopeItems:deleteOldEnvelopeItems
                transportAdapter:transportAdapter];
}

/** Internal constructor for testing purposes. */
- (instancetype)initWithOptions:(SentryOptions *)options
                    fileManager:(SentryFileManager *)fileManager
         deleteOldEnvelopeItems:(BOOL)deleteOldEnvelopeItems
               transportAdapter:(SentryTransportAdapter *)transportAdapter

{
    SentryThreadInspector *threadInspector =
        [[SentryThreadInspector alloc] initWithOptions:options];

    return [self initWithOptions:options
                transportAdapter:transportAdapter
                     fileManager:fileManager
          deleteOldEnvelopeItems:deleteOldEnvelopeItems
                 threadInspector:threadInspector
                          random:[SentryDependencyContainer sharedInstance].random
                          locale:[NSLocale autoupdatingCurrentLocale]
                        timezone:[NSCalendar autoupdatingCurrentCalendar].timeZone];
}

- (instancetype)initWithOptions:(SentryOptions *)options
               transportAdapter:(SentryTransportAdapter *)transportAdapter
                    fileManager:(SentryFileManager *)fileManager
         deleteOldEnvelopeItems:(BOOL)deleteOldEnvelopeItems
                threadInspector:(SentryThreadInspector *)threadInspector
                         random:(id<SentryRandom>)random
                         locale:(NSLocale *)locale
                       timezone:(NSTimeZone *)timezone
{
    if (self = [super init]) {
        _isEnabled = YES;
        self.options = options;
        self.transportAdapter = transportAdapter;
        self.fileManager = fileManager;
        self.threadInspector = threadInspector;
        self.random = random;
        self.debugImageProvider = [SentryDependencyContainer sharedInstance].debugImageProvider;
        self.locale = locale;
        self.timezone = timezone;
        self.attachmentProcessors = [[NSMutableArray alloc] init];

        // The SDK stores the installationID in a file. The first call requires file IO. To avoid
        // executing this on the main thread, we cache the installationID async here.
        [SentryInstallation cacheIDAsyncWithCacheDirectoryPath:options.cacheDirectoryPath];

        if (deleteOldEnvelopeItems) {
            [fileManager deleteOldEnvelopeItems];
        }
    }
    return self;
}

- (SentryId *)captureMessage:(NSString *)message
{
    return [self captureMessage:message withScope:[[SentryScope alloc] init]];
}

- (SentryId *)captureMessage:(NSString *)message withScope:(SentryScope *)scope
{
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelInfo];
    event.message = [[SentryMessage alloc] initWithFormatted:message];
    return [self sendEvent:event withScope:scope alwaysAttachStacktrace:NO];
}

- (SentryId *)captureException:(NSException *)exception
{
    return [self captureException:exception withScope:[[SentryScope alloc] init]];
}

- (SentryId *)captureException:(NSException *)exception withScope:(SentryScope *)scope
{
    SentryEvent *event = [self buildExceptionEvent:exception];
    return [self sendEvent:event withScope:scope alwaysAttachStacktrace:YES];
}

- (SentryId *)captureException:(NSException *)exception
                     withScope:(SentryScope *)scope
        incrementSessionErrors:(SentrySession * (^)(void))sessionBlock
{
    SentryEvent *event = [self buildExceptionEvent:exception];
    event = [self prepareEvent:event withScope:scope alwaysAttachStacktrace:YES];

    if (event != nil) {
        SentrySession *session = sessionBlock();
        return [self sendEvent:event withSession:session withScope:scope];
    }

    return SentryId.empty;
}

- (SentryEvent *)buildExceptionEvent:(NSException *)exception
{
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelError];
    SentryException *sentryException = [[SentryException alloc] initWithValue:exception.reason
                                                                         type:exception.name];

    event.exceptions = @[ sentryException ];
    [self setUserInfo:exception.userInfo withEvent:event];
    return event;
}

- (SentryId *)captureError:(NSError *)error
{
    return [self captureError:error withScope:[[SentryScope alloc] init]];
}

- (SentryId *)captureError:(NSError *)error withScope:(SentryScope *)scope
{
    SentryEvent *event = [self buildErrorEvent:error];
    return [self sendEvent:event withScope:scope alwaysAttachStacktrace:YES];
}

- (SentryId *)captureError:(NSError *)error
                 withScope:(SentryScope *)scope
    incrementSessionErrors:(SentrySession * (^)(void))sessionBlock
{
    SentryEvent *event = [self buildErrorEvent:error];
    event = [self prepareEvent:event withScope:scope alwaysAttachStacktrace:YES];

    if (event != nil) {
        SentrySession *session = sessionBlock();
        return [self sendEvent:event withSession:session withScope:scope];
    }

    return SentryId.empty;
}

- (SentryEvent *)buildErrorEvent:(NSError *)error
{
    SentryEvent *event = [[SentryEvent alloc] initWithError:error];

    // flatten any recursive description of underlying errors into a list, to ultimately report them
    // as a list of exceptions with error mechanisms, sorted oldest to newest (so, the leaf node
    // underlying error as oldest, with the root as the newest)
    NSMutableArray<NSError *> *errors = [NSMutableArray<NSError *> arrayWithObject:error];
    NSError *underlyingError;
    if ([error.userInfo[NSUnderlyingErrorKey] isKindOfClass:[NSError class]]) {
        underlyingError = error.userInfo[NSUnderlyingErrorKey];
    } else if (error.userInfo[NSUnderlyingErrorKey] != nil) {
        SENTRY_LOG_WARN(@"Invalid value for NSUnderlyingErrorKey in user info. Data at key: %@. "
                        @"Class type: %@.",
            error.userInfo[NSUnderlyingErrorKey], [error.userInfo[NSUnderlyingErrorKey] class]);
    }

    while (underlyingError != nil) {
        [errors addObject:underlyingError];

        if ([underlyingError.userInfo[NSUnderlyingErrorKey] isKindOfClass:[NSError class]]) {
            underlyingError = underlyingError.userInfo[NSUnderlyingErrorKey];
        } else {
            if (underlyingError.userInfo[NSUnderlyingErrorKey] != nil) {
                SENTRY_LOG_WARN(@"Invalid value for NSUnderlyingErrorKey in user info. Data at "
                                @"key: %@. Class type: %@.",
                    underlyingError.userInfo[NSUnderlyingErrorKey],
                    [underlyingError.userInfo[NSUnderlyingErrorKey] class]);
            }
            underlyingError = nil;
        }
    }

    NSMutableArray<SentryException *> *exceptions = [NSMutableArray<SentryException *> array];
    [errors enumerateObjectsWithOptions:NSEnumerationReverse
                             usingBlock:^(NSError *_Nonnull nextError, NSUInteger __unused idx,
                                 BOOL *_Nonnull __unused stop) {
                                 [exceptions addObject:[self exceptionForError:nextError]];
                             }];

    event.exceptions = exceptions;

    // Once the UI displays the mechanism data we can the userInfo from the event.context using only
    // the root error's userInfo.
    [self setUserInfo:sentry_sanitize(error.userInfo) withEvent:event];

    return event;
}

- (SentryException *)exceptionForError:(NSError *)error
{
    NSString *exceptionValue;

    // If the error has a debug description, use that.
    NSString *customExceptionValue = [[error userInfo] valueForKey:NSDebugDescriptionErrorKey];

    NSString *swiftErrorDescription = nil;
    // SwiftNativeNSError is the subclass of NSError used to represent bridged native Swift errors,
    // see
    // https://github.com/apple/swift/blob/067e4ec50147728f2cb990dbc7617d66692c1554/stdlib/public/runtime/ErrorObject.mm#L63-L73
    NSString *errorClass = NSStringFromClass(error.class);
    if ([errorClass containsString:@"SwiftNativeNSError"]) {
        swiftErrorDescription = [SwiftDescriptor getSwiftErrorDescription:error];
    }

    if (customExceptionValue != nil) {
        exceptionValue =
            [NSString stringWithFormat:@"%@ (Code: %ld)", customExceptionValue, (long)error.code];
    } else if (swiftErrorDescription != nil) {
        exceptionValue =
            [NSString stringWithFormat:@"%@ (Code: %ld)", swiftErrorDescription, (long)error.code];
    } else {
        exceptionValue = [NSString stringWithFormat:@"Code: %ld", (long)error.code];
    }
    SentryException *exception = [[SentryException alloc] initWithValue:exceptionValue
                                                                   type:error.domain];

    // Sentry uses the error domain and code on the mechanism for gouping
    SentryMechanism *mechanism = [[SentryMechanism alloc] initWithType:@"NSError"];
    SentryMechanismMeta *mechanismMeta = [[SentryMechanismMeta alloc] init];
    mechanismMeta.error = [[SentryNSError alloc] initWithDomain:error.domain code:error.code];
    mechanism.meta = mechanismMeta;
    // The description of the error can be especially useful for error from swift that
    // use a simple enum.
    mechanism.desc = error.description;

    NSDictionary<NSString *, id> *userInfo = sentry_sanitize(error.userInfo);
    mechanism.data = userInfo;
    exception.mechanism = mechanism;

    return exception;
}

- (SentryId *)captureCrashEvent:(SentryEvent *)event withScope:(SentryScope *)scope
{
    return [self sendEvent:event withScope:scope alwaysAttachStacktrace:NO isCrashEvent:YES];
}

- (SentryId *)captureCrashEvent:(SentryEvent *)event
                    withSession:(SentrySession *)session
                      withScope:(SentryScope *)scope
{
    SentryEvent *preparedEvent = [self prepareEvent:event
                                          withScope:scope
                             alwaysAttachStacktrace:NO
                                       isCrashEvent:YES];
    return [self sendEvent:preparedEvent withSession:session withScope:scope];
}

- (SentryId *)captureEvent:(SentryEvent *)event
{
    return [self captureEvent:event withScope:[[SentryScope alloc] init]];
}

- (SentryId *)captureEvent:(SentryEvent *)event withScope:(SentryScope *)scope
{
    return [self sendEvent:event withScope:scope alwaysAttachStacktrace:NO];
}

- (SentryId *)captureEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
{
    return [self sendEvent:event
                      withScope:scope
         alwaysAttachStacktrace:NO
                   isCrashEvent:NO
        additionalEnvelopeItems:additionalEnvelopeItems];
}

- (SentryId *)sendEvent:(SentryEvent *)event
                 withScope:(SentryScope *)scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
{
    return [self sendEvent:event
                     withScope:scope
        alwaysAttachStacktrace:alwaysAttachStacktrace
                  isCrashEvent:NO];
}

- (nullable SentryTraceContext *)getTraceStateWithEvent:(SentryEvent *)event
                                              withScope:(SentryScope *)scope
{
    id<SentrySpan> span;
    if ([event isKindOfClass:[SentryTransaction class]]) {
        span = [(SentryTransaction *)event trace];
    } else {
        // Even envelopes without transactions can contain the trace state, allowing Sentry to
        // eventually sample attachments belonging to a transaction.
        span = scope.span;
    }

    SentryTracer *tracer = [SentryTracer getTracer:span];
    if (tracer != nil) {
        return [[SentryTraceContext alloc] initWithTracer:tracer scope:scope options:_options];
    }

    if (event.error || event.exceptions.count > 0) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return [[SentryTraceContext alloc] initWithTraceId:scope.propagationContext.traceId
                                                   options:self.options
                                               userSegment:scope.userObject.segment];
#pragma clang diagnostic pop
    }

    return nil;
}

- (SentryId *)sendEvent:(SentryEvent *)event
                 withScope:(SentryScope *)scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
              isCrashEvent:(BOOL)isCrashEvent
{
    return [self sendEvent:event
                      withScope:scope
         alwaysAttachStacktrace:alwaysAttachStacktrace
                   isCrashEvent:isCrashEvent
        additionalEnvelopeItems:@[]];
}

- (SentryId *)sendEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
     alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
               isCrashEvent:(BOOL)isCrashEvent
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
{
    SentryEvent *preparedEvent = [self prepareEvent:event
                                          withScope:scope
                             alwaysAttachStacktrace:alwaysAttachStacktrace
                                       isCrashEvent:isCrashEvent];

    if (preparedEvent == nil) {
        return SentryId.empty;
    }

    SentryTraceContext *traceContext = [self getTraceStateWithEvent:event withScope:scope];

    NSArray *attachments = scope.attachments;
    if (self.attachmentProcessors.count) {
        for (id<SentryClientAttachmentProcessor> attachmentProcessor in self.attachmentProcessors) {
            attachments = [attachmentProcessor processAttachments:attachments
                                                         forEvent:preparedEvent];
        }
    }

    [self.transportAdapter sendEvent:preparedEvent
                        traceContext:traceContext
                         attachments:attachments
             additionalEnvelopeItems:additionalEnvelopeItems];

    return preparedEvent.eventId;
}

- (SentryId *)sendEvent:(SentryEvent *)event
            withSession:(SentrySession *)session
              withScope:(SentryScope *)scope
{
    if (nil != event) {
        NSArray *attachments = scope.attachments;
        if (self.attachmentProcessors.count) {
            for (id<SentryClientAttachmentProcessor> attachmentProcessor in self
                     .attachmentProcessors) {
                attachments = [attachmentProcessor processAttachments:attachments forEvent:event];
            }
        }

        SentryTraceContext *traceContext = [self getTraceStateWithEvent:event withScope:scope];

        if (nil == session.releaseName || [session.releaseName length] == 0) {
            SENTRY_LOG_DEBUG(DropSessionLogMessage);

            [self.transportAdapter sendEvent:event
                                traceContext:traceContext
                                 attachments:attachments];
            return event.eventId;
        }

        [self.transportAdapter sendEvent:event
                             withSession:session
                            traceContext:traceContext
                             attachments:attachments];

        return event.eventId;
    }

    return SentryId.empty;
}

- (void)captureSession:(SentrySession *)session
{
    if (nil == session.releaseName || [session.releaseName length] == 0) {
        SENTRY_LOG_DEBUG(DropSessionLogMessage);
        return;
    }

    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithSession:session];
    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithHeader:[SentryEnvelopeHeader empty]
                                                           singleItem:item];
    [self captureEnvelope:envelope];
}

- (void)captureReplayEvent:(SentryReplayEvent *)replayEvent
           replayRecording:(SentryReplayRecording *)replayRecording
                     video:(NSURL *)videoURL
                 withScope:(SentryScope *)scope
{
    replayEvent = (SentryReplayEvent *)[self prepareEvent:replayEvent
                                                withScope:scope
                                   alwaysAttachStacktrace:NO];

    if (![replayEvent isKindOfClass:SentryReplayEvent.class]) {
        SENTRY_LOG_DEBUG(@"The event preprocessor didn't update the replay event in place. The "
                         @"replay was discarded.");
        return;
    }

    SentryEnvelopeItem *videoEnvelopeItem =
        [[SentryEnvelopeItem alloc] initWithReplayEvent:replayEvent
                                        replayRecording:replayRecording
                                                  video:videoURL];

    if (videoEnvelopeItem == nil) {
        SENTRY_LOG_DEBUG(@"The Session Replay segment will not be sent to Sentry because an "
                         @"Envelope Item could not be created.");
        return;
    }

    SentryEnvelope *envelope = [[SentryEnvelope alloc]
        initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:replayEvent.eventId]
                 items:@[ videoEnvelopeItem ]];

    [self captureEnvelope:envelope];
}

- (void)captureEnvelope:(SentryEnvelope *)envelope
{
    if ([self isDisabled]) {
        [self logDisabledMessage];
        return;
    }

    [self.transportAdapter sendEnvelope:envelope];
}

- (void)captureUserFeedback:(SentryUserFeedback *)userFeedback
{
    if ([self isDisabled]) {
        [self logDisabledMessage];
        return;
    }

    if ([SentryId.empty isEqual:userFeedback.eventId]) {
        SENTRY_LOG_DEBUG(@"Capturing UserFeedback with an empty event id. Won't send it.");
        return;
    }

    [self.transportAdapter sendUserFeedback:userFeedback];
}

- (void)storeEnvelope:(SentryEnvelope *)envelope
{
    [self.fileManager storeEnvelope:envelope];
}

- (void)recordLostEvent:(SentryDataCategory)category reason:(SentryDiscardReason)reason
{
    [self.transportAdapter recordLostEvent:category reason:reason];
}

- (void)recordLostEvent:(SentryDataCategory)category
                 reason:(SentryDiscardReason)reason
               quantity:(NSUInteger)quantity
{
    [self.transportAdapter recordLostEvent:category reason:reason quantity:quantity];
}

- (SentryEvent *_Nullable)prepareEvent:(SentryEvent *)event
                             withScope:(SentryScope *)scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
{
    return [self prepareEvent:event
                     withScope:scope
        alwaysAttachStacktrace:alwaysAttachStacktrace
                  isCrashEvent:NO];
}

- (void)flush:(NSTimeInterval)timeout
{
    [self.transportAdapter flush:timeout];
}

- (void)close
{
    _isEnabled = NO;
    [self flush:self.options.shutdownTimeInterval];
    SENTRY_LOG_DEBUG(@"Closed the Client.");
}

- (SentryEvent *_Nullable)prepareEvent:(SentryEvent *)event
                             withScope:(SentryScope *)scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                          isCrashEvent:(BOOL)isCrashEvent
{
    NSParameterAssert(event);
    if (event == nil) {
        return nil;
    }

    if ([self isDisabled]) {
        [self logDisabledMessage];
        return nil;
    }

    BOOL eventIsNotATransaction
        = event.type == nil || ![event.type isEqualToString:SentryEnvelopeItemTypeTransaction];
    BOOL eventIsNotReplay
        = event.type == nil || ![event.type isEqualToString:SentryEnvelopeItemTypeReplayVideo];

    // Transactions and replays have their own sampleRate
    if (eventIsNotATransaction && eventIsNotReplay && [self isSampled:self.options.sampleRate]) {
        SENTRY_LOG_DEBUG(@"Event got sampled, will not send the event");
        [self recordLostEvent:kSentryDataCategoryError reason:kSentryDiscardReasonSampleRate];
        return nil;
    }

    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
    if (nil != infoDict && nil == event.dist) {
        event.dist = infoDict[@"CFBundleVersion"];
    }

    // Use the values from SentryOptions as a fallback,
    // in case not yet set directly in the event nor in the scope:
    NSString *releaseName = self.options.releaseName;
    if (nil == event.releaseName && nil != releaseName) {
        // If no release was already set (i.e: crashed on an older version) use
        // current release name
        event.releaseName = releaseName;
    }

    NSString *dist = self.options.dist;
    if (nil != dist) {
        event.dist = dist;
    }

    [self setSdk:event];

    // We don't want to attach debug meta and stacktraces for transactions and replays.
    if (eventIsNotATransaction && eventIsNotReplay) {
        BOOL shouldAttachStacktrace = alwaysAttachStacktrace || self.options.attachStacktrace
            || (nil != event.exceptions && [event.exceptions count] > 0);

        BOOL threadsNotAttached = !(nil != event.threads && event.threads.count > 0);

        if (!isCrashEvent && shouldAttachStacktrace && threadsNotAttached) {
            event.threads = [self.threadInspector getCurrentThreads];
        }

#if SENTRY_HAS_UIKIT
        if (!isCrashEvent) {
            NSMutableDictionary *context =
                [event.context mutableCopy] ?: [NSMutableDictionary dictionary];
            if (context[@"app"] == nil
                || ([context[@"app"] isKindOfClass:NSDictionary.self]
                    && context[@"app"][@"in_foreground"] == nil)) {
                NSMutableDictionary *app = [(NSDictionary *)context[@"app"] mutableCopy]
                    ?: [NSMutableDictionary dictionary];
                context[@"app"] = app;

                UIApplicationState appState =
                    [SentryDependencyContainer sharedInstance].application.applicationState;
                BOOL inForeground = appState == UIApplicationStateActive;
                app[@"in_foreground"] = @(inForeground);
                event.context = context;
            }
        }
#endif

        BOOL debugMetaNotAttached = !(nil != event.debugMeta && event.debugMeta.count > 0);
        if (!isCrashEvent && shouldAttachStacktrace && debugMetaNotAttached
            && event.threads != nil) {
            event.debugMeta = [self.debugImageProvider getDebugImagesForThreads:event.threads
                                                                        isCrash:NO];
        }
    }

    event = [scope applyToEvent:event maxBreadcrumb:self.options.maxBreadcrumbs];

    if (!eventIsNotReplay) {
        event.breadcrumbs = nil;
    }

    if ([self isWatchdogTermination:event isCrashEvent:isCrashEvent]) {
        // Remove some mutable properties from the device/app contexts which are no longer
        // applicable
        [self removeExtraDeviceContextFromEvent:event];
    } else if (!isCrashEvent) {
        // Store the current free memory battery level and more mutable properties,
        // at the time of this event, but not for crashes as the current data isn't guaranteed to be
        // the same as when the app crashed.
        [self applyExtraDeviceContextToEvent:event];
        [self applyCultureContextToEvent:event];
#if SENTRY_HAS_UIKIT
        [self applyCurrentViewNamesToEventContext:event withScope:scope];
#endif // SENTRY_HAS_UIKIT
    }

    // With scope applied, before running callbacks run:
    if (event.environment == nil) {
        // We default to environment 'production' if nothing was set
        event.environment = self.options.environment;
    }

    // Need to do this after the scope is applied cause this sets the user if there is any
    [self setUserIdIfNoUserSet:event];

    // User can't be nil as setUserIdIfNoUserSet sets it.
    if (self.options.sendDefaultPii && nil == event.user.ipAddress) {
        // Let Sentry infer the IP address from the connection.
        // Due to backward compatibility concerns, Sentry servers set the IP address to {{auto}} out
        // of the box for only Cocoa and JavaScript, which makes this toggle currently somewhat
        // useless. Still, we keep it for future compatibility reasons.
        event.user.ipAddress = @"{{auto}}";
    }

    BOOL eventIsATransaction
        = event.type != nil && [event.type isEqualToString:SentryEnvelopeItemTypeTransaction];
    BOOL eventIsATransactionClass
        = eventIsATransaction && [event isKindOfClass:[SentryTransaction class]];

    NSUInteger currentSpanCount;
    if (eventIsATransactionClass) {
        SentryTransaction *transaction = (SentryTransaction *)event;
        currentSpanCount = transaction.spans.count;
    } else {
        currentSpanCount = 0;
    }

    event = [self callEventProcessors:event];
    if (event == nil) {
        [self recordLost:eventIsNotATransaction reason:kSentryDiscardReasonEventProcessor];
        if (eventIsATransaction) {
            // We dropped the whole transaction, the dropped count includes all child spans + 1 root
            // span
            [self recordLostSpanWithReason:kSentryDiscardReasonEventProcessor
                                  quantity:currentSpanCount + 1];
        }
    } else {
        if (eventIsATransactionClass) {
            [self recordPartiallyDroppedSpans:(SentryTransaction *)event
                                   withReason:kSentryDiscardReasonEventProcessor
                         withCurrentSpanCount:&currentSpanCount];
        }
    }
    if (event != nil && eventIsATransaction && self.options.beforeSendSpan != nil) {
        SentryTransaction *transaction = (SentryTransaction *)event;
        NSMutableArray<id<SentrySpan>> *processedSpans = [NSMutableArray array];
        for (id<SentrySpan> span in transaction.spans) {
            id<SentrySpan> processedSpan = self.options.beforeSendSpan(span);
            if (processedSpan) {
                [processedSpans addObject:processedSpan];
            }
        }
        transaction.spans = processedSpans;

        if (eventIsATransactionClass) {
            [self recordPartiallyDroppedSpans:transaction
                                   withReason:kSentryDiscardReasonBeforeSend
                         withCurrentSpanCount:&currentSpanCount];
        }
    }

    if (event != nil && nil != self.options.beforeSend) {
        event = self.options.beforeSend(event);
        if (event == nil) {
            [self recordLost:eventIsNotATransaction reason:kSentryDiscardReasonBeforeSend];
            if (eventIsATransaction) {
                // We dropped the whole transaction, the dropped count includes all child spans + 1
                // root span
                [self recordLostSpanWithReason:kSentryDiscardReasonBeforeSend
                                      quantity:currentSpanCount + 1];
            }
        } else {
            if (eventIsATransactionClass) {
                [self recordPartiallyDroppedSpans:(SentryTransaction *)event
                                       withReason:kSentryDiscardReasonBeforeSend
                             withCurrentSpanCount:&currentSpanCount];
            }
        }
    }

    if (event != nil && isCrashEvent && nil != self.options.onCrashedLastRun
        && !SentrySDK.crashedLastRunCalled) {
        // We only want to call the callback once. It can occur that multiple crash events are
        // about to be sent.
        SentrySDK.crashedLastRunCalled = YES;
        self.options.onCrashedLastRun(event);
    }

    return event;
}

- (void)recordPartiallyDroppedSpans:(SentryTransaction *)transaction
                         withReason:(SentryDiscardReason)reason
               withCurrentSpanCount:(NSUInteger *)currentSpanCount
{
    // If some spans got removed we still report them as dropped
    NSUInteger spanCountAfter = transaction.spans.count;
    NSUInteger droppedSpanCount = *currentSpanCount - spanCountAfter;
    if (droppedSpanCount > 0) {
        [self recordLostSpanWithReason:reason quantity:droppedSpanCount];
    }
    *currentSpanCount = spanCountAfter;
}

- (BOOL)isSampled:(NSNumber *)sampleRate
{
    if (sampleRate == nil) {
        return NO;
    }

    return [self.random nextNumber] <= sampleRate.doubleValue ? NO : YES;
}

- (BOOL)isDisabled
{
    return !_isEnabled || !self.options.enabled || nil == self.options.parsedDsn;
}

- (void)logDisabledMessage
{
    SENTRY_LOG_DEBUG(@"SDK disabled or no DSN set. Won't do anyting.");
}

- (SentryEvent *_Nullable)callEventProcessors:(SentryEvent *)event
{
    SentryEvent *newEvent = event;

    for (SentryEventProcessor processor in SentryGlobalEventProcessor.shared.processors) {
        newEvent = processor(newEvent);
        if (newEvent == nil) {
            SENTRY_LOG_DEBUG(@"SentryScope callEventProcessors: An event processor decided to "
                             @"remove this event.");
            break;
        }
    }
    return newEvent;
}

- (void)setSdk:(SentryEvent *)event
{
    if (event.sdk) {
        return;
    }

    id integrations = event.extra[@"__sentry_sdk_integrations"];
    if (!integrations) {
        integrations = [SentrySDK.currentHub trimmedInstalledIntegrationNames];

#if SENTRY_HAS_UIKIT
        if (self.options.enablePreWarmedAppStartTracing) {
            [integrations addObject:@"PreWarmedAppStartTracing"];
        }
#endif
    }

    NSArray<NSString *> *features =
        [SentryEnabledFeaturesBuilder getEnabledFeaturesWithOptions:self.options];

    event.sdk = @{
        @"name" : SentryMeta.sdkName,
        @"version" : SentryMeta.versionString,
        @"integrations" : integrations,
        @"features" : features
    };
}

- (void)setUserInfo:(NSDictionary *)userInfo withEvent:(SentryEvent *)event
{
    if (nil != event && nil != userInfo && userInfo.count > 0) {
        NSMutableDictionary *context;
        if (event.context == nil) {
            context = [[NSMutableDictionary alloc] init];
            event.context = context;
        } else {
            context = [event.context mutableCopy];
        }

        [context setValue:sentry_sanitize(userInfo) forKey:@"user info"];
    }
}

- (void)setUserIdIfNoUserSet:(SentryEvent *)event
{
    // We only want to set the id if the customer didn't set a user so we at least set something to
    // identify the user.
    if (event.user == nil) {
        SentryUser *user = [[SentryUser alloc] init];
        user.userId = [SentryInstallation idWithCacheDirectoryPath:self.options.cacheDirectoryPath];
        event.user = user;
    }
}

- (BOOL)isWatchdogTermination:(SentryEvent *)event isCrashEvent:(BOOL)isCrashEvent
{
    if (!isCrashEvent) {
        return NO;
    }

    if (event.exceptions == nil || event.exceptions.count != 1) {
        return NO;
    }

    SentryException *exception = event.exceptions[0];
    return exception.mechanism != nil &&
        [exception.mechanism.type isEqualToString:SentryWatchdogTerminationMechanismType];
}

- (void)applyCultureContextToEvent:(SentryEvent *)event
{
    [self modifyContext:event
                    key:@"culture"
                  block:^(NSMutableDictionary *culture) {
#if TARGET_OS_MACCATALYST
                      if (@available(macCatalyst 13, *)) {
                          culture[@"calendar"] = [self.locale
                              localizedStringForCalendarIdentifier:self.locale.calendarIdentifier];
                          culture[@"display_name"] = [self.locale
                              localizedStringForLocaleIdentifier:self.locale.localeIdentifier];
                      }
#else
            if (@available(iOS 10, macOS 10.12, watchOS 3, tvOS 10, *)) {
                culture[@"calendar"] = [self.locale
                    localizedStringForCalendarIdentifier:self.locale.calendarIdentifier];
                culture[@"display_name"] =
                    [self.locale localizedStringForLocaleIdentifier:self.locale.localeIdentifier];
            }
#endif
                      culture[@"locale"] = self.locale.localeIdentifier;
                      culture[@"is_24_hour_format"] = @([SentryLocale timeIs24HourFormat]);
                      culture[@"timezone"] = self.timezone.name;
                  }];
}

- (void)applyExtraDeviceContextToEvent:(SentryEvent *)event
{
    NSDictionary *extraContext =
        [SentryDependencyContainer.sharedInstance.extraContextProvider getExtraContext];
    [self modifyContext:event
                    key:@"device"
                  block:^(NSMutableDictionary *device) {
                      [device addEntriesFromDictionary:extraContext[@"device"]];
                  }];

    [self modifyContext:event
                    key:@"app"
                  block:^(NSMutableDictionary *app) {
                      [app addEntriesFromDictionary:extraContext[@"app"]];
                  }];
}

#if SENTRY_HAS_UIKIT
- (void)applyCurrentViewNamesToEventContext:(SentryEvent *)event withScope:(SentryScope *)scope
{
    [self modifyContext:event
                    key:@"app"
                  block:^(NSMutableDictionary *app) {
                      if ([event isKindOfClass:[SentryTransaction class]]) {
                          SentryTransaction *transaction = (SentryTransaction *)event;
                          if ([transaction.viewNames count] > 0) {
                              app[@"view_names"] = transaction.viewNames;
                          }
                      } else {
                          if (scope.currentScreen != nil) {
                              app[@"view_names"] = @[ scope.currentScreen ];
                          } else {
                              app[@"view_names"] = [SentryDependencyContainer.sharedInstance
                                                        .application relevantViewControllersNames];
                          }
                      }
                  }];
}
#endif // SENTRY_HAS_UIKIT

- (void)removeExtraDeviceContextFromEvent:(SentryEvent *)event
{
    [self modifyContext:event
                    key:@"device"
                  block:^(NSMutableDictionary *device) {
                      [device removeObjectForKey:SentryDeviceContextFreeMemoryKey];
                      [device removeObjectForKey:@"orientation"];
                      [device removeObjectForKey:@"charging"];
                      [device removeObjectForKey:@"battery_level"];
                  }];

    [self modifyContext:event
                    key:@"app"
                  block:^(NSMutableDictionary *app) {
                      [app removeObjectForKey:SentryDeviceContextAppMemoryKey];
                  }];
}

- (void)modifyContext:(SentryEvent *)event
                  key:(NSString *)key
                block:(void (^)(NSMutableDictionary *))block
{
    if (event.context == nil || event.context.count == 0) {
        return;
    }

    NSMutableDictionary *context = [[NSMutableDictionary alloc] initWithDictionary:event.context];
    NSMutableDictionary *dict = event.context[key] == nil
        ? [[NSMutableDictionary alloc] init]
        : [[NSMutableDictionary alloc] initWithDictionary:context[key]];
    block(dict);
    context[key] = dict;
    event.context = context;
}

- (void)recordLost:(BOOL)eventIsNotATransaction reason:(SentryDiscardReason)reason
{
    if (eventIsNotATransaction) {
        [self recordLostEvent:kSentryDataCategoryError reason:reason];
    } else {
        [self recordLostEvent:kSentryDataCategoryTransaction reason:reason];
    }
}

- (void)recordLostSpanWithReason:(SentryDiscardReason)reason quantity:(NSUInteger)quantity
{
    [self recordLostEvent:kSentryDataCategorySpan reason:reason quantity:quantity];
}

- (void)addAttachmentProcessor:(id<SentryClientAttachmentProcessor>)attachmentProcessor
{
    [self.attachmentProcessors addObject:attachmentProcessor];
}

- (void)removeAttachmentProcessor:(id<SentryClientAttachmentProcessor>)attachmentProcessor
{
    [self.attachmentProcessors removeObject:attachmentProcessor];
}

@end

NS_ASSUME_NONNULL_END
