#import "SentrySDK.h"

@class SentryHub, SentryId, SentryAppStartMeasurement, SentryEnvelope;

NS_ASSUME_NONNULL_BEGIN

@interface
SentrySDK (Private)

+ (void)captureCrashEvent:(SentryEvent *)event;

+ (void)captureCrashEvent:(SentryEvent *)event withScope:(SentryScope *)scope;

/**
 * SDK private field to store the state if onCrashedLastRun was called.
 */
@property (nonatomic, class) BOOL crashedLastRunCalled;

+ (void)setAppStartMeasurement:(nullable SentryAppStartMeasurement *)appStartMeasurement;

+ (nullable SentryAppStartMeasurement *)getAppStartMeasurement;

@property (nonatomic, class) NSUInteger startInvocations;

+ (SentryHub *)currentHub;

@property (nonatomic, nullable, readonly, class) SentryOptions *options;

/**
 * Needed by hybrid SDKs as react-native to synchronously store an envelope to disk.
 */
+ (void)storeEnvelope:(SentryEnvelope *)envelope;

/**
 * Needed by hybrid SDKs as react-native to synchronously capture an envelope.
 */
+ (void)captureEnvelope:(SentryEnvelope *)envelope;

/**
 * Start a transaction with a name and a name source.
 */
+ (id<SentrySpan>)startTransactionWithName:(NSString *)name
                                nameSource:(SentryTransactionNameSource)source
                                 operation:(NSString *)operation;

+ (id<SentrySpan>)startTransactionWithName:(NSString *)name
                                nameSource:(SentryTransactionNameSource)source
                                 operation:(NSString *)operation
                               bindToScope:(BOOL)bindToScope;

@end

NS_ASSUME_NONNULL_END
