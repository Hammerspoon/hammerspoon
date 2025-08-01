#import "SentryANRTrackingIntegration.h"
#import "SentryClient+Private.h"
#import "SentryCrashMachineContext.h"
#import "SentryCrashWrapper.h"
#import "SentryDebugImageProvider+HybridSDKs.h"
#import "SentryDependencyContainer.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryFileManager.h"
#import "SentryHub+Private.h"
#import "SentryLogC.h"
#import "SentryMechanism.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"
#import "SentryStacktrace.h"
#import "SentrySwift.h"
#import "SentryThread.h"
#import "SentryThreadInspector.h"
#import "SentryThreadWrapper.h"
#import "SentryUIApplication.h"
#import <SentryCrashWrapper.h>
#import <SentryOptions+Private.h>

#if SENTRY_HAS_UIKIT
#    import <UIKit/UIKit.h>
#endif

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryANRMechanismDataAppHangDuration = @"app_hang_duration";

@interface SentryANRTrackingIntegration () <SentryANRTrackerDelegate>

@property (nonatomic, strong) id<SentryANRTracker> tracker;
@property (nonatomic, strong) SentryOptions *options;
@property (nonatomic, strong) SentryFileManager *fileManager;
@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueueWrapper;
@property (nonatomic, strong) SentryCrashWrapper *crashWrapper;
@property (nonatomic, strong) SentryDebugImageProvider *debugImageProvider;
@property (atomic, assign) BOOL reportAppHangs;
@property (atomic, assign) BOOL enableReportNonFullyBlockingAppHangs;

@end

@implementation SentryANRTrackingIntegration

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

#if SENTRY_HAS_UIKIT
    self.tracker =
        [SentryDependencyContainer.sharedInstance getANRTracker:options.appHangTimeoutInterval
                                                    isV2Enabled:options.enableAppHangTrackingV2];
#else
    self.tracker =
        [SentryDependencyContainer.sharedInstance getANRTracker:options.appHangTimeoutInterval];

#endif // SENTRY_HAS_UIKIT
    self.fileManager = SentryDependencyContainer.sharedInstance.fileManager;
    self.dispatchQueueWrapper = SentryDependencyContainer.sharedInstance.dispatchQueueWrapper;
    self.crashWrapper = SentryDependencyContainer.sharedInstance.crashWrapper;
    self.debugImageProvider = SentryDependencyContainer.sharedInstance.debugImageProvider;
    [self.tracker addListener:self];
    self.options = options;
    self.reportAppHangs = YES;

#if SENTRY_HAS_UIKIT
    [self captureStoredAppHangEvent];
#endif // SENTRY_HAS_UIKIT

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

- (void)anrDetectedWithType:(enum SentryANRType)type
{
    if (self.reportAppHangs == NO) {
        SENTRY_LOG_DEBUG(@"AppHangTracking paused. Ignoring reported app hang.")
        return;
    }

#if SENTRY_HAS_UIKIT
    if (type == SentryANRTypeNonFullyBlocking
        && !self.options.enableReportNonFullyBlockingAppHangs) {
        SENTRY_LOG_DEBUG(@"Ignoring non fully blocking app hang.")
        return;
    }

    // If the app is not active, the main thread may be blocked or too busy.
    // Since there is no UI for the user to interact, there is no need to report app hang.
    if (SentryDependencyContainer.sharedInstance.application.applicationState
        != UIApplicationStateActive) {
        return;
    }
#endif // SENTRY_HAS_UIKIT
    SentryThreadInspector *threadInspector = SentrySDK.currentHub.getClient.threadInspector;

    NSArray<SentryThread *> *threads = [threadInspector getCurrentThreadsWithStackTrace];

    if (threads.count == 0) {
        SENTRY_LOG_WARN(@"Getting current thread returned an empty list. Can't create AppHang "
                        @"event without a stacktrace.");
        return;
    }

    NSString *appHangDurationInfo = [NSString
        stringWithFormat:@"at least %li ms", (long)(self.options.appHangTimeoutInterval * 1000)];
    NSString *message = [NSString stringWithFormat:@"App hanging for %@.", appHangDurationInfo];
    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelError];

    NSString *exceptionType = [SentryAppHangTypeMapper getExceptionTypeWithAnrType:type];
    SentryException *sentryException = [[SentryException alloc] initWithValue:message
                                                                         type:exceptionType];

    SentryMechanism *mechanism = [[SentryMechanism alloc] initWithType:@"AppHang"];
    sentryException.mechanism = mechanism;
    sentryException.stacktrace = [threads[0] stacktrace];
    sentryException.stacktrace.snapshot = @(YES);

    [threads enumerateObjectsUsingBlock:^(SentryThread *_Nonnull obj, NSUInteger idx,
        BOOL *_Nonnull stop) { obj.current = [NSNumber numberWithBool:idx == 0]; }];

    event.exceptions = @[ sentryException ];
    event.threads = threads;

    // When storing the app hang event to disk, it could turn into a fatal one, and then we can't
    // recover the debug images. The client would also attach the debug images when directly
    // capturing the app hang event. Still, we attach them already now to ensure all app hang events
    // have debug images cause it's easy to mess this up in the future.
    event.debugMeta = [self.debugImageProvider getDebugImagesFromCacheForThreads:event.threads];

#if SENTRY_HAS_UIKIT
    // We only measure app hang duration for V2.
    // For V1, we directly capture the app hang event.
    if (self.options.enableAppHangTrackingV2) {
        // We only temporarily store the app hang duration info, so we can change the error message
        // when either sending a normal or fatal app hang event. Otherwise, we would have to rely on
        // string parsing to retrieve the app hang duration info from the error message.
        mechanism.data = @{ SentryANRMechanismDataAppHangDuration : appHangDurationInfo };

        // We need to apply the scope now because if the app hang turns into a fatal one,
        // we would lose the scope. Furthermore, we want to know in which state the app was when the
        // app hang started.
        SentryScope *scope = [SentrySDK currentHub].scope;
        SentryOptions *options = SentrySDK.options;
        if (scope != nil && options != nil) {
            [scope applyToEvent:event maxBreadcrumb:options.maxBreadcrumbs];
        }

        [self.fileManager storeAppHangEvent:event];
    } else {
#endif // SENTRY_HAS_UIKIT
        [SentrySDK captureEvent:event];
#if SENTRY_HAS_UIKIT
    }
#endif // SENTRY_UIKIT_AVAILABLE
}

- (void)anrStoppedWithResult:(SentryANRStoppedResult *_Nullable)result
{
#if SENTRY_HAS_UIKIT
    // We only measure app hang duration for V2, and therefore ignore V1.
    if (!self.options.enableAppHangTrackingV2) {
        return;
    }

    if (result == nil) {
        SENTRY_LOG_WARN(@"ANR stopped for V2 but result was nil.")
        return;
    }

    SentryEvent *event = [self.fileManager readAppHangEvent];
    if (event == nil) {
        SENTRY_LOG_WARN(@"AppHang stopped but stored app hang event was nil.")
        return;
    }

    [self.fileManager deleteAppHangEvent];

    // We round to 0.1 seconds accuracy because we can't precicely measure the app hand duration.
    NSString *appHangDurationInfo = [NSString
        stringWithFormat:@"between %.1f and %.1f seconds", result.minDuration, result.maxDuration];
    NSString *errorMessage = [NSString stringWithFormat:@"App hanging %@.", appHangDurationInfo];
    event.exceptions.firstObject.value = errorMessage;

    if (event.exceptions.firstObject.mechanism.data == nil) {
        SENTRY_LOG_WARN(@"Mechanism data of the stored app hang event was nil. This is unexpected, "
                        @"so it's likely that the app hang event is corrupted. Therefore, dropping "
                        @"the stored app hang event.");
        return;
    }

    NSMutableDictionary *mechanismData = [event.exceptions.firstObject.mechanism.data mutableCopy];
    [mechanismData removeObjectForKey:SentryANRMechanismDataAppHangDuration];
    event.exceptions.firstObject.mechanism.data = mechanismData;

    // We already applied the scope. We use an empty scope to avoid overwriting exising fields on
    // the event.
    [SentrySDK captureEvent:event withScope:[[SentryScope alloc] init]];
#endif // SENTRY_HAS_UIKIT
}

#if SENTRY_HAS_UIKIT
- (void)captureStoredAppHangEvent
{
    __weak SentryANRTrackingIntegration *weakSelf = self;
    [self.dispatchQueueWrapper dispatchAsyncWithBlock:^{
        if (weakSelf == nil) {
            return;
        }

        SentryEvent *event = [weakSelf.fileManager readAppHangEvent];
        if (event == nil) {
            return;
        }

        [weakSelf.fileManager deleteAppHangEvent];

        if (weakSelf.crashWrapper.crashedLastLaunch) {
            // The app crashed during an ongoing app hang. Capture the stored app hang as it is.
            // We already applied the scope. We use an empty scope to avoid overwriting exising
            // fields on the event.
            [SentrySDK captureEvent:event withScope:[[SentryScope alloc] init]];
        } else {
            // Fatal App Hang
            // We can't differ if the watchdog or the user terminated the app, because when the main
            // thread is blocked we don't receive the applicationWillTerminate notification. Further
            // investigations are required to validate if we somehow can differ between watchdog or
            // user terminations; see https://github.com/getsentry/sentry-cocoa/issues/4845.

            if (event.exceptions.count != 1) {
                SENTRY_LOG_WARN(@"The stored app hang event is expected to have exactly one "
                                @"exception, so we don't capture it.");
                return;
            }

            event.level = kSentryLevelFatal;

            SentryException *exception = event.exceptions.firstObject;
            exception.mechanism.handled = @(NO);

            NSString *exceptionType = exception.type;
            NSString *fatalExceptionType =
                [SentryAppHangTypeMapper getFatalExceptionTypeWithNonFatalErrorType:exceptionType];

            event.exceptions.firstObject.type = fatalExceptionType;

            NSMutableDictionary *mechanismData =
                [event.exceptions.firstObject.mechanism.data mutableCopy];
            NSString *appHangDurationInfo
                = exception.mechanism.data[SentryANRMechanismDataAppHangDuration];

            [mechanismData removeObjectForKey:SentryANRMechanismDataAppHangDuration];
            event.exceptions.firstObject.mechanism.data = mechanismData;

            NSString *exceptionValue =
                [NSString stringWithFormat:@"The user or the OS watchdog terminated your app while "
                                           @"it blocked the main thread for %@.",
                    appHangDurationInfo];
            event.exceptions.firstObject.value = exceptionValue;

            // We already applied the scope. We use an empty scope to avoid overwriting exising
            // fields on the event.
            [SentrySDK captureFatalAppHangEvent:event];
        }
    }];
}

#endif // SENTRY_HAS_UIKIT

@end

NS_ASSUME_NONNULL_END
