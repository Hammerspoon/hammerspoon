#import "SentryHub.h"

@class SentryEnvelopeItem;
@class SentryId;
@class SentryScope;
@class SentryTransaction;
@class SentryDispatchQueueWrapper;
@class SentryEnvelope;
@class SentryNSTimerFactory;
@class SentrySession;
@class SentryTracer;
@class SentryTracerConfiguration;
@class SentryReplayEvent;
@class SentryReplayRecording;
@protocol SentryIntegrationProtocol;
@protocol SentrySessionListener;

NS_ASSUME_NONNULL_BEGIN

@interface
SentryHub ()

@property (nullable, nonatomic, strong) SentrySession *session;

@property (nonatomic, strong) NSMutableArray<id<SentryIntegrationProtocol>> *installedIntegrations;

/**
 * Every integration starts with "Sentry" and ends with "Integration". To keep the payload of the
 * event small we remove both.
 */
- (NSMutableArray<NSString *> *)trimmedInstalledIntegrationNames;

- (void)addInstalledIntegration:(id<SentryIntegrationProtocol>)integration name:(NSString *)name;
- (void)removeAllIntegrations;

- (SentryClient *_Nullable)client;

- (void)captureCrashEvent:(SentryEvent *)event;

- (void)captureCrashEvent:(SentryEvent *)event withScope:(SentryScope *)scope;

- (void)captureReplayEvent:(SentryReplayEvent *)replayEvent
           replayRecording:(SentryReplayRecording *)replayRecording
                     video:(NSURL *)videoURL;

- (void)closeCachedSessionWithTimestamp:(NSDate *_Nullable)timestamp;

- (SentryTracer *)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
                                configuration:(SentryTracerConfiguration *)configuration;

- (SentryId *)captureEvent:(SentryEvent *)event
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems
    NS_SWIFT_NAME(capture(event:scope:additionalEnvelopeItems:));

- (void)captureTransaction:(SentryTransaction *)transaction withScope:(SentryScope *)scope;

- (void)captureTransaction:(SentryTransaction *)transaction
                  withScope:(SentryScope *)scope
    additionalEnvelopeItems:(NSArray<SentryEnvelopeItem *> *)additionalEnvelopeItems;

- (void)storeEnvelope:(SentryEnvelope *)envelope;
- (void)captureEnvelope:(SentryEnvelope *)envelope;

- (void)registerSessionListener:(id<SentrySessionListener>)listener;
- (void)unregisterSessionListener:(id<SentrySessionListener>)listener;
- (nullable id<SentryIntegrationProtocol>)getInstalledIntegration:(Class)integrationClass;

@end

NS_ASSUME_NONNULL_END
