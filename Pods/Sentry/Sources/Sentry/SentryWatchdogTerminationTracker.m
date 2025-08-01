#import "SentryDateUtils.h"
#import "SentryEvent+Private.h"
#import "SentryFileManager.h"
#import "SentrySwift.h"
#import <SentryAppState.h>
#import <SentryAppStateManager.h>
#import <SentryClient+Private.h>
#import <SentryException.h>
#import <SentryHub.h>
#import <SentryLogC.h>
#import <SentryMechanism.h>
#import <SentryMessage.h>
#import <SentryOptions.h>
#import <SentrySDK+Private.h>
#import <SentryWatchdogTerminationLogic.h>
#import <SentryWatchdogTerminationTracker.h>

@interface SentryWatchdogTerminationTracker ()

@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) SentryWatchdogTerminationLogic *watchdogTerminationLogic;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;
@property (nonatomic, strong) SentryAppStateManager *appStateManager;
@property (nonatomic, strong) SentryFileManager *fileManager;
@property (nonatomic, strong) SentryScopePersistentStore *scopePersistentStore;

@end

@implementation SentryWatchdogTerminationTracker

- (instancetype)initWithOptions:(SentryOptions *)options
       watchdogTerminationLogic:(SentryWatchdogTerminationLogic *)watchdogTerminationLogic
                appStateManager:(SentryAppStateManager *)appStateManager
           dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                    fileManager:(SentryFileManager *)fileManager
           scopePersistentStore:(SentryScopePersistentStore *)scopePersistentStore
{
    if (self = [super init]) {
        self.options = options;
        self.watchdogTerminationLogic = watchdogTerminationLogic;
        self.appStateManager = appStateManager;
        self.dispatchQueue = dispatchQueueWrapper;
        self.fileManager = fileManager;
        self.scopePersistentStore = scopePersistentStore;
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

            [self addBreadcrumbsToEvent:event];
            [self addContextToEvent:event];
            event.user = [self.scopePersistentStore readPreviousUserFromDisk];
            event.dist = [self.scopePersistentStore readPreviousDistFromDisk];
            event.environment = [self.scopePersistentStore readPreviousEnvironmentFromDisk];
            event.tags = [self.scopePersistentStore readPreviousTagsFromDisk];
            event.extra = [self.scopePersistentStore readPreviousExtrasFromDisk];
            event.fingerprint = [self.scopePersistentStore readPreviousFingerprintFromDisk];
            // Termination events always have fatal level, so we are not reading from disk

            SentryException *exception =
                [[SentryException alloc] initWithValue:SentryWatchdogTerminationExceptionValue
                                                  type:SentryWatchdogTerminationExceptionType];
            SentryMechanism *mechanism =
                [[SentryMechanism alloc] initWithType:SentryWatchdogTerminationMechanismType];
            mechanism.handled = @(NO);
            exception.mechanism = mechanism;
            event.exceptions = @[ exception ];

            // We don't need to update the releaseName of the event to the previous app state as we
            // assume it's not a watchdog termination when the releaseName changed between app
            // starts.
            [SentrySDK captureFatalEvent:event];
        }
    }];
#else // !SENTRY_HAS_UIKIT
    SENTRY_LOG_INFO(
        @"NO UIKit -> SentryWatchdogTerminationTracker will not track Watchdog Terminations.");
    return;
#endif // SENTRY_HAS_UIKIT
}

- (void)addBreadcrumbsToEvent:(SentryEvent *)event
{
    // Set to empty list so no breadcrumbs of the current scope are added
    event.breadcrumbs = @[];

    // Load the previous breadcrumbs from disk, which are already serialized
    event.serializedBreadcrumbs = [self.fileManager readPreviousBreadcrumbs];
    if (event.serializedBreadcrumbs.count > self.options.maxBreadcrumbs) {
        event.serializedBreadcrumbs = [event.serializedBreadcrumbs
            subarrayWithRange:NSMakeRange(
                                  event.serializedBreadcrumbs.count - self.options.maxBreadcrumbs,
                                  self.options.maxBreadcrumbs)];
    }

    NSDictionary *lastBreadcrumb = event.serializedBreadcrumbs.lastObject;
    if (lastBreadcrumb && [lastBreadcrumb objectForKey:@"timestamp"]) {
        NSString *timestampIso8601String = [lastBreadcrumb objectForKey:@"timestamp"];
        event.timestamp = sentry_fromIso8601String(timestampIso8601String);
    }
}

- (void)addContextToEvent:(SentryEvent *)event
{
    // Load the previous context from disk, or create an empty one if it doesn't exist
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *previousContext =
        [self.scopePersistentStore readPreviousContextFromDisk];
    NSMutableDictionary *context =
        [[NSMutableDictionary alloc] initWithDictionary:previousContext ?: @{}];

    // We only report watchdog terminations if the app was in the foreground. So, we can
    // already set it. We can't set it in the client because the client uses the current
    // application state, and the app could be in the background when executing this code.
    NSMutableDictionary *appContext =
        [[NSMutableDictionary alloc] initWithDictionary:event.context[@"app"] ?: @{}];
    appContext[@"in_foreground"] = @(YES);
    context[@"app"] = appContext;

    event.context = context;
}

- (void)stop
{
#if SENTRY_HAS_UIKIT
    [self.appStateManager stop];
#endif // SENTRY_HAS_UIKIT
}

@end
