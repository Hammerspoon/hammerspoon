import Foundation

@objc
protocol SentryRedactOptions {
    var redactAllText: Bool { get }
    var redactAllImages: Bool { get }
}
