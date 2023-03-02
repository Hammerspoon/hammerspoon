#import "SentryIntegrationProtocol.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryDeviceContextFreeMemoryKey = @"free_memory";

@interface SentryCrashIntegration : NSObject <SentryIntegrationProtocol>

@end

NS_ASSUME_NONNULL_END
