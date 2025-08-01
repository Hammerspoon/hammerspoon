import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

@available(iOS 13.0, *)
final class SentryUserFeedbackWidgetButtonMegaphoneIconView: UIView {
    init(config: SentryUserFeedbackConfiguration) {
        super.init(frame: .zero)
    
        let svgLayer = CAShapeLayer()
        svgLayer.path = SentryIconography.megaphone
        svgLayer.fillColor = UIColor.clear.cgColor
        
        if UIScreen.main.traitCollection.userInterfaceStyle == .dark {
            svgLayer.strokeColor = config.darkTheme.foreground.cgColor
        } else {
            svgLayer.strokeColor = config.theme.foreground.cgColor
        }
        
        layer.addSublayer(svgLayer)
        translatesAutoresizingMaskIntoConstraints = false
        
        var transform = CATransform3DIdentity
        if config.scaleFactor != 1 {
            transform = CATransform3DConcat(transform, CATransform3DMakeScale(config.scaleFactor, config.scaleFactor, 0))
        }
        
        if SentryLocale.isRightToLeftLanguage() {
            transform = CATransform3DConcat(transform, CATransform3DMakeScale(-1, 1, 1))
        }
        
        layer.transform = transform
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
