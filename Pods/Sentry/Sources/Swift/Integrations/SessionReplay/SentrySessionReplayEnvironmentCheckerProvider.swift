@_spi(Private) @objc public protocol SentrySessionReplayEnvironmentCheckerProvider {
    /// Checks if the runtime environment is considered unreliable with regards to Session Replay masking.
    ///
    /// - Returns: `true` if reliable, otherwise `false`
    func isReliable() -> Bool
}
