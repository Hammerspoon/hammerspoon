#import "SentryIntegrationProtocol.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryOutOfMemoryTrackingIntegration : NSObject <SentryIntegrationProtocol>

- (void)stop;

@end

NS_ASSUME_NONNULL_END
