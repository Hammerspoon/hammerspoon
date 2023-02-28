#import "SentryANRTracker.h"
#import "SentryBaseIntegration.h"
#import "SentryIntegrationProtocol.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryANRTrackingIntegration
    : SentryBaseIntegration <SentryIntegrationProtocol, SentryANRTrackerDelegate>

@end

NS_ASSUME_NONNULL_END
