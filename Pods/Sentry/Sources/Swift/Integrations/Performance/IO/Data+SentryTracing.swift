@_implementationOnly import _SentryPrivate

/// A ``Data`` extension that tracks read and write operations with Sentry.
///
/// - Note: Methods provided by this extension reflect the same functionality as the original ``Data`` methods, but they track the operation with Sentry.
public extension Data {

    // MARK: - Reading Data from a File

    /// Creates a data object from the data at the specified file URL, tracking the operation with Sentry.
    ///
    /// This method is a wrapper around ``Data.init(contentsOf:options:)`` and can also be used when the Sentry SDK is not enabled.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.experimental.enableDataSwizzling` to `false` when initializing Sentry.
    /// - Parameters:
    ///   - url: The location on disk of the data to read.
    ///   - options: The mask specifying the options to use when reading the data. For more information, see ``NSData.ReadingOptions``.
    /// - Note: See ``Data.init(contentsOf:options:)`` for more information.
    init(contentsOfWithSentryTracing url: URL, options: Data.ReadingOptions = []) throws {
        // Gets a tracker instance if the SDK is enabled, otherwise uses the original method.
        let method = { (url: URL, options: Data.ReadingOptions) throws -> Data in
            try Data(contentsOf: url, options: options)
        }
        guard let tracker = SentryFileIOTracker.sharedInstance() else {
            self = try method(url, options)
            return
        }
        self = try tracker
            .measureReadingData(
                from: url,
                options: options,
                origin: SentryTraceOriginManualFileData,
                method: method
            )
    }

    // MARK: - Writing Data to a File

    /// Write the contents of the `Data` to a location, tracking the operation with Sentry.
    ///
    /// This method is a wrapper around ``Data.write(to:options:)`` and can also be used when the Sentry SDK is not enabled.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.experimental.enableDataSwizzling` to `false` when initializing Sentry.
    /// - Parameters:
    ///   - url: The location to write the data into.
    ///   - options: Options for writing the data. Default value is `[]`.
    /// - Note: See ``Data.write(to:options:)`` for more information.
    func writeWithSentryTracing(to url: URL, options: Data.WritingOptions = []) throws {
        // Gets a tracker instance if the SDK is enabled, otherwise uses the original method.
        let method = { (data: Data, url: URL, options: Data.WritingOptions) throws in
            try data.write(to: url, options: options)
        }
        guard let tracker = SentryFileIOTracker.sharedInstance() else {
            return try method(self, url, options)
        }
        try tracker
            .measureWritingData(
                self,
                to: url,
                options: options,
                origin: SentryTraceOriginManualFileData,
                method: method
            )
    }
}
