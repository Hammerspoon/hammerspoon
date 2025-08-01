#import "SentryDefines.h"

@class SentryAppStateManager;
@class SentryDispatchQueueWrapper;
@class SentryFileManager;
@class SentryOptions;
@class SentryWatchdogTerminationLogic;
@class SentryScopePersistentStore;

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryWatchdogTerminationExceptionType = @"WatchdogTermination";
static NSString *const SentryWatchdogTerminationExceptionValue
    = @"The OS watchdog terminated your app, possibly because it overused RAM.";
static NSString *const SentryWatchdogTerminationMechanismType = @"watchdog_termination";

/**
 * Detect watchdog terminations based on heuristics described in a blog post:
 * https://engineering.fb.com/2015/08/24/ios/reducing-fooms-in-the-facebook-ios-app/ If a watchdog
 * termination is detected, the SDK sends it as crash event. Only works for iOS, tvOS and
 * macCatalyst.
 */
@interface SentryWatchdogTerminationTracker : NSObject
SENTRY_NO_INIT

- (instancetype)initWithOptions:(SentryOptions *)options
       watchdogTerminationLogic:(SentryWatchdogTerminationLogic *)watchdogTerminationLogic
                appStateManager:(SentryAppStateManager *)appStateManager
           dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                    fileManager:(SentryFileManager *)fileManager
           scopePersistentStore:(SentryScopePersistentStore *)scopeStore;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END
