@_spi(Private) public final class SentryFrameRemover: NSObject {
    
    /// Removes Sentry SDK frames until a frame from a different package is found.
    /// @discussion When a user includes Sentry as a static library, the package is the same as the
    /// application. Therefore removing frames with a package containing "sentry" doesn't work. We can't
    /// look into the function name as in release builds, the function name can be obfuscated, or we
    /// remove functions that are not from this SDK and contain "sentry". Therefore this logic only works
    /// for apps including Sentry dynamically.
    @objc public static func removeNonSdkFrames(_ frames: [Frame]) -> [Frame] {
        let indexOfFirstNonSentryFrame = frames.firstIndex { frame in
            guard let package = frame.package?.lowercased() else {
                return true
            }
            return !package.contains("/sentry.framework/") && !package.contains("/sentryprivate.framework/")
        }
        
        if let indexOfFirstNonSentryFrame {
            return Array(frames[indexOfFirstNonSentryFrame...])
        }
        return frames
    }
}
