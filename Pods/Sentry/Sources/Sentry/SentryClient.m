#import "SentryClient.h"
#import "NSDictionary+SentrySanitize.h"
#import "SentryCrashDefaultBinaryImageProvider.h"
#import "SentryCrashDefaultMachineContextWrapper.h"
#import "SentryDebugMetaBuilder.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryDsn.h"
#import "SentryEnvelope.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryFileManager.h"
#import "SentryFrameRemover.h"
#import "SentryGlobalEventProcessor.h"
#import "SentryId.h"
#import "SentryInstallation.h"
#import "SentryLog.h"
#import "SentryMessage.h"
#import "SentryMeta.h"
#import "SentryOptions.h"
#import "SentryScope.h"
#import "SentryStacktraceBuilder.h"
#import "SentryThreadInspector.h"
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

        SentryFrameRemover *frameRemover = [[SentryFrameRemover alloc] init];
        SentryStacktraceBuilder *stacktraceBuilder =
            [[SentryStacktraceBuilder alloc] initWithSentryFrameRemover:frameRemover];
        id<SentryCrashMachineContextWrapper> machineContextWrapper =
            [[SentryCrashDefaultMachineContextWrapper alloc] init];

        self.threadInspector =
            [[SentryThreadInspector alloc] initWithStacktraceBuilder:stacktraceBuilder
                                            andMachineContextWrapper:machineContextWrapper];

        NSError *error = nil;

        self.fileManager =
            [[SentryFileManager alloc] initWithDsn:self.options.parsedDsn
                            andCurrentDateProvider:[[SentryDefaultCurrentDateProvider alloc] init]
                                  didFailWithError:&error];
        if (nil != error) {
            [SentryLog logWithMessage:error.localizedDescription andLevel:kSentryLogLevelError];
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
    return [self sendEvent:event withSession:session];
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
    return [self sendEvent:event withSession:session];
}

- (SentryEvent *)buildErrorEvent:(NSError *)error
{
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelError];
    NSString *formatted = [NSString stringWithFormat:@"%@ %ld", error.domain, (long)error.code];
    SentryMessage *message = [[SentryMessage alloc] initWithFormatted:formatted];
    message.message = [error.domain stringByAppendingString:@" %s"];
    message.params = @[ [NSString stringWithFormat:@"%ld", (long)error.code] ];
    event.message = message;
    [self setUserInfo:error.userInfo withEvent:event];
    return event;
}

- (SentryId *)captureEvent:(SentryEvent *)event
               withSession:(SentrySession *)session
                 withScope:(SentryScope *)scope
{
    SentryEvent *preparedEvent = [self prepareEvent:event
                                          withScope:scope
                             alwaysAttachStacktrace:NO];
    return [self sendEvent:preparedEvent withSession:session];
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
    SentryEvent *preparedEvent = [self prepareEvent:event
                                          withScope:scope
                             alwaysAttachStacktrace:alwaysAttachStacktrace];

    if (nil != preparedEvent) {
        [self.transport sendEvent:preparedEvent];
        return preparedEvent.eventId;
    }

    return SentryId.empty;
}

- (SentryId *)sendEvent:(SentryEvent *)event withSession:(SentrySession *)session
{

    if (nil != event) {
        if (nil == session.releaseName || [session.releaseName length] == 0) {
            [SentryLog logWithMessage:DropSessionLogMessage andLevel:kSentryLogLevelDebug];
            [self.transport sendEvent:event];
            return event.eventId;
        }

        [self.transport sendEvent:event withSession:session];
        return event.eventId;
    } else {
        [self captureSession:session];
        return SentryId.empty;
    }
}

- (void)captureSession:(SentrySession *)session
{
    if (nil == session.releaseName || [session.releaseName length] == 0) {
        [SentryLog logWithMessage:DropSessionLogMessage andLevel:kSentryLogLevelDebug];
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
                         andLevel:kSentryLogLevelDebug];
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
    if (nil == sampleRate || [sampleRate floatValue] < 0 || [sampleRate floatValue] > 1) {
        return YES;
    }
    return ([sampleRate floatValue] >= ((double)arc4random() / 0x100000000));
}

- (SentryEvent *_Nullable)prepareEvent:(SentryEvent *)event
                             withScope:(SentryScope *)scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
{
    NSParameterAssert(event);
    if ([self isDisabled]) {
        [self logDisabledMessage];
        return nil;
    }

    if (NO == [self checkSampleRate:self.options.sampleRate]) {
        [SentryLog logWithMessage:@"Event got sampled, will not send the event"
                         andLevel:kSentryLogLevelDebug];
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

    BOOL shouldAttachStacktrace = alwaysAttachStacktrace || self.options.attachStacktrace
        || (nil != event.exceptions && [event.exceptions count] > 0);

    BOOL debugMetaNotAttached = !(nil != event.debugMeta && event.debugMeta.count > 0);
    if (shouldAttachStacktrace && debugMetaNotAttached) {
        event.debugMeta = [self.debugMetaBuilder buildDebugMeta];
    }

    BOOL threadsNotAttached = !(nil != event.threads && event.threads.count > 0);
    if (shouldAttachStacktrace && threadsNotAttached) {
        event.threads = [self.threadInspector getCurrentThreads];
    }

    event = [scope applyToEvent:event maxBreadcrumb:self.options.maxBreadcrumbs];

    // With scope applied, before running callbacks run:
    if (nil == event.environment) {
        // We default to environment 'production' if nothing was set
        event.environment = @"production";
    }

    // Need to do this after the scope is applied cause this sets the user if there is any
    [self setUserIdIfNoUserSet:event];

    event = [self callEventProcessors:event];

    if (nil != self.options.beforeSend) {
        event = self.options.beforeSend(event);
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
                     andLevel:kSentryLogLevelDebug];
}

- (SentryEvent *_Nullable)callEventProcessors:(SentryEvent *)event
{
    SentryEvent *newEvent = event;

    for (SentryEventProcessor processor in SentryGlobalEventProcessor.shared.processors) {
        newEvent = processor(newEvent);
        if (nil == newEvent) {
            [SentryLog logWithMessage:@"SentryScope callEventProcessors: An event "
                                      @"processor decided to remove this event."
                             andLevel:kSentryLogLevelDebug];
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

@end

NS_ASSUME_NONNULL_END
