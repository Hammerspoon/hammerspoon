#import <Foundation/Foundation.h>

#import "SentryOptions.h"
#import "SentryTransport.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TransportInitializer)
@interface SentryTransportFactory : NSObject

+ (id<SentryTransport>)initTransport:(SentryOptions *)options
                   sentryFileManager:(SentryFileManager *)sentryFileManager;

@end

NS_ASSUME_NONNULL_END
