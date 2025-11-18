// swiftlint:disable file_length
@_implementationOnly import _SentryPrivate
import Foundation

/// The main entry point for the Sentry SDK.
/// We recommend using `start(configureOptions:)` to initialize Sentry.
@objc open class SentrySDK: NSObject {
    
    // MARK: - Public
    
    /// The current active transaction or span bound to the scope.
    @objc public static var span: Span? {
        return SentrySDKInternal.span
    }
    
    /// Indicates whether the Sentry SDK is enabled.
    @objc public static var isEnabled: Bool {
        return SentrySDKInternal.isEnabled
    }

    #if canImport(UIKit) && !SENTRY_NO_UIKIT && (os(iOS) || os(tvOS))
    /// API to control session replay
    @objc public static var replay: SentryReplayApi {
        return SentrySDKInternal.replay
    }
    #endif

    /// API to access Sentry logs
    @objc public static var logger: SentryLogger {
        return _loggerLock.synchronized {
            let sdkEnabled = SentrySDKInternal.isEnabled
            if !sdkEnabled {
                SentrySDKLog.fatal("Logs called before SentrySDK.start() will be dropped.")
            }
            if let _logger, _loggerConfigured {
                return _logger
            }
            let hub = SentryDependencyContainerSwiftHelper.currentHub()
            var batcher: SentryLogBatcher?
            if let client = hub.getClient(), client.options.experimental.enableLogs {
                batcher = SentryLogBatcher(client: client, dispatchQueue: Dependencies.dispatchQueueWrapper)
            }
            let logger = SentryLogger(
                hub: hub,
                dateProvider: Dependencies.dateProvider,
                batcher: batcher
            )
            _logger = logger
            _loggerConfigured = sdkEnabled
            return logger
        }
    }
    
    /// Inits and configures Sentry (`SentryHub`, `SentryClient`) and sets up all integrations. Make sure to
    /// set a valid DSN.
    /// - note: Call this method on the main thread. When calling it from a background thread, the
    /// SDK starts on the main thread async.
    @objc public static func start(options: Options) {
        SentrySDKInternal.start(options: options)
    }
    
    /// Inits and configures Sentry (`SentryHub`, `SentryClient`) and sets up all integrations. Make sure to
    /// set a valid DSN.
    /// - note: Call this method on the main thread. When calling it from a background thread, the
    /// SDK starts on the main thread async.
    @objc public static func start(configureOptions: @escaping (Options) -> Void) {
        SentrySDKInternal.start(configureOptions: configureOptions)
    }
    
    // MARK: - Event Capture
    
    /// Captures a manually created event and sends it to Sentry.
    /// - parameter event: The event to send to Sentry.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureEvent:)
    @discardableResult public static func capture(event: Event) -> SentryId {
        return SentrySDKInternal.capture(event: event).sentryId
    }
    
    /// Captures a manually created event and sends it to Sentry. Only the data in this scope object will
    /// be added to the event. The global scope will be ignored.
    /// - parameter event: The event to send to Sentry.
    /// - parameter scope: The scope containing event metadata.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureEvent:withScope:)
    @discardableResult public static func capture(event: Event, scope: Scope) -> SentryId {
        return SentrySDKInternal.capture(event: event, scope: scope).sentryId
    }
    
    /// Captures a manually created event and sends it to Sentry. Maintains the global scope but mutates
    /// scope data for only this call.
    /// - parameter event: The event to send to Sentry.
    /// - parameter block: The block mutating the scope only for this call.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureEvent:withScopeBlock:)
    @discardableResult public static func capture(event: Event, block: @escaping (Scope) -> Void) -> SentryId {
        return SentrySDKInternal.capture(event: event, block: block).sentryId
    }
    
    // MARK: - Transaction Management
    
    /// Creates a transaction, binds it to the hub and returns the instance.
    /// - parameter name: The transaction name.
    /// - parameter operation: Short code identifying the type of operation the span is measuring.
    /// - returns: The created transaction.
    @objc @discardableResult public static func startTransaction(name: String, operation: String) -> Span {
        return SentrySDKInternal.startTransaction(name: name, operation: operation)
    }
    
    /// Creates a transaction, binds it to the hub and returns the instance.
    /// - parameter name: The transaction name.
    /// - parameter operation: Short code identifying the type of operation the span is measuring.
    /// - parameter bindToScope: Indicates whether the SDK should bind the new transaction to the scope.
    /// - returns: The created transaction.
    @objc @discardableResult public static func startTransaction(name: String, operation: String, bindToScope: Bool) -> Span {
        return SentrySDKInternal.startTransaction(name: name, operation: operation, bindToScope: bindToScope)
    }
    
    /// Creates a transaction, binds it to the hub and returns the instance.
    /// - parameter transactionContext: The transaction context.
    /// - returns: The created transaction.
    @objc(startTransactionWithContext:)
    @discardableResult public static func startTransaction(transactionContext: TransactionContext) -> Span {
        return SentrySDKInternal.startTransaction(transactionContext: transactionContext)
    }
    
    /// Creates a transaction, binds it to the hub and returns the instance.
    /// - parameter transactionContext: The transaction context.
    /// - parameter bindToScope: Indicates whether the SDK should bind the new transaction to the scope.
    /// - returns: The created transaction.
    @objc(startTransactionWithContext:bindToScope:)
    @discardableResult public static func startTransaction(transactionContext: TransactionContext, bindToScope: Bool) -> Span {
        return SentrySDKInternal.startTransaction(transactionContext: transactionContext, bindToScope: bindToScope)
    }
    
    /// Creates a transaction, binds it to the hub and returns the instance.
    /// - parameter transactionContext: The transaction context.
    /// - parameter bindToScope: Indicates whether the SDK should bind the new transaction to the scope.
    /// - parameter customSamplingContext: Additional information about the sampling context.
    /// - returns: The created transaction.
    @objc(startTransactionWithContext:bindToScope:customSamplingContext:)
    @discardableResult public static func startTransaction(transactionContext: TransactionContext, bindToScope: Bool, customSamplingContext: [String: Any]) -> Span {
        return SentrySDKInternal.startTransaction(transactionContext: transactionContext, bindToScope: bindToScope, customSamplingContext: customSamplingContext)
    }
    
    /// Creates a transaction, binds it to the hub and returns the instance.
    /// - parameter transactionContext: The transaction context.
    /// - parameter customSamplingContext: Additional information about the sampling context.
    /// - returns: The created transaction.
    @objc(startTransactionWithContext:customSamplingContext:)
    @discardableResult public static func startTransaction(transactionContext: TransactionContext, customSamplingContext: [String: Any]) -> Span {
        return SentrySDKInternal.startTransaction(transactionContext: transactionContext, customSamplingContext: customSamplingContext)
    }
    
    // MARK: - Error Capture
    
    /// Captures an error event and sends it to Sentry.
    /// - parameter error: The error to send to Sentry.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureError:)
    @discardableResult public static func capture(error: Error) -> SentryId {
        return SentrySDKInternal.capture(error: error).sentryId
    }
    
    /// Captures an error event and sends it to Sentry. Only the data in this scope object will be added
    /// to the event. The global scope will be ignored.
    /// - parameter error: The error to send to Sentry.
    /// - parameter scope: The scope containing event metadata.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureError:withScope:)
    @discardableResult public static func capture(error: Error, scope: Scope) -> SentryId {
        return SentrySDKInternal.capture(error: error, scope: scope).sentryId
    }
    
    /// Captures an error event and sends it to Sentry. Maintains the global scope but mutates scope data
    /// for only this call.
    /// - parameter error: The error to send to Sentry.
    /// - parameter block: The block mutating the scope only for this call.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureError:withScopeBlock:)
    @discardableResult public static func capture(error: Error, block: @escaping (Scope) -> Void) -> SentryId {
        return SentrySDKInternal.capture(error: error, block: block).sentryId
    }
    
    // MARK: - Exception Capture
    
    /// Captures an exception event and sends it to Sentry.
    /// - parameter exception: The exception to send to Sentry.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureException:)
    @discardableResult public static func capture(exception: NSException) -> SentryId {
        return SentrySDKInternal.capture(exception: exception).sentryId
    }
    
    /// Captures an exception event and sends it to Sentry. Only the data in this scope object will be
    /// added to the event. The global scope will be ignored.
    /// - parameter exception: The exception to send to Sentry.
    /// - parameter scope: The scope containing event metadata.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureException:withScope:)
    @discardableResult public static func capture(exception: NSException, scope: Scope) -> SentryId {
        return SentrySDKInternal.capture(exception: exception, scope: scope).sentryId
    }
    
    /// Captures an exception event and sends it to Sentry. Maintains the global scope but mutates scope
    /// data for only this call.
    /// - parameter exception: The exception to send to Sentry.
    /// - parameter block: The block mutating the scope only for this call.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureException:withScopeBlock:)
    @discardableResult public static func capture(exception: NSException, block: @escaping (Scope) -> Void) -> SentryId {
        return SentrySDKInternal.capture(exception: exception, block: block).sentryId
    }
    
    // MARK: - Message Capture
    
    /// Captures a message event and sends it to Sentry.
    /// - parameter message: The message to send to Sentry.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureMessage:)
    @discardableResult public static func capture(message: String) -> SentryId {
        return SentrySDKInternal.capture(message: message).sentryId
    }
    
    /// Captures a message event and sends it to Sentry. Only the data in this scope object will be added
    /// to the event. The global scope will be ignored.
    /// - parameter message: The message to send to Sentry.
    /// - parameter scope: The scope containing event metadata.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureMessage:withScope:)
    @discardableResult public static func capture(message: String, scope: Scope) -> SentryId {
        return SentrySDKInternal.capture(message: message, scope: scope).sentryId
    }
    
    /// Captures a message event and sends it to Sentry. Maintains the global scope but mutates scope
    /// data for only this call.
    /// - parameter message: The message to send to Sentry.
    /// - parameter block: The block mutating the scope only for this call.
    /// - returns: The `SentryId` of the event or `SentryId.empty` if the event is not sent.
    @objc(captureMessage:withScopeBlock:)
    @discardableResult public static func capture(message: String, block: @escaping (Scope) -> Void) -> SentryId {
        return SentrySDKInternal.capture(message: message, block: block).sentryId
    }
    
    #if !SDK_V9
    /// Captures user feedback that was manually gathered and sends it to Sentry.
    /// - parameter userFeedback: The user feedback to send to Sentry.
    @available(*, deprecated, message: "Use SentrySDK.back or use or configure our new managed UX with SentryOptions.configureUserFeedback.")
    @objc(captureUserFeedback:)
    public static func capture(userFeedback: UserFeedback) {
        SentrySDKInternal.capture(userFeedback: userFeedback)
    }
    #endif
    
    /// Captures user feedback that was manually gathered and sends it to Sentry.
    /// - warning: This is an experimental feature and may still have bugs.
    /// - parameter feedback: The feedback to send to Sentry.
    /// - note: If you'd prefer not to have to build the UI required to gather the feedback from the user,
    /// see `SentryOptions.configureUserFeedback` to customize a fully managed integration. See
    /// https://docs.sentry.io/platforms/apple/user-feedback/ for more information.
    @objc(captureFeedback:)
    public static func capture(feedback: SentryFeedback) {
      SentrySDKInternal.captureSerializedFeedback(
        feedback.serialize(),
        withEventId: feedback.eventId.sentryIdString,
        attachments: feedback.attachmentsForEnvelope())
    }
    
    #if os(iOS) && !SENTRY_NO_UIKIT
    @available(iOS 13.0, *)
    @objc public static let feedback = {
      return SentryFeedbackAPI()
    }()
    #endif
    
    /// Adds a `Breadcrumb` to the current `Scope` of the current `Hub`. If the total number of breadcrumbs
    /// exceeds the `SentryOptions.maxBreadcrumbs` the SDK removes the oldest breadcrumb.
    /// - parameter crumb: The `Breadcrumb` to add to the current `Scope` of the current `Hub`.
    @objc(addBreadcrumb:)
    public static func addBreadcrumb(_ crumb: Breadcrumb) {
        SentrySDKInternal.addBreadcrumb(crumb)
    }
    
    /// Use this method to modify the current `Scope` of the current `Hub`. The SDK uses the `Scope` to attach
    /// contextual data to events.
    /// - parameter callback: The callback for configuring the current `Scope` of the current `Hub`.
    @objc(configureScope:)
    public static func configureScope(_ callback: @escaping (Scope) -> Void) {
        SentrySDKInternal.configureScope(callback)
    }
    
    // MARK: - Crash Detection
    
    /// Checks if the last program execution terminated with a crash.
    @objc public static var crashedLastRun: Bool {
        return SentrySDKInternal.crashedLastRun
    }
    
    /// Checks if the SDK detected a start-up crash during SDK initialization.
    /// - note: The SDK init waits synchronously for up to 5 seconds to flush out events if the app crashes
    /// within 2 seconds after the SDK init.
    /// - returns: true if the SDK detected a start-up crash and false if not.
    @objc public static var detectedStartUpCrash: Bool {
        return SentrySDKInternal.detectedStartUpCrash
    }
    
    // MARK: - User Management
    
    /// Set `user` to the current `Scope` of the current `Hub`.
    /// - parameter user: The user to set to the current `Scope`.
    /// - note: You must start the SDK before calling this method, otherwise it doesn't set the user.
    @objc public static func setUser(_ user: User?) {
        SentrySDKInternal.setUser(user)
    }
    
    // MARK: - Session Management
    
    /// Starts a new `SentrySession`. If there's a running `SentrySession`, it ends it before starting the
    /// new one. You can use this method in combination with `endSession` to manually track
    /// sessions. The SDK uses `SentrySession` to inform Sentry about release and project
    /// associated project health.
    @objc public static func startSession() {
        SentrySDKInternal.startSession()
    }
    
    /// Ends the current `SentrySession`. You can use this method in combination with `startSession` to
    /// manually track `SentrySessions`. The SDK uses `SentrySession` to inform Sentry about release and
    /// project associated project health.
    @objc public static func endSession() {
        SentrySDKInternal.endSession()
    }
    
    /// This forces a crash, useful to test the `SentryCrash` integration.
    ///
    /// - note: The SDK can't report a crash when a debugger is attached. Your application needs to run
    /// without a debugger attached to capture the crash and send it to Sentry the next time you launch
    /// your application.
    @objc public static func crash() {
        SentrySDKInternal.crash()
    }
    
    /// Reports to the ongoing `UIViewController` transaction
    /// that the screen contents are fully loaded and displayed,
    /// which will create a new span.
    ///
    /// - seealso:
    /// https://docs.sentry.io/platforms/cocoa/performance/instrumentation/automatic-instrumentation/#time-to-full-display
    @objc public static func reportFullyDisplayed() {
        SentrySDKInternal.reportFullyDisplayed()
    }
    
    // MARK: - App Hang Tracking
    
    /// Pauses sending detected app hangs to Sentry.
    ///
    /// This method doesn't close the detection of app hangs. Instead, the app hang detection
    /// will ignore detected app hangs until you call `resumeAppHangTracking`.
    @objc public static func pauseAppHangTracking() {
        SentrySDKInternal.pauseAppHangTracking()
    }
    
    /// Resumes sending detected app hangs to Sentry.
    @objc public static func resumeAppHangTracking() {
        SentrySDKInternal.resumeAppHangTracking()
    }
    
    /// Waits synchronously for the SDK to flush out all queued and cached items for up to the specified
    /// timeout in seconds. If there is no internet connection, the function returns immediately. The SDK
    /// doesn't dispose the client or the hub.
    /// - parameter timeout: The time to wait for the SDK to complete the flush.
    /// - note: This might take slightly longer than the specified timeout if there are many batched logs to capture.
    @objc(flush:)
    public static func flush(timeout: TimeInterval) {
        let captureLogsDuration = captureLogs()
        // Capturing batched logs should never take long, but we need to fall back to a sane value.
        // This is a workaround for experimental logs, until we'll write batched logs to disk, 
        // to avoid data loss due to crashes. This is a trade-off until then.
        SentrySDKInternal.flush(timeout: max(timeout / 2, timeout - captureLogsDuration))
    }
    
    /// Closes the SDK, uninstalls all the integrations, and calls `flush` with
    /// `SentryOptions.shutdownTimeInterval`.
    @objc public static func close() {
        // Capturing batched logs should never take long, ignore the duration here.
        _ = captureLogs()
        SentrySDKInternal.close()
    }
    
#if !(os(watchOS) || os(tvOS) || (swift(>=5.9) && os(visionOS)))
    /// Start a new continuous profiling session if one is not already running.
    /// - warning: Continuous profiling mode is experimental and may still contain bugs.
    /// - note: Unlike transaction-based profiling, continuous profiling does not take into account
    /// `SentryOptions.profilesSampleRate` or `SentryOptions.profilesSampler`. If either of those
    /// options are set, this method does nothing.
    /// - note: Taking into account the above note, if `SentryOptions.configureProfiling` is not set,
    /// calls to this method will always start a profile if one is not already running. This includes app
    /// launch profiles configured with `SentryOptions.enableAppLaunchProfiling`.
    /// - note: If neither `SentryOptions.profilesSampleRate` nor `SentryOptions.profilesSampler` are
    /// set, and `SentryOptions.configureProfiling` is set, this method does nothing if the profiling
    /// session is not sampled with respect to `SentryOptions.profileSessionSampleRate`, or if it is
    /// sampled but the profiler is already running.
    /// - note: If neither `SentryOptions.profilesSampleRate` nor `SentryOptions.profilesSampler` are
    /// set, and `SentryOptions.configureProfiling` is set, this method does nothing if
    /// `SentryOptions.profileLifecycle` is set to `trace`. In this scenario, the profiler is
    /// automatically started and stopped depending on whether there is an active sampled span, so it is
    /// not permitted to manually start profiling.
    /// - note: Profiling is automatically disabled if a thread sanitizer is attached.
    /// - seealso: https://docs.sentry.io/platforms/apple/guides/ios/profiling/#continuous-profiling
    @objc public static func startProfiler() {
        SentrySDKInternal.startProfiler()
    }
    
    /// Stop a continuous profiling session if there is one ongoing.
    /// - warning: Continuous profiling mode is experimental and may still contain bugs.
    /// - note: Does nothing if `SentryOptions.profileLifecycle` is set to `trace`.
    /// - note: Does not immediately stop the profiler. Profiling data is uploaded at regular timed
    /// intervals; when the current interval completes, then the profiler stops and the data gathered
    /// during that last interval is uploaded.
    /// - note: If a new call to `startProfiler` that would start the profiler is made before the last
    /// interval completes, the profiler will continue running until another call to stop is made.
    /// - note: Profiling is automatically disabled if a thread sanitizer is attached.
    /// - seealso: https://docs.sentry.io/platforms/apple/guides/ios/profiling/#continuous-profiling
    @objc public static func stopProfiler() {
        SentrySDKInternal.stopProfiler()
    }
    #endif

    // MARK: Internal

    /// - note: Conceptually internal but needs to be marked public with SPI for ObjC visibility
    @objc @_spi(Private) public static func clearLogger() {
        _loggerLock.synchronized {
            _logger = nil
            _loggerConfigured = false
        }
    }

    // MARK: Private
    
    private static var _loggerLock = NSLock()
    private static var _logger: SentryLogger?
    // Flag to re-create instance if accessed before SDK init.
    private static var _loggerConfigured = false

    @discardableResult
    private static func captureLogs() -> TimeInterval {
        var duration: TimeInterval = 0.0
        _loggerLock.synchronized {
            duration = _logger?.captureLogs() ?? 0.0
        }
        return duration
    }
}

extension SentryIdWrapper {
    var sentryId: SentryId {
        SentryId(uuidString: sentryIdString)
    }
}

// swiftlint:enable file_length
