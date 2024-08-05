#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryId;

static NSString *const SENTRY_BAGGAGE_HEADER = @"baggage";

@interface SentryBaggage : NSObject

/*
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
 * The id attribute of the user context.
 */
@property (nullable, nonatomic, readonly) NSString *userId;

/**
 * The value of a segment attribute in the user's data bag, if it exists.
 */
@property (nullable, nonatomic, readonly) NSString *userSegment;

/**
 * The sample rate.
 */
@property (nullable, nonatomic, readonly) NSString *sampleRate;

/**
 * Value indicating whether the trace was sampled.
 */
@property (nullable, nonatomic, strong) NSString *sampled;

@property (nullable, nonatomic, strong) NSString *replayId;

- (instancetype)initWithTraceId:(SentryId *)traceId
                      publicKey:(NSString *)publicKey
                    releaseName:(nullable NSString *)releaseName
                    environment:(nullable NSString *)environment
                    transaction:(nullable NSString *)transaction
                    userSegment:(nullable NSString *)userSegment
                     sampleRate:(nullable NSString *)sampleRate
                        sampled:(nullable NSString *)sampled
                       replayId:(nullable NSString *)replayId;

- (NSString *)toHTTPHeaderWithOriginalBaggage:(NSDictionary *_Nullable)originalBaggage;

@end

NS_ASSUME_NONNULL_END
