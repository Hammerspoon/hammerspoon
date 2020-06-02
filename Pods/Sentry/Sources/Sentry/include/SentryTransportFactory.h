#import <Foundation/Foundation.h>

#import "SentryTransport.h"
#import "SentryOptions.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(TransportInitializer)
@interface SentryTransportFactory : NSObject

+ (id<SentryTransport>_Nonnull) initTransport:(SentryOptions *) options
                            sentryFileManager:(SentryFileManager *)sentryFileManager;

@end

NS_ASSUME_NONNULL_END
