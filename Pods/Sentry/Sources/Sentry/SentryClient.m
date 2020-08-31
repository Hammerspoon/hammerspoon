#import "SentryClient.h"
#import "SentryCrashDefaultBinaryImageProvider.h"
#import "SentryCrashDefaultMachineContextWrapper.h"
#import "SentryDebugMetaBuilder.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryDsn.h"
#import "SentryGlobalEventProcessor.h"
#import "SentryLog.h"
#import "SentryMeta.h"
#import "SentryScope.h"
#import "SentryStacktraceBuilder.h"
#import "SentryThreadInspector.h"
#import "SentryTransportFactory.h"

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

@implementation SentryClient

- (_Nullable instancetype)initWithOptions:(SentryOptions *)options
{
    if (self = [super init]) {
        self.options = options;

        SentryCrashDefaultBinaryImageProvider *provider =
            [[SentryCrashDefaultBinaryImageProvider alloc] init];

        self.debugMetaBuilder =
            [[SentryDebugMetaBuilder alloc] initWithBinaryImageProvider:provider];

        SentryStacktraceBuilder *stacktraceBuilder = [[SentryStacktraceBuilder alloc] init];
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

- (NSString *_Nullable)captureMessage:(NSString *)message withScope:(SentryScope *_Nullable)scope
{
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelInfo];
    event.message = message;
    return [self sendEvent:event withScope:scope alwaysAttachStacktrace:NO];
}

- (NSString *_Nullable)captureException:(NSException *)exception
                              withScope:(SentryScope *_Nullable)scope
{
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelError];
    event.message = exception.reason;
    [self setUserInfo:exception.userInfo withEvent:event];
    return [self sendEvent:event withScope:scope alwaysAttachStacktrace:YES];
}

- (NSString *_Nullable)captureError:(NSError *)error withScope:(SentryScope *_Nullable)scope
{
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelError];
    event.message = error.localizedDescription;
    [self setUserInfo:error.userInfo withEvent:event];
    return [self sendEvent:event withScope:scope alwaysAttachStacktrace:YES];
}

- (NSString *_Nullable)captureEvent:(SentryEvent *)event withScope:(SentryScope *_Nullable)scope
{
    return [self sendEvent:event withScope:scope alwaysAttachStacktrace:NO];
}

- (NSString *_Nullable)sendEvent:(SentryEvent *)event
                       withScope:(SentryScope *_Nullable)scope
          alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
{
    SentryEvent *preparedEvent = [self prepareEvent:event
                                          withScope:scope
                             alwaysAttachStacktrace:alwaysAttachStacktrace];
    if (nil != preparedEvent) {
        if (nil != self.options.beforeSend) {
            preparedEvent = self.options.beforeSend(preparedEvent);
        }
        if (nil != preparedEvent) {
            [self.transport sendEvent:preparedEvent withCompletionHandler:nil];
            return preparedEvent.eventId;
        }
    }
    return nil;
}

- (void)captureSession:(SentrySession *)session
{
    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithSession:session];
    [self captureEnvelope:envelope];
}

// TODO: We remove this function It is not in the header and nobody uses it
- (void)captureSessions:(NSArray<SentrySession *> *)sessions
{
    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithSessions:sessions];
    [self captureEnvelope:envelope];
}

- (NSString *_Nullable)captureEnvelope:(SentryEnvelope *)envelope
{
    // TODO: What is about beforeSend
    [self.transport sendEnvelope:envelope withCompletionHandler:nil];
    return envelope.header.eventId;
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
                             withScope:(SentryScope *_Nullable)scope
                alwaysAttachStacktrace:(BOOL)alwaysAttachStacktrace
{
    NSParameterAssert(event);

    if (NO == [self.options.enabled boolValue]) {
        [SentryLog logWithMessage:@"SDK is disabled, will not do anything"
                         andLevel:kSentryLogLevelDebug];
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

    BOOL shouldAttachStacktrace = alwaysAttachStacktrace ||
        [self.options.attachStacktrace boolValue]
        || (nil != event.exceptions && [event.exceptions count] > 0);

    BOOL debugMetaNotAttached = !(nil != event.debugMeta && event.debugMeta.count > 0);
    if (shouldAttachStacktrace && debugMetaNotAttached) {
        event.debugMeta = [self.debugMetaBuilder buildDebugMeta];
    }

    BOOL threadsNotAttached = !(nil != event.threads && event.threads.count > 0);
    if (shouldAttachStacktrace && threadsNotAttached) {
        // We don't want to add the stacktrace of attaching the stacktrace.
        // Therefore we skip three frames.
        event.threads = [self.threadInspector getCurrentThreadsSkippingFrames:3];
    }

    if (nil != scope) {
        event = [scope applyToEvent:event maxBreadcrumb:self.options.maxBreadcrumbs];
    }

    return [self callEventProcessors:event];
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

        [context setValue:userInfo forKey:@"user info"];
    }
}

@end

NS_ASSUME_NONNULL_END
