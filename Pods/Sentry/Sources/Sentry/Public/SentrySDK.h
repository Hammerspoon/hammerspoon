#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif

@protocol SentrySpan;

@class SentryBreadcrumb;
@class SentryEvent;
@class SentryFeedback;
@class SentryFeedbackAPI;
@class SentryId;
@class SentryMetricsAPI;
@class SentryOptions;
@class SentryReplayApi;
@class SentryScope;
@class SentryTransactionContext;
@class SentryUser;
@class SentryUserFeedback;
@class UIView;

NS_ASSUME_NONNULL_BEGIN

/**
 * The main entry point for the SentrySDK.
 * We recommend using @c +[startWithConfigureOptions:] to initialize Sentry.
 */
@interface SentrySDK : NSObject
SENTRY_NO_INIT

/**
 * The current active transaction or span bound to the scope.
 */
@property (nullable, class, nonatomic, readonly) id<SentrySpan> span;

/**
 * Indicates whether the SentrySDK is enabled.
 */
@property (class, nonatomic, readonly) BOOL isEnabled;

@property (class, nonatomic, readonly) SentryMetricsAPI *metrics;

#if SENTRY_TARGET_REPLAY_SUPPORTED
/**
 * API to control session replay
 */
@property (class, nonatomic, readonly) SentryReplayApi *replay;
#endif

/**
 * Inits and configures Sentry (SentryHub, SentryClient) and sets up all integrations. Make sure to
 * set a valid DSN.
 *
 * @discussion Call this method on the main thread. When calling it from a background thread, the
 * SDK starts on the main thread async.
 */
+ (void)startWithOptions:(SentryOptions *)options NS_SWIFT_NAME(start(options:));

/**
 * Inits and configures Sentry (SentryHub, SentryClient) and sets up all integrations. Make sure to
 * set a valid DSN.
 *
 * @discussion Call this method on the main thread. When calling it from a background thread, the
 * SDK starts on the main thread async.
 */
+ (void)startWithConfigureOptions:(void (^)(SentryOptions *options))configureOptions
    NS_SWIFT_NAME(start(configureOptions:));

/**
 * Captures a manually created event and sends it to Sentry.
 * @param event The event to send to Sentry.
 * @return The @c SentryId of the event or @c SentryId.empty if the event is not sent.
 *
 */
+ (SentryId *)captureEvent:(SentryEvent *)event NS_SWIFT_NAME(capture(event:));

/**
 * Captures a manually created event and sends it to Sentry. Only the data in this scope object will
 * be added to the event. The global scope will be ignored.
 * @param event The event to send to Sentry.
 * @param scope The scope containing event metadata.
 * @return The @c SentryId of the event or @c SentryId.empty if the event is not sent.
 *
 */
+ (SentryId *)captureEvent:(SentryEvent *)event
                 withScope:(SentryScope *)scope NS_SWIFT_NAME(capture(event:scope:));

/**
 * Captures a manually created event and sends it to Sentry. Maintains the global scope but mutates
 * scope data for only this call.
 * @param event The event to send to Sentry.
 * @param block The block mutating the scope only for this call.
 * @return The @c SentryId of the event or @c SentryId.empty if the event is not sent.
 *
 */
+ (SentryId *)captureEvent:(SentryEvent *)event
            withScopeBlock:(void (^)(SentryScope *scope))block NS_SWIFT_NAME(capture(event:block:));

/**
 * Creates a transaction, binds it to the hub and returns the instance.
 * @param name The transaction name.
 * @param operation Short code identifying the type of operation the span is measuring.
 * @return The created transaction.
 */
+ (id<SentrySpan>)startTransactionWithName:(NSString *)name
                                 operation:(NSString *)operation
    NS_SWIFT_NAME(startTransaction(name:operation:));

/**
 * Creates a transaction, binds it to the hub and returns the instance.
 * @param name The transaction name.
 * @param operation Short code identifying the type of operation the span is measuring.
 * @param bindToScope Indicates whether the SDK should bind the new transaction to the scope.
 * @return The created transaction.
 */
+ (id<SentrySpan>)startTransactionWithName:(NSString *)name
                                 operation:(NSString *)operation
                               bindToScope:(BOOL)bindToScope
    NS_SWIFT_NAME(startTransaction(name:operation:bindToScope:));

/**
 * Creates a transaction, binds it to the hub and returns the instance.
 * @param transactionContext The transaction context.
 * @return The created transaction.
 */
+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
    NS_SWIFT_NAME(startTransaction(transactionContext:));

/**
 * Creates a transaction, binds it to the hub and returns the instance.
 * @param transactionContext The transaction context.
 * @param bindToScope Indicates whether the SDK should bind the new transaction to the scope.
 * @return The created transaction.
 */
+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
    NS_SWIFT_NAME(startTransaction(transactionContext:bindToScope:));

/**
 * Creates a transaction, binds it to the hub and returns the instance.
 * @param transactionContext The transaction context.
 * @param bindToScope Indicates whether the SDK should bind the new transaction to the scope.
 * @param customSamplingContext Additional information about the sampling context.
 * @return The created transaction.
 */
+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                                  bindToScope:(BOOL)bindToScope
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
    NS_SWIFT_NAME(startTransaction(transactionContext:bindToScope:customSamplingContext:));

/**
 * Creates a transaction, binds it to the hub and returns the instance.
 * @param transactionContext The transaction context.
 * @param customSamplingContext Additional information about the sampling context.
 * @return The created transaction.
 */
+ (id<SentrySpan>)startTransactionWithContext:(SentryTransactionContext *)transactionContext
                        customSamplingContext:(NSDictionary<NSString *, id> *)customSamplingContext
    NS_SWIFT_NAME(startTransaction(transactionContext:customSamplingContext:));

/**
 * Captures an error event and sends it to Sentry.
 * @param error The error to send to Sentry.
 * @return The @c SentryId of the event or @c SentryId.empty if the event is not sent.
 *
 */
+ (SentryId *)captureError:(NSError *)error NS_SWIFT_NAME(capture(error:));

/**
 * Captures an error event and sends it to Sentry. Only the data in this scope object will be added
 * to the event. The global scope will be ignored.
 * @param error The error to send to Sentry.
 * @param scope The scope containing event metadata.
 * @return The @c SentryId of the event or @c SentryId.empty if the event is not sent.
 *
 */
+ (SentryId *)captureError:(NSError *)error
                 withScope:(SentryScope *)scope NS_SWIFT_NAME(capture(error:scope:));

/**
 * Captures an error event and sends it to Sentry. Maintains the global scope but mutates scope data
 * for only this call.
 * @param error The error to send to Sentry.
 * @param block The block mutating the scope only for this call.
 * @return The @c SentryId of the event or @c SentryId.empty if the event is not sent.
 *
 */
+ (SentryId *)captureError:(NSError *)error
            withScopeBlock:(void (^)(SentryScope *scope))block NS_SWIFT_NAME(capture(error:block:));

/**
 * Captures an exception event and sends it to Sentry.
 * @param exception The exception to send to Sentry.
 * @return The @c SentryId of the event or @c SentryId.empty if the event is not sent.
 *
 */
+ (SentryId *)captureException:(NSException *)exception NS_SWIFT_NAME(capture(exception:));

/**
 * Captures an exception event and sends it to Sentry. Only the data in this scope object will be
 * added to the event. The global scope will be ignored.
 * @param exception The exception to send to Sentry.
 * @param scope The scope containing event metadata.
 * @return The @c SentryId of the event or @c SentryId.empty if the event is not sent.
 *
 */
+ (SentryId *)captureException:(NSException *)exception
                     withScope:(SentryScope *)scope NS_SWIFT_NAME(capture(exception:scope:));

/**
 * Captures an exception event and sends it to Sentry. Maintains the global scope but mutates scope
 * data for only this call.
 * @param exception The exception to send to Sentry.
 * @param block The block mutating the scope only for this call.
 * @return The @c SentryId of the event or @c SentryId.empty if the event is not sent.
 *
 */
+ (SentryId *)captureException:(NSException *)exception
                withScopeBlock:(void (^)(SentryScope *scope))block
    NS_SWIFT_NAME(capture(exception:block:));

/**
 * Captures a message event and sends it to Sentry.
 * @param message The message to send to Sentry.
 * @return The @c SentryId of the event or @c SentryId.empty if the event is not sent.
 *
 */
+ (SentryId *)captureMessage:(NSString *)message NS_SWIFT_NAME(capture(message:));

/**
 * Captures a message event and sends it to Sentry. Only the data in this scope object will be added
 * to the event. The global scope will be ignored.
 * @param message The message to send to Sentry.
 * @param scope The scope containing event metadata.
 * @return The @c SentryId of the event or @c SentryId.empty if the event is not sent.
 *
 */
+ (SentryId *)captureMessage:(NSString *)message
                   withScope:(SentryScope *)scope NS_SWIFT_NAME(capture(message:scope:));

/**
 * Captures a message event and sends it to Sentry. Maintains the global scope but mutates scope
 * data for only this call.
 * @param message The message to send to Sentry.
 * @param block The block mutating the scope only for this call.
 * @return The @c SentryId of the event or @c SentryId.empty if the event is not sent.
 *
 */
+ (SentryId *)captureMessage:(NSString *)message
              withScopeBlock:(void (^)(SentryScope *scope))block
    NS_SWIFT_NAME(capture(message:block:));

#if !SDK_V9
/**
 * Captures user feedback that was manually gathered and sends it to Sentry.
 * @param userFeedback The user feedback to send to Sentry.
 * @deprecated Use @c SentrySDK.captureFeedback or use or configure our new managed UX with
 * @c SentryOptions.configureUserFeedback .
 */
+ (void)captureUserFeedback:(SentryUserFeedback *)userFeedback
    NS_SWIFT_NAME(capture(userFeedback:)) DEPRECATED_MSG_ATTRIBUTE(
        "Use SentrySDK.captureFeedback or use or configure our new managed UX with "
        "SentryOptions.configureUserFeedback.");
#endif // !SDK_V9

/**
 * Captures user feedback that was manually gathered and sends it to Sentry.
 * @warning This is an experimental feature and may still have bugs.
 * @param feedback The feedback to send to Sentry.
 * @note If you'd prefer not to have to build the UI required to gather the feedback from the user,
 * see @c SentryOptions.configureUserFeedback to customize a fully managed integration. See
 * https://docs.sentry.io/platforms/apple/user-feedback/ for more information.
 */
+ (void)captureFeedback:(SentryFeedback *)feedback NS_SWIFT_NAME(capture(feedback:));

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

@property (nonatomic, class, readonly) SentryFeedbackAPI *feedback API_AVAILABLE(ios(13.0));

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT

/**
 * Adds a Breadcrumb to the current Scope of the current Hub. If the total number of breadcrumbs
 * exceeds the @c SentryOptions.maxBreadcrumbs  the SDK removes the oldest breadcrumb.
 * @param crumb The Breadcrumb to add to the current Scope of the current Hub.
 */
+ (void)addBreadcrumb:(SentryBreadcrumb *)crumb NS_SWIFT_NAME(addBreadcrumb(_:));

/**
 * Use this method to modify the current Scope of the current Hub. The SDK uses the Scope to attach
 * contextual data to events.
 * @param callback The callback for configuring the current Scope of the current Hub.
 */
+ (void)configureScope:(void (^)(SentryScope *scope))callback;

/**
 * Checks if the last program execution terminated with a crash.
 */
@property (nonatomic, class, readonly) BOOL crashedLastRun;

/**
 * Checks if the SDK detected a start-up crash during SDK initialization.
 *
 * @note The SDK init waits synchronously for up to 5 seconds to flush out events if the app crashes
 * within 2 seconds after the SDK init.
 *
 * @return @c YES if the SDK detected a start-up crash and @c NO if not.
 */
@property (nonatomic, class, readonly) BOOL detectedStartUpCrash;

/**
 * Set user to the current Scope of the current Hub.
 * @param user The user to set to the current Scope.
 *
 * @note You must start the SDK before calling this method, otherwise it doesn't set the user.
 */
+ (void)setUser:(nullable SentryUser *)user;

/**
 * Starts a new SentrySession. If there's a running @c SentrySession, it ends it before starting the
 * new one. You can use this method in combination with endSession to manually track
 * @c SentrySessions. The SDK uses SentrySession to inform Sentry about release and project
 * associated project health.
 */
+ (void)startSession;

/**
 * Ends the current @c SentrySession. You can use this method in combination with @c startSession to
 * manually track @c SentrySessions. The SDK uses SentrySession to inform Sentry about release and
 * project associated project health.
 */
+ (void)endSession;

/**
 * This forces a crash, useful to test the @c SentryCrash integration.
 *
 * @note The SDK can't report a crash when a debugger is attached. Your application needs to run
 * without a debugger attached to capture the crash and send it to Sentry the next time you launch
 * your application.
 */
+ (void)crash;

/**
 * Reports to the ongoing UIViewController transaction
 * that the screen contents are fully loaded and displayed,
 * which will create a new span.
 *
 * For more information see our documentation:
 * https://docs.sentry.io/platforms/cocoa/performance/instrumentation/automatic-instrumentation/#time-to-full-display
 */
+ (void)reportFullyDisplayed;

/**
 * Pauses sending detected app hangs to Sentry.
 *
 * @discussion This method doesn't close the detection of app hangs. Instead, the app hang detection
 * will ignore detected app hangs until you call @c resumeAppHangTracking.
 */
+ (void)pauseAppHangTracking;

/**
 * Resumes sending detected app hangs to Sentry.
 */
+ (void)resumeAppHangTracking;

/**
 * Waits synchronously for the SDK to flush out all queued and cached items for up to the specified
 * timeout in seconds. If there is no internet connection, the function returns immediately. The SDK
 * doesn't dispose the client or the hub.
 * @param timeout The time to wait for the SDK to complete the flush.
 */
+ (void)flush:(NSTimeInterval)timeout NS_SWIFT_NAME(flush(timeout:));

/**
 * Closes the SDK, uninstalls all the integrations, and calls flush with
 * @c SentryOptions.shutdownTimeInterval .
 */
+ (void)close;

#if SENTRY_TARGET_PROFILING_SUPPORTED
/**
 * Start a new continuous profiling session if one is not already running.
 * @warning Continuous profiling mode is experimental and may still contain bugs.
 * @note Unlike transaction-based profiling, continuous profiling does not take into account
 * @c SentryOptions.profilesSampleRate or @c SentryOptions.profilesSampler . If either of those
 * options are set, this method does nothing.
 * @note Taking into account the above note, if @c SentryOptions.configureProfiling is not set,
 * calls to this method will always start a profile if one is not already running. This includes app
 * launch profiles configured with @c SentryOptions.enableAppLaunchProfiling .
 * @note If neither @c SentryOptions.profilesSampleRate nor @c SentryOptions.profilesSampler are
 * set, and @c SentryOptions.configureProfiling is set, this method does nothing if the profiling
 * session is not sampled with respect to @c SentryOptions.profileSessionSampleRate , or if it is
 * sampled but the profiler is already running.
 * @note If neither @c SentryOptions.profilesSampleRate nor @c SentryOptions.profilesSampler are
 * set, and @c SentryOptions.configureProfiling is set, this method does nothing if
 * @c SentryOptions.profileLifecycle is set to @c trace . In this scenario, the profiler is
 * automatically started and stopped depending on whether there is an active sampled span, so it is
 * not permitted to manually start profiling.
 * @note Profiling is automatically disabled if a thread sanitizer is attached.
 * @seealso https://docs.sentry.io/platforms/apple/guides/ios/profiling/#continuous-profiling
 */
+ (void)startProfiler;

/**
 * Stop a continuous profiling session if there is one ongoing.
 * @warning Continuous profiling mode is experimental and may still contain bugs.
 * @note Does nothing if @c SentryOptions.profileLifecycle is set to @c trace .
 * @note Does not immediately stop the profiler. Profiling data is uploaded at regular timed
 * intervals; when the current interval completes, then the profiler stops and the data gathered
 * during that last interval is uploaded.
 * @note If a new call to @c startProfiler that would start the profiler is made before the last
 * interval completes, the profiler will continue running until another call to stop is made.
 * @note Profiling is automatically disabled if a thread sanitizer is attached.
 * @seealso https://docs.sentry.io/platforms/apple/guides/ios/profiling/#continuous-profiling
 */
+ (void)stopProfiler;
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

@end

NS_ASSUME_NONNULL_END
