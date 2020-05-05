#import "SentryClient.h"
#import "SentryLog.h"
#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryUser.h"
#import "SentryQueueableRequestManager.h"
#import "SentryEvent.h"
#import "SentryCrashInstallationReporter.h"
#import "SentryFileManager.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryCrash.h"
#import "SentryOptions.h"
#import "SentryScope.h"
#import "SentryHttpTransport.h"
#import "SentryTransport.h"
#import "SentryTransportFactory.h"
#import "SentrySDK.h"
#import "SentryIntegrationProtocol.h"
#import "SentryGlobalEventProcessor.h"
#import "SentrySession.h"
#import "SentryEnvelope.h"

#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryClient ()

@property(nonatomic, strong) id <SentryTransport> transport;
@property(nonatomic, strong) SentryFileManager* fileManager;

@end

@implementation SentryClient

#pragma mark Initializer

- (_Nullable instancetype)initWithOptions:(SentryOptions *)options {
    if (self = [super init]) {
        self.options = options;
    }
    return self;
}

- (id<SentryTransport>)transport {
    if (_transport == nil) {
        _transport = [SentryTransportFactory initTransport:self.options sentryFileManager: self.fileManager];
    }
    return _transport;
}

- (SentryFileManager*)fileManager {
    if(_fileManager == nil) {
        NSError* error = nil;
        SentryFileManager *fileManager = [[SentryFileManager alloc] initWithDsn:self.options.dsn didFailWithError:&error];
        if (nil != error) {
            [SentryLog logWithMessage:(error).localizedDescription andLevel:kSentryLogLevelError];
            return nil;
        }
        _fileManager = fileManager;
    }
    return _fileManager;
}

- (NSString *_Nullable)captureMessage:(NSString *)message withScope:(SentryScope *_Nullable)scope {
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelInfo];
    // TODO: Attach stacktrace?
    event.message = message;
    return [self captureEvent:event withScope:scope];
}

- (NSString *_Nullable)captureException:(NSException *)exception withScope:(SentryScope *_Nullable)scope {
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelError];
    // TODO: Capture Stacktrace
    event.message = exception.reason;
    return [self captureEvent:event withScope:scope];
}

- (NSString *_Nullable)captureError:(NSError *)error withScope:(SentryScope *_Nullable)scope {
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelError];
    // TODO: Capture Stacktrace
    event.message = error.localizedDescription;
    return [self captureEvent:event withScope:scope];
}

- (NSString *_Nullable)captureEvent:(SentryEvent *)event withScope:(SentryScope *_Nullable)scope {
    SentryEvent *preparedEvent = [self prepareEvent:event withScope:scope];
    if (nil != preparedEvent) {
        if (nil != self.options.beforeSend) {
            event = self.options.beforeSend(event);
        }
        if (nil != event) {
            [self.transport sendEvent:preparedEvent withCompletionHandler:nil];
            return event.eventId;
        }
    }
    return nil;
}

- (void)captureSession:(SentrySession *)session {
    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithSession:session];
    [self captureEnvelope:envelope];
}

- (void)captureSessions:(NSArray<SentrySession *> *)sessions {
    SentryEnvelope *envelope = [[SentryEnvelope alloc] initWithSessions:sessions];
    [self captureEnvelope:envelope];
}

- (NSString *_Nullable)captureEnvelope:(SentryEnvelope *)envelope {
    // TODO: What is about beforeSend
    [self.transport sendEnvelope:envelope withCompletionHandler:nil];
    return envelope.header.eventId;
}

/**
 * returns BOOL chance of YES is defined by sampleRate.
 * if sample rate isn't within 0.0 - 1.0 it returns YES (like if sampleRate is 1.0)
 */
- (BOOL)checkSampleRate:(NSNumber *)sampleRate {
    if (nil == sampleRate || [sampleRate floatValue] < 0 || [sampleRate floatValue] > 1) {
        return YES;
    }
    return ([sampleRate floatValue] >= ((double)arc4random() / 0x100000000));
}

#pragma mark prepareEvent

- (SentryEvent *_Nullable)prepareEvent:(SentryEvent *)event
                             withScope:(SentryScope *_Nullable)scope {
    NSParameterAssert(event);
    
    if (NO == [self.options.enabled boolValue]) {
        [SentryLog logWithMessage:@"SDK is disabled, will not do anything" andLevel:kSentryLogLevelDebug];
        return nil;
    }
    
    if (NO == [self checkSampleRate:self.options.sampleRate]) {
        [SentryLog logWithMessage:@"Event got sampled, will not send the event" andLevel:kSentryLogLevelDebug];
        return nil;
    }    

    NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
//    if (nil != infoDict && nil == event.releaseName) {
//        event.releaseName = [NSString stringWithFormat:@"%@@%@+%@", infoDict[@"CFBundleIdentifier"], infoDict[@"CFBundleShortVersionString"],
//            infoDict[@"CFBundleVersion"]];
//    }
    if (nil != infoDict && nil == event.dist) {
        event.dist = infoDict[@"CFBundleVersion"];
    }

    // Use the values from SentryOptions as a fallback,
    // in case not yet set directly in the event nor in the scope:
    NSString *releaseName = self.options.releaseName;
    if (nil != releaseName) {
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
    
    if (nil != scope) {
        event = [scope applyToEvent:event maxBreadcrumb:self.options.maxBreadcrumbs];
    }
    
    return [self callEventProcessors:event];
}

- (SentryEvent *_Nullable)callEventProcessors:(SentryEvent *)event {
    SentryEvent *newEvent = event;

    for (SentryEventProcessor processor in SentryGlobalEventProcessor.shared.processors) {
        newEvent = processor(newEvent);
        if (nil == newEvent) {
            [SentryLog logWithMessage:@"SentryScope callEventProcessors: An event processor decided to remove this event." andLevel:kSentryLogLevelDebug];
            break;
        }
    }
    return newEvent;
}

@end

NS_ASSUME_NONNULL_END
