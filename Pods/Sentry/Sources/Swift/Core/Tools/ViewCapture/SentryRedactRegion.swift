#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)
import Foundation
import ObjectiveC.NSObjCRuntime
import UIKit

final class SentryRedactRegion {
    let size: CGSize
    let transform: CGAffineTransform
    let type: SentryRedactRegionType
    let color: UIColor?
    let name: String

    init(size: CGSize, transform: CGAffineTransform, type: SentryRedactRegionType, color: UIColor? = nil, name: String) {
        self.size = size
        self.transform = transform
        self.type = type
        self.color = color
        self.name = name
    }

    func canReplace(as other: SentryRedactRegion) -> Bool {
        size == other.size && transform == other.transform && type == other.type
    }
}
#endif
#endif
