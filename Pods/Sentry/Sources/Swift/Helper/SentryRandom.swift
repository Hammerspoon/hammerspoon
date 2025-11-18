import Foundation

/// Protocol for generating random numbers.
@objc
@_spi(Private) public protocol SentryRandomProtocol {
    /// Returns a random number uniformly distributed over the interval [0.0 , 1.0].
    @objc func nextNumber() -> Double
}

@objc
@_spi(Private) public class SentryRandom: NSObject, SentryRandomProtocol {
    /// Returns a random number uniformly distributed over the interval [0.0 , 1.0].
    @objc public func nextNumber() -> Double {
        Double.random(in: 0...1)
    }
}
