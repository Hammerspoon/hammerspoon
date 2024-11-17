#import <Foundation/Foundation.h>

#import "SentryTransport.h"

@class SentryOptions, SentryFileManager;
@class SentryCurrentDateProvider;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TransportInitializer)
@interface SentryTransportFactory : NSObject

+ (NSArray<id<SentryTransport>> *)initTransports:(SentryOptions *)options
                               sentryFileManager:(SentryFileManager *)sentryFileManager
                             currentDateProvider:(SentryCurrentDateProvider *)currentDateProvider;

@end

NS_ASSUME_NONNULL_END
