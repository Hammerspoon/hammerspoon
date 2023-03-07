#import "SentryUIEventTrackingIntegration.h"
#import <Foundation/Foundation.h>
#import <SentryDependencyContainer.h>
#import <SentryLog.h>
#import <SentryNSDataSwizzling.h>
#import <SentryOptions+Private.h>
#import <SentryOptions.h>
#import <SentryUIEventTracker.h>

#if SENTRY_HAS_UIKIT
@interface
SentryUIEventTrackingIntegration ()

@property (nonatomic, strong) SentryUIEventTracker *uiEventTracker;

@end

@implementation SentryUIEventTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    SentryDependencyContainer *dependencies = [SentryDependencyContainer sharedInstance];
    self.uiEventTracker = [[SentryUIEventTracker alloc]
        initWithSwizzleWrapper:[SentryDependencyContainer sharedInstance].swizzleWrapper
          dispatchQueueWrapper:dependencies.dispatchQueueWrapper
                   idleTimeout:options.idleTimeout];

    [self.uiEventTracker start];

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableAutoPerformanceTracing | kIntegrationOptionEnableSwizzling
        | kIntegrationOptionIsTracingEnabled | kIntegrationOptionEnableUserInteractionTracing;
}

- (void)uninstall
{
    if (self.uiEventTracker) {
        [self.uiEventTracker stop];
    }
}

@end
#endif
