#import "SentryId.h"
#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryScope, SentryOptions, SentryTracer, SentryUser, SentryBaggage;

@interface SentryTraceContext : NSObject <SentrySerializable>

/**
 * UUID V4 encoded as a hexadecimal sequence with no dashes (e.g. 771a43a4192642f0b136d5159a501700)
 * that is a sequence of 32 hexadecimal digits.
 */
@property (nonatomic, readonly) SentryId *traceId;

/**
 * Public key from the DSN used by the SDK.
 */
@property (nonatomic, readonly) NSString *publicKey;

/**
 * The release name as specified in client options, usually: package@x.y.z+build.
 */
@property (nullable, nonatomic, readonly) NSString *releaseName;

/**
 * The environment name as specified in client options, for example staging.
 */
@property (nullable, nonatomic, readonly) NSString *environment;

/**
 * The transaction name set on the scope.
 */
@property (nullable, nonatomic, readonly) NSString *transaction;

/**
 * A subset of the scope's user context.
 */
@property (nullable, nonatomic, readonly) NSString *userSegment;

/**
 * Sample rate used for this trace.
 */
@property (nullable, nonatomic) NSString *sampleRate;

/**
 * Initializes a SentryTraceContext with given properties.
 */
- (instancetype)initWithTraceId:(SentryId *)traceId
                      publicKey:(NSString *)publicKey
                    releaseName:(nullable NSString *)releaseName
                    environment:(nullable NSString *)environment
                    transaction:(nullable NSString *)transaction
                    userSegment:(nullable NSString *)userSegment
                     sampleRate:(nullable NSString *)sampleRate;

/**
 * Initializes a SentryTraceContext with data from scope and options.
 */
- (nullable instancetype)initWithScope:(SentryScope *)scope options:(SentryOptions *)options;

/**
 * Initializes a SentryTraceContext with data from a dictionary.
 */
- (nullable instancetype)initWithDict:(NSDictionary<NSString *, id> *)dictionary;

/**
 * Initializes a SentryTraceContext with data from a trace, scope and options.
 */
- (nullable instancetype)initWithTracer:(SentryTracer *)tracer
                                  scope:(nullable SentryScope *)scope
                                options:(SentryOptions *)options;

/**
 * Create a SentryBaggage with the information of this SentryTraceContext.
 */
- (SentryBaggage *)toBaggage;
@end

NS_ASSUME_NONNULL_END
