#import "SentryDateUtils.h"
#import "SentryEvent+Private.h"
#import "SentryFileManager.h"
#import <Foundation/Foundation.h>
#import <SentryAppState.h>
#import <SentryAppStateManager.h>
#import <SentryClient+Private.h>
#import <SentryDispatchQueueWrapper.h>
#import <SentryException.h>
#import <SentryHub.h>
#import <SentryLog.h>
#import <SentryMechanism.h>
#import <SentryMessage.h>
#import <SentryOptions.h>
#import <SentrySDK+Private.h>
#import <SentryWatchdogTerminationLogic.h>
#import <SentryWatchdogTerminationTracker.h>

@interface
SentryWatchdogTerminationTracker ()

@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) SentryWatchdogTerminationLogic *watchdogTerminationLogic;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;
@property (nonatomic, strong) SentryAppStateManager *appStateManager;
@property (nonatomic, strong) SentryFileManager *fileManager;

@end

@implementation SentryWatchdogTerminationTracker

- (instancetype)initWithOptions:(SentryOptions *)options
       watchdogTerminationLogic:(SentryWatchdogTerminationLogic *)watchdogTerminationLogic
                appStateManager:(SentryAppStateManager *)appStateManager
           dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                    fileManager:(SentryFileManager *)fileManager
{
    if (self = [super init]) {
        self.options = options;
        self.watchdogTerminationLogic = watchdogTerminationLogic;
        self.appStateManager = appStateManager;
        self.dispatchQueue = dispatchQueueWrapper;
        self.fileManager = fileManager;
    }
    return self;
}

- (void)start
{
#if SENTRY_HAS_UIKIT
    [self.appStateManager start];

    [self.dispatchQueue dispatchAsyncWithBlock:^{
        if ([self.watchdogTerminationLogic isWatchdogTermination]) {
            SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelFatal];
            // Set to empty list so no breadcrumbs of the current scope are added
            event.breadcrumbs = @[];

            // Load the previous breadcrumbs from disk, which are already serialized
            event.serializedBreadcrumbs = [self.fileManager readPreviousBreadcrumbs];
            if (event.serializedBreadcrumbs.count > self.options.maxBreadcrumbs) {
                event.serializedBreadcrumbs = [event.serializedBreadcrumbs
                    subarrayWithRange:NSMakeRange(event.serializedBreadcrumbs.count
                                              - self.options.maxBreadcrumbs,
                                          self.options.maxBreadcrumbs)];
            }

            NSDictionary *lastBreadcrumb = event.serializedBreadcrumbs.lastObject;
            if (lastBreadcrumb && [lastBreadcrumb objectForKey:@"timestamp"]) {
                NSString *timestampIso8601String = [lastBreadcrumb objectForKey:@"timestamp"];
                event.timestamp = sentry_fromIso8601String(timestampIso8601String);
            }

            SentryException *exception =
                [[SentryException alloc] initWithValue:SentryWatchdogTerminationExceptionValue
                                                  type:SentryWatchdogTerminationExceptionType];
            SentryMechanism *mechanism =
                [[SentryMechanism alloc] initWithType:SentryWatchdogTerminationMechanismType];
            mechanism.handled = @(NO);
            exception.mechanism = mechanism;
            event.exceptions = @[ exception ];

            // We don't need to update the releaseName of the event to the previous app state as we
            // assume it's not an OOM when the releaseName changed between app starts.
            [SentrySDK captureCrashEvent:event];
        }
    }];
#else // !SENTRY_HAS_UIKIT
    SENTRY_LOG_INFO(
        @"NO UIKit -> SentryWatchdogTerminationTracker will not track Watchdog Terminations.");
    return;
#endif // SENTRY_HAS_UIKIT
}

- (void)stop
{
#if SENTRY_HAS_UIKIT
    [self.appStateManager stop];
#endif // SENTRY_HAS_UIKIT
}

@end
