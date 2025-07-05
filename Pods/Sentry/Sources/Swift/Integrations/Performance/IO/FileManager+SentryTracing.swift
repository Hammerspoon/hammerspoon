@_implementationOnly import _SentryPrivate
import Foundation

/// A ``FileManager`` extension that tracks read and write operations with Sentry.
///
/// - Note: Methods provided by this extension reflect the same functionality as the original ``FileManager`` methods, but they track the operation with Sentry.
public extension FileManager {

    // MARK: - Creating and Deleting Items

    /// Creates a file with the specified content and attributes at the given location, tracking the operation with Sentry.
    ///
    /// This method is a wrapper around ``FileManager.createFile(atPath:contents:attributes:)`` and can also be used when the SentrySDK is not enabled.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.experimental.enableFileManagerSwizzling` to `false` when initializing Sentry.
    /// - Parameters:
    ///   - path: The path for the new file.
    ///   - data: A data object containing the contents of the new file.
    ///   - attr: A dictionary containing the attributes to associate with the new file.
    ///           You can use these attributes to set the owner and group numbers, file permissions, and modification date.
    ///           For a list of keys, see ``FileAttributeKey``. If you specify `nil` for attributes, the file is created with a set of default attributes.
    /// - Returns: `true` if the operation was successful or if the item already exists, otherwise `false`.
    /// - Note: See ``FileManager.createFile(atPath:contents:attributes:)`` for more information.
    func createFileWithSentryTracing(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey: Any]? = nil) -> Bool {
        // Using a closure ensures that the same method is used with and without Sentry tracking.
        let method = { (path: String, data: Data?, attr: [FileAttributeKey: Any]?) -> Bool in
            self.createFile(atPath: path, contents: data, attributes: attr)
        }
        // Gets a tracker instance if the SDK is enabled, otherwise uses the original method.
        guard let tracker = SentryFileIOTracker.sharedInstance() else {
            return method(path, data, attr)
        }
        return tracker
            .measureCreatingFile(
                atPath: path,
                contents: data,
                attributes: attr,
                origin: SentryTraceOriginManualFileData,
                method: method
            )
    }

    /// Removes the file or directory at the specified URL, tracking the operation with Sentry.
    ///
    /// This method is a wrapper around ``FileManager.removeItem(at:)`` and can also be used when the Sentry SDK is not enabled.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.experimental.enableFileManagerSwizzling` to `false` when initializing Sentry.
    /// - Parameter url: A file URL specifying the file or directory to remove.
    ///                  If the URL specifies a directory, the contents of that directory are recursively removed.
    /// - Note: See ``FileManager.removeItem(at:)`` for more information.
    func removeItemWithSentryTracing(at url: URL) throws {
        // It is necessary to check if the SDK is enabled because accessing the tracker will otherwise initialize the
        // depency container without any configured SDK options. This is a known issue and needs to be fixed in general.
        //
        // Using a closure ensures that the same method is used with and without Sentry tracking.
        let method = { (url: URL) in
            try self.removeItem(at: url)
        }
        // Gets a tracker instance if the SDK is enabled, otherwise uses the original method.
        guard let tracker = SentryFileIOTracker.sharedInstance() else {
            return try method(url)
        }
        try tracker.measureRemovingItem(at: url, origin: SentryTraceOriginManualFileData, method: method)
    }

    /// Removes the file or directory at the specified path, tracking the operation with Sentry.
    ///
    /// This method is a wrapper around ``FileManager.removeItem(atPath:)`` and can also be used when the Sentry SDK is not enabled.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.experimental.enableFileManagerSwizzling` to `false` when initializing Sentry.
    /// - Parameter path: A path string indicating the file or directory to remove.
    ///                   If the path specifies a directory, the contents of that directory are recursively removed.
    /// - Note: See ``FileManager.removeItem(atPath:)`` for more information.
    func removeItemWithSentryTracing(atPath path: String) throws {
        // It is necessary to check if the SDK is enabled because accessing the tracker will otherwise initialize the
        // depency container without any configured SDK options. This is a known issue and needs to be fixed in general.
        //
        // Using a closure to ensure that the same method is used with and without Sentry tracking.
        let method = { (path: String) in
            try self.removeItem(atPath: path)
        }
        // Gets a tracker instance if the SDK is enabled, otherwise uses the original method.
        guard let tracker = SentryFileIOTracker.sharedInstance() else {
            return try method(path)
        }
        try tracker.measureRemovingItem(atPath: path, origin: SentryTraceOriginManualFileData, method: method)
    }

    // MARK: - Moving and Copying Items

    /// Copies the file at the specified URL to a new location synchronously, tracking the operation with Sentry.
    ///
    /// This method is a wrapper around ``FileManager.copyItem(at:to:)`` and can also be used when the Sentry SDK is not enabled.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.experimental.enableFileManagerSwizzling` to `false` when initializing Sentry.
    /// - Parameters:
    ///   - srcURL: The file URL that identifies the file you want to copy.
    ///             The URL in this parameter must not be a file reference URL.
    ///   - dstURL: The URL at which to place the copy of `srcURL`.
    ///             The URL in this parameter must not be a file reference URL and must include the name of the file in its new location.
    /// - Note: See ``FileManager.copyItem(at:to:)`` for more information.
    func copyItemWithSentryTracing(at srcURL: URL, to dstURL: URL) throws {
        // It is necessary to check if the SDK is enabled because accessing the tracker will otherwise initialize the
        // depency container without any configured SDK options. This is a known issue and needs to be fixed in general.
        //
        // Using a closure ensures that the same method is used with and without Sentry tracking.
        let method = { (srcURL: URL, dstURL: URL) throws in
            try self.copyItem(at: srcURL, to: dstURL)
        }
        // Gets a tracker instance if the SDK is enabled, otherwise uses the original method.
        guard let tracker = SentryFileIOTracker.sharedInstance() else {
            return try method(srcURL, dstURL)
        }
        try tracker.measureCopyingItem(at: srcURL, to: dstURL, origin: SentryTraceOriginManualFileData, method: method)
    }

    /// Copies the item at the specified path to a new location synchronously, tracking the operation with Sentry.
    ///
    /// This method is a wrapper around ``FileManager.copyItem(atPath:toPath:)`` and can also be used when the SentrySDK is not enabled.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.experimental.enableFileManagerSwizzling` to `false` when initializing Sentry.
    /// - Parameters:
    ///   - srcPath: The path to the file or directory you want to move.
    ///   - dstPath: The path at which to place the copy of `srcPath`.
    ///              This path must include the name of the file or directory in its new location.
    /// - Note: See ``FileManager.copyItem(atPath:toPath:)`` for more information.
    func copyItemWithSentryTracing(atPath srcPath: String, toPath dstPath: String) throws {
        // It is necessary to check if the SDK is enabled because accessing the tracker will otherwise initialize the
        // depency container without any configured SDK options. This is a known issue and needs to be fixed in general.
        //
        // Using a closure to ensure that the same method is used with and without Sentry tracking.
        let method = { (srcPath: String, dstPath: String) throws in
            try self.copyItem(atPath: srcPath, toPath: dstPath)
        }
        // Gets a tracker instance if the SDK is enabled, otherwise uses the original method.
        guard let tracker = SentryFileIOTracker.sharedInstance() else {
            return try method(srcPath, dstPath)
        }
        try tracker.measureCopyingItem(atPath: srcPath, toPath: dstPath, origin: SentryTraceOriginManualFileData, method: method)
    }

    /// Moves the file or directory at the specified URL to a new location synchronously, tracking the operation with Sentry.
    ///
    /// This method is a wrapper around ``FileManager.moveItem(at:to:)`` and can also be used when the Sentry SDK is not enabled.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.experimental.enableFileManagerSwizzling` to `false` when initializing Sentry.
    /// - Parameters:
    ///   - srcURL: The file URL that identifies the file or directory you want to move.
    ///             The URL in this parameter must not be a file reference URL.
    ///   - dstURL: The new location for the item in `srcURL`.
    ///             The URL in this parameter must not be a file reference URL and must include the name of the file or directory in its new location.
    /// - Note: See ``FileManager.moveItem(at:to:)`` for more information.
    func moveItemWithSentryTracing(at srcURL: URL, to dstURL: URL) throws {
        // It is necessary to check if the SDK is enabled because accessing the tracker will otherwise initialize the
        // depency container without any configured SDK options. This is a known issue and needs to be fixed in general.
        //
        // Using a closure ensures that the same method is used with and without Sentry tracking.
        let method = { (srcURL: URL, dstURL: URL) throws in
            try self.moveItem(at: srcURL, to: dstURL)
        }
        // Gets a tracker instance if the SDK is enabled, otherwise uses the original method.
        guard let tracker = SentryFileIOTracker.sharedInstance() else {
            return try method(srcURL, dstURL)
        }
        try tracker.measureMovingItem(
            at: srcURL,
            to: dstURL,
            origin: SentryTraceOriginManualFileData,
            method: method
        )
    }

    /// Moves the file or directory at the specified path to a new location synchronously, tracking the operation with Sentry.
    ///
    /// This method is a wrapper around ``FileManager.moveItem(atPath:toPath:)`` and can also be used when the Sentry SDK is not enabled.
    ///
    /// - Important: Using this method with auto-instrumentation for file operations enabled can lead to duplicate spans on older operating system versions.
    ///              It is recommended to use either automatic or manual instrumentation. You can disable automatic instrumentation by setting
    ///              `options.experimental.enableFileManagerSwizzling` to `false` when initializing Sentry.
    /// - Parameters:
    ///   - srcPath: The path to the file or directory you want to move.
    ///   - dstPath: The new path for the item in `srcPath`.
    ///              This path must include the name of the file or directory in its new location.
    /// - Note: See ``FileManager.moveItem(atPath:toPath:)`` for more information.
    func moveItemWithSentryTracing(atPath srcPath: String, toPath dstPath: String) throws {
        // It is necessary to check if the SDK is enabled because accessing the tracker will otherwise initialize the
        // depency container without any configured SDK options. This is a known issue and needs to be fixed in general.
        //
        // Using a closure ensures that the same method is used with and without Sentry tracking.
        let method = { (srcPath: String, dstPath: String) throws in
            try self.moveItem(atPath: srcPath, toPath: dstPath)
        }
        // Gets a tracker instance if the SDK is enabled, otherwise uses the original method.
        guard let tracker = SentryFileIOTracker.sharedInstance() else {
            return try method(srcPath, dstPath)
        }
        try tracker.measureMovingItem(
            atPath: srcPath,
            toPath: dstPath,
            origin: SentryTraceOriginManualFileData,
            method: method
        )
    }
}
