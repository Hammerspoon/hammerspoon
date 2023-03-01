#import "SentryCoreDataTrackingIntegration.h"
#import "SentryCoreDataSwizzling.h"
#import "SentryCoreDataTracker.h"
#import "SentryLog.h"
#import "SentryNSDataSwizzling.h"
#import "SentryOptions.h"

@interface
SentryCoreDataTrackingIntegration ()

@property (nonatomic, strong) SentryCoreDataTracker *tracker;

@end

@implementation SentryCoreDataTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    self.tracker = [[SentryCoreDataTracker alloc] init];
    [SentryCoreDataSwizzling.sharedInstance startWithMiddleware:self.tracker];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableAutoPerformanceTracing | kIntegrationOptionEnableSwizzling
        | kIntegrationOptionIsTracingEnabled | kIntegrationOptionEnableCoreDataTracing;
}

- (void)uninstall
{
    [SentryCoreDataSwizzling.sharedInstance stop];
}

@end
