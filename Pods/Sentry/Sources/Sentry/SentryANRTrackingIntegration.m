#import "SentryANRTrackingIntegration.h"
#import "SentryANRTracker.h"
#import "SentryClient+Private.h"
#import "SentryCrashMachineContext.h"
#import "SentryCrashWrapper.h"
#import "SentryDependencyContainer.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentryMechanism.h"
#import "SentrySDK+Private.h"
#import "SentryStacktrace.h"
#import "SentryThread.h"
#import "SentryThreadInspector.h"
#import "SentryThreadWrapper.h"
#import "SentryUIApplication.h"
#import <SentryOptions+Private.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

@interface
SentryANRTrackingIntegration ()

@property (nonatomic, strong) SentryANRTracker *tracker;
@property (nonatomic, strong) SentryOptions *options;
@property (atomic, assign) BOOL reportAppHangs;

@end

@implementation SentryANRTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    self.tracker =
        [SentryDependencyContainer.sharedInstance getANRTracker:options.appHangTimeoutInterval];

    [self.tracker addListener:self];
    self.options = options;
    self.reportAppHangs = YES;

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionEnableAppHangTracking | kIntegrationOptionDebuggerNotAttached;
}

- (void)pauseAppHangTracking
{
    self.reportAppHangs = NO;
}

- (void)resumeAppHangTracking
{
    self.reportAppHangs = YES;
}

- (void)uninstall
{
    [self.tracker removeListener:self];
}

- (void)dealloc
{
    [self uninstall];
}

- (void)anrDetected
{
    if (self.reportAppHangs == NO) {
        SENTRY_LOG_DEBUG(@"AppHangTracking paused. Ignoring reported app hang.")
        return;
    }

#if SENTRY_HAS_UIKIT
    // If the app is not active, the main thread may be blocked or too busy.
    // Since there is no UI for the user to interact, there is no need to report app hang.
    if (SentryDependencyContainer.sharedInstance.application.applicationState
        != UIApplicationStateActive) {
        return;
    }
#endif
    SentryThreadInspector *threadInspector = SentrySDK.currentHub.getClient.threadInspector;

    NSArray<SentryThread *> *threads = [threadInspector getCurrentThreadsWithStackTrace];

    if (threads.count == 0) {
        SENTRY_LOG_WARN(@"Getting current thread returned an empty list. Can't create AppHang "
                        @"event without a stacktrace.");
        return;
    }

    NSString *message = [NSString stringWithFormat:@"App hanging for at least %li ms.",
                                  (long)(self.options.appHangTimeoutInterval * 1000)];
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelError];
    SentryException *sentryException =
        [[SentryException alloc] initWithValue:message type:SentryANRExceptionType];

    sentryException.mechanism = [[SentryMechanism alloc] initWithType:@"AppHang"];
    sentryException.stacktrace = [threads[0] stacktrace];
    sentryException.stacktrace.snapshot = @(YES);

    [threads enumerateObjectsUsingBlock:^(SentryThread *_Nonnull obj, NSUInteger idx,
        BOOL *_Nonnull stop) { obj.current = [NSNumber numberWithBool:idx == 0]; }];

    event.exceptions = @[ sentryException ];
    event.threads = threads;

    [SentrySDK captureEvent:event];
}

- (void)anrStopped
{
    // We dont report when an ANR ends.
}

@end

NS_ASSUME_NONNULL_END
