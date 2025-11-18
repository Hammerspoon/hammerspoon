#if canImport(UIKit) && !SENTRY_NO_UIKIT
import Foundation
import UIKit

@objc
@_spi(Private) public protocol SentryReplayVideoMaker: NSObjectProtocol {
    func addFrameAsync(timestamp: Date, maskedViewImage: UIImage, forScreen: String?)
    func releaseFramesUntil(_ date: Date)
    func createVideoInBackgroundWith(beginning: Date, end: Date, completion: @escaping ([SentryVideoInfo]) -> Void)
    func createVideoWith(beginning: Date, end: Date) -> [SentryVideoInfo]
}

extension SentryReplayVideoMaker {
    func addFrameAsync(timestamp: Date, maskedViewImage: UIImage) {
        self.addFrameAsync(timestamp: timestamp, maskedViewImage: maskedViewImage, forScreen: nil)
    }
}

#endif
