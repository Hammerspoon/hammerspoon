import Foundation

@objcMembers
public class SentryExperimentalOptions: NSObject {
    /**
     * Enables swizzling of`NSData` to automatically track file operations.
     *
     * - Note: Swizzling is enabled by setting ``SentryOptions.enableSwizzling`` to `true`.
     *         This option allows you to disable swizzling for `NSData` only, while keeping swizzling enabled for other classes.
     *         This is useful if you want to use manual tracing for file operations.
     */
    public var enableDataSwizzling = true

    /**
     * Enables swizzling of`NSFileManager` to automatically track file operations.
     *
     * - Note: Swizzling is enabled by setting ``SentryOptions.enableSwizzling`` to `true`.
     *         This option allows you to disable swizzling for `NSFileManager` only, while keeping swizzling enabled for other classes.
     *         This is useful if you want to use manual tracing for file operations.
     * - Experiment: This is an experimental feature and is therefore disabled by default. We'll enable it by default in a future release.
     */
    public var enableFileManagerSwizzling = false

    /**
     * A more reliable way to report unhandled C++ exceptions.
     *
     * This approach hooks into all instances of the `__cxa_throw` function, which provides a more comprehensive and consistent exception handling across an app’s runtime, regardless of the number of C++ modules or how they’re linked. It helps in obtaining accurate stack traces.
     *
     * - Note: The mechanism of hooking into `__cxa_throw` could cause issues with symbolication on iOS due to caching of symbol references.
     * - Experiment: This is an experimental feature and is therefore disabled by default. We'll enable it by default in a future major release.
     */
    public var enableUnhandledCPPExceptionsV2 = false

    @_spi(Private) public func validateOptions(_ options: [String: Any]?) {
    }
}

// Makes the `experimental` property visible as the Swift type `SentryExperimentalOptions`.
// This works around `SentryExperimentalOptions` being only forward declared in the objc header.
@objc
extension Options {

   /**
    * This aggregates options for experimental features.
    * Be aware that the options available for experimental can change at any time.
    */
    @objc
    open var experimental: SentryExperimentalOptions {
      // We know the type so it's fine to force cast.
      // swiftlint:disable force_cast
        _swiftExperimentalOptions as! SentryExperimentalOptions
      // swiftlint:enable force_cast
    }
}
