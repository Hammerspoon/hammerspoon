#import "SentryIntegrationProtocol.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Integration to setup automatic performance tracking.
 *
 * Automatic UI performance setup can be avoided by setting
 * enableAutoUIPerformanceTracking to NO
 * in SentryOptions during SentrySDK initialization.
 */
@interface SentryPerformanceTrackingIntegration : NSObject <SentryIntegrationProtocol>

@end

NS_ASSUME_NONNULL_END
