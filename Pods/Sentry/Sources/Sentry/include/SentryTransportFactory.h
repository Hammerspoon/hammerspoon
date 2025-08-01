#import "SentryTransport.h"

@class SentryFileManager;
@class SentryOptions;
@protocol SentryCurrentDateProvider;
@protocol SentryRateLimits;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TransportInitializer)
@interface SentryTransportFactory : NSObject

+ (NSArray<id<SentryTransport>> *)initTransports:(SentryOptions *)options
                                    dateProvider:(id<SentryCurrentDateProvider>)dateProvider
                               sentryFileManager:(SentryFileManager *)sentryFileManager
                                      rateLimits:(id<SentryRateLimits>)rateLimits;

@end

NS_ASSUME_NONNULL_END
