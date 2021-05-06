#import "SentryClient.h"
#import "NSDictionary+SentrySanitize.h"
#import "SentryCrashDefaultBinaryImageProvider.h"
#import "SentryCrashDefaultMachineContextWrapper.h"
#import "SentryCrashIntegration.h"
#import "SentryCrashStackEntryMapper.h"
#import "SentryDebugMetaBuilder.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryDsn.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeItemType.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryFileManager.h"
#import "SentryFrameInAppLogic.h"
#import "SentryFrameRemover.h"
#import "SentryGlobalEventProcessor.h"
#import "SentryId.h"
#import "SentryInstallation.h"
#import "SentryLog.h"
#import "SentryMechanism.h"
#import "SentryMechanismMeta.h"
#import "SentryMessage.h"
#import "SentryMeta.h"
#import "SentryNSError.h"
#import "SentryOptions+Private.h"
#import "SentryOptions.h"
#import "SentryOutOfMemoryTracker.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"
#import "SentryScope.h"
#import "SentryStacktraceBuilder.h"
#import "SentryThreadInspector.h"
#import "SentryTransaction.h"
#import "SentryTransport.h"
#import "SentryTransportFactory.h"
#import "SentryUser.h"
#import "SentryUserFeedback.h"

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface
SentryClient ()

@property (nonatomic, strong) id<SentryTransport> transport;
@property (nonatomic, strong) SentryFileManager *fileManager;
@property (nonatomic, strong) SentryDebugMetaBuilder *debugMetaBuilder;
@property (nonatomic, strong) SentryThreadInspector *threadInspector;

@end

NSString *const DropSessionLogMessage = @"Session has no release name. Won't send it.";

@implementation SentryClient

- (_Nullable instancetype)initWithOptions:(SentryOptions *)options
{
    if (self = [super init]) {
        self.options = options;

        SentryCrashDefaultBinaryImageProvider *provider =
            [[SentryCrashDefaultBinaryImageProvider alloc] init];

        self.debugMetaBuilder =
            [[SentryDebugMetaBuilder alloc] initWithBinaryImageProvider:provider];

        SentryFrameInAppLogic *frameInAppLogic =
            [[SentryFrameInAppLogic alloc] initWithInAppIncludes:options.inAppIncludes
                                                   inAppExcludes:options.inAppExcludes];
        SentryCrashStackEntryMapper *crashStackEntryMapper =
            [[SentryCrashStackEntryMapper alloc] initWithFrameInAppLogic:frameInAppLogic];
        SentryStacktraceBuilder *stacktraceBuilder =
            [[SentryStacktraceBuilder alloc] initWithCrashStackEntryMapper:crashStackEntryMapper];
        id<SentryCrashMachineContextWrapper> machineContextWrapper =
            [[SentryCrashDefaultMachineContextWrapper alloc] init];

        self.threadInspector =
            [[SentryThreadInspector alloc] initWithStacktraceBuilder:stacktraceBuilder
                                            andMachineContextWrapper:machineContextWrapper];

        NSError *error = nil;

        self.fileManager = [[SentryFileManager alloc]
                   initWithOptions:self.options
            andCurrentDateProvider:[[SentryDefaultCurrentDateProvider alloc] init]
                             error:&error];
        if (nil != error) {
            [SentryLog logWithMessage:error.localizedDescription andLevel:kSentryLevelError];
            return nil;
        }

        self.transport = [SentryTransportFactory initTransport:self.options
                                             sentryFileManager:self.fileManager];
    }
    return self;
}

/** Internal constructor for testing */
- (instancetype)initWithOptions:(SentryOptions *)options
                   andTransport:(id<SentryTransport>)transport
                 andFileManager:(SentryFileManager *)fileManager
{
    self = [self initWithOptions:options];

    self.transport = transport;
    self.fileManager = fileManager;

    return self;
}

- (SentryFileManager *)fileManager
{
    return _fileManager;
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
                   withSession:(SentrySession *)session
                     withScope:(SentryScope *)scope
{
    SentryEvent *event = [self buildExceptionEvent:exception];
    event = [self prepareEvent:event withScope:scope alwaysAttachStacktrace:YES];
    return [self sendEvent:event withSession:session withScope:scope];
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
               withSession:(SentrySession *)session
                 withScope:(SentryScope *)scope
{
    SentryEvent *event = [self buildErrorEvent:error];
    event = [self prepareEvent:event withScope:scope alwaysAttachStacktrace:YES];
    return [self sendEvent:event withSession:session withScope:scope];
}

- (SentryEvent *)buildErrorEvent:(NSError *)error
{
    SentryEvent *event = [[SentryEvent alloc] initWithError:error];

    NSString *exceptionValue = [NSString stringWithFormat:@"Code: %ld", (long)error.code];
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

    NSDictionary<NSString *, id> *userInfo = [error.userInfo sentry_sanitize];
    mechanism.data = userInfo;
    exception.mechanism = mechanism;
    event.exceptions = @[ exception ];

    // Once the UI displays the mechanism data we can the userInfo from the event.context.
    [self setUserInfo:userInfo withEvent:event];

    return event;
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

- (SentryId *)sendEvent:(SentryEvent *)event
                 withScope:(SentryScope *)scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
{
    return [self sendEvent:event
                     withScope:scope
        alwaysAttachStacktrace:alwaysAttachStacktrace
                  isCrashEvent:NO];
}

- (SentryId *)sendEvent:(SentryEvent *)event
                 withScope:(SentryScope *)scope
    alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
              isCrashEvent:(BOOL)isCrashEvent
{
    SentryEvent *preparedEvent = [self prepareEvent:event
                                          withScope:scope
                             alwaysAttachStacktrace:alwaysAttachStacktrace
                                       isCrashEvent:isCrashEvent];

    if (nil != preparedEvent) {
        [self.transport sendEvent:preparedEvent attachments:scope.attachments];
        return preparedEvent.eventId;
    }

    return SentryId.empty;
}

- (SentryId *)sendEvent:(SentryEvent *)event
            withSession:(SentrySession *)session
              withScope:(SentryScope *)scope
{
    if (nil != event) {
        if (nil == session.releaseName || [session.releaseName length] == 0) {
            [SentryLog logWithMessage:DropSessionLogMessage andLevel:kSentryLevelDebug];
            [self.transport sendEvent:event attachments:scope.attachments];
            return event.eventId;
        }

        [self.transport sendEvent:event withSession:session attachments:scope.attachments];
        return event.eventId;
    } else {
        [self captureSession:session];
        return SentryId.empty;
    }
}

- (void)captureSession:(SentrySession *)session
{
    if (nil == session.releaseName || [session.releaseName length] == 0) {
        [SentryLog logWithMessage:DropSessionLogMessage andLevel:kSentryLevelDebug];
        return;
    }

    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithSession:session];
    [self captureEnvelope:envelope];
}

- (void)captureEnvelope:(SentryEnvelope *)envelope
{
    // TODO: What is about beforeSend

    if ([self isDisabled]) {
        [self logDisabledMessage];
        return;
    }

    [self.transport sendEnvelope:envelope];
}

- (void)captureUserFeedback:(SentryUserFeedback *)userFeedback
{
    if ([self isDisabled]) {
        [self logDisabledMessage];
        return;
    }

    if ([SentryId.empty isEqual:userFeedback.eventId]) {
        [SentryLog logWithMessage:@"Capturing UserFeedback with an empty event id. Won't send it."
                         andLevel:kSentryLevelDebug];
        return;
    }

    [self.transport sendUserFeedback:userFeedback];
}

- (void)storeEnvelope:(SentryEnvelope *)envelope
{
    [self.fileManager storeEnvelope:envelope];
}

/**
 * returns BOOL chance of YES is defined by sampleRate.
 * if sample rate isn't within 0.0 - 1.0 it returns YES (like if sampleRate
 * is 1.0)
 */
- (BOOL)checkSampleRate:(NSNumber *)sampleRate
{
    if (nil == sampleRate || ![self.options isValidSampleRate:sampleRate]) {
        return YES;
    }
    return ([sampleRate floatValue] >= ((double)arc4random() / 0x100000000));
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

- (SentryEvent *_Nullable)prepareEvent:(SentryEvent *)event
                             withScope:(SentryScope *)scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
                          isCrashEvent:(BOOL)isCrashEvent
{
    NSParameterAssert(event);
    if ([self isDisabled]) {
        [self logDisabledMessage];
        return nil;
    }

    if (NO == [self checkSampleRate:self.options.sampleRate]) {
        [SentryLog logWithMessage:@"Event got sampled, will not send the event"
                         andLevel:kSentryLevelDebug];
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

    NSString *environment = self.options.environment;
    if (nil != environment && nil == event.environment) {
        // Set the environment from option to the event before Scope is applied
        event.environment = environment;
    }

    NSMutableDictionary *sdk =
        @{ @"name" : SentryMeta.sdkName, @"version" : SentryMeta.versionString }.mutableCopy;
    if (nil != sdk && nil == event.sdk) {
        if (event.extra[@"__sentry_sdk_integrations"]) {
            [sdk setValue:event.extra[@"__sentry_sdk_integrations"] forKey:@"integrations"];
        }
        event.sdk = sdk;
    }

    // We don't want to attach debug meta and stacktraces for transactions
    BOOL eventIsNotATransaction
        = event.type == nil || ![event.type isEqualToString:SentryEnvelopeItemTypeTransaction];
    if (eventIsNotATransaction) {
        BOOL shouldAttachStacktrace = alwaysAttachStacktrace || self.options.attachStacktrace
            || (nil != event.exceptions && [event.exceptions count] > 0);

        BOOL debugMetaNotAttached = !(nil != event.debugMeta && event.debugMeta.count > 0);
        if (!isCrashEvent && shouldAttachStacktrace && debugMetaNotAttached) {
            event.debugMeta = [self.debugMetaBuilder buildDebugMeta];
        }

        BOOL threadsNotAttached = !(nil != event.threads && event.threads.count > 0);
        if (!isCrashEvent && shouldAttachStacktrace && threadsNotAttached) {
            event.threads = [self.threadInspector getCurrentThreads];
        }
    }

    event = [scope applyToEvent:event maxBreadcrumb:self.options.maxBreadcrumbs];

    // Remove free_memory if OOM as free_memory stems from the current run and not of the time of
    // the OOM.
    if ([self isOOM:event isCrashEvent:isCrashEvent]) {
        [self removeFreeMemoryFromDeviceContext:event];
    }

    // With scope applied, before running callbacks run:
    if (nil == event.environment) {
        // We default to environment 'production' if nothing was set
        event.environment = @"production";
    }

    // Need to do this after the scope is applied cause this sets the user if there is any
    [self setUserIdIfNoUserSet:event];

    // User can't be nil as setUserIdIfNoUserSet sets it.
    if (self.options.sendDefaultPii && nil == event.user.ipAddress) {
        // Let Sentry infer the IP address from the connection.
        event.user.ipAddress = @"{{auto}}";
    }

    event = [self callEventProcessors:event];

    if (nil != self.options.beforeSend) {
        event = self.options.beforeSend(event);
    }

    if (isCrashEvent && nil != self.options.onCrashedLastRun && !SentrySDK.crashedLastRunCalled) {
        // We only want to call the callback once. It can occur that multiple crash events are
        // about to be sent.
        self.options.onCrashedLastRun(event);
        SentrySDK.crashedLastRunCalled = YES;
    }

    return event;
}

- (BOOL)isDisabled
{
    return !self.options.enabled || nil == self.options.parsedDsn;
}

- (void)logDisabledMessage
{
    [SentryLog logWithMessage:@"SDK disabled or no DSN set. Won't do anyting."
                     andLevel:kSentryLevelDebug];
}

- (SentryEvent *_Nullable)callEventProcessors:(SentryEvent *)event
{
    SentryEvent *newEvent = event;

    for (SentryEventProcessor processor in SentryGlobalEventProcessor.shared.processors) {
        newEvent = processor(newEvent);
        if (nil == newEvent) {
            [SentryLog logWithMessage:@"SentryScope callEventProcessors: An event "
                                      @"processor decided to remove this event."
                             andLevel:kSentryLevelDebug];
            break;
        }
    }
    return newEvent;
}

- (void)setUserInfo:(NSDictionary *)userInfo withEvent:(SentryEvent *)event
{
    if (nil != event && nil != userInfo && userInfo.count > 0) {
        NSMutableDictionary *context;
        if (nil == event.context) {
            context = [[NSMutableDictionary alloc] init];
            event.context = context;
        } else {
            context = [event.context mutableCopy];
        }

        [context setValue:[userInfo sentry_sanitize] forKey:@"user info"];
    }
}

- (void)setUserIdIfNoUserSet:(SentryEvent *)event
{
    // We only want to set the id if the customer didn't set a user so we at least set something to
    // identify the user.
    if (nil == event.user) {
        SentryUser *user = [[SentryUser alloc] init];
        user.userId = [SentryInstallation id];
        event.user = user;
    }
}

- (BOOL)isOOM:(SentryEvent *)event isCrashEvent:(BOOL)isCrashEvent
{
    if (!isCrashEvent) {
        return NO;
    }

    if (nil == event.exceptions || event.exceptions.count != 1) {
        return NO;
    }

    SentryException *exception = event.exceptions[0];
    return nil != exception.mechanism &&
        [exception.mechanism.type isEqualToString:SentryOutOfMemoryMechanismType];
}

- (void)removeFreeMemoryFromDeviceContext:(SentryEvent *)event
{
    if (nil == event.context || event.context.count == 0 || nil == event.context[@"device"]) {
        return;
    }

    NSMutableDictionary *context = [[NSMutableDictionary alloc] initWithDictionary:event.context];
    NSMutableDictionary *device =
        [[NSMutableDictionary alloc] initWithDictionary:context[@"device"]];
    [device removeObjectForKey:SentryDeviceContextFreeMemoryKey];
    context[@"device"] = device;

    event.context = context;
}

@end

NS_ASSUME_NONNULL_END
