import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

@available(iOS 13.0, *)
final class SentryUserFeedbackWidgetButtonView: UIView {
    // MARK: Measurements
    let svgSize: CGFloat = 16
    
    lazy var sizeWithoutLabel = CGSize(width: svgSize * config.scaleFactor + 2 * config.padding, height: svgSize * config.scaleFactor + 2 * config.padding)
    
    // MARK: Properties
    
    lazy var tapGesture = UITapGestureRecognizer(target: self, action: #selector(buttonPressed))
    let target: AnyObject
    let selector: Selector
    let config: SentryUserFeedbackConfiguration
    lazy var megaphone = SentryUserFeedbackWidgetButtonMegaphoneIconView(config: config)
    
    // MARK: Initialization
    
    //swiftlint:disable function_body_length
    init(config: SentryUserFeedbackConfiguration, target: AnyObject, selector: Selector) {
        self.config = config
        self.target = target
        self.selector = selector
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        accessibilityLabel = config.widgetConfig.widgetAccessibilityLabel ?? config.widgetConfig.labelText
        accessibilityIdentifier = "io.sentry.feedback.widget"
        
        let atLeastOneElement = config.widgetConfig.showIcon || config.widgetConfig.labelText != nil
        let preconditionMessage = "User Feedback widget attempted to be displayed with neither text label or icon."
#if DEBUG
        precondition(atLeastOneElement, preconditionMessage)
#endif // DEBUG
        guard atLeastOneElement else {
            SentrySDKLog.warning(preconditionMessage)
            return
        }
        
        var constraints = [NSLayoutConstraint]()
        
        if config.widgetConfig.showIcon {
            constraints.append(contentsOf: [
                megaphone.heightAnchor.constraint(equalToConstant: svgSize),
                megaphone.widthAnchor.constraint(equalTo: megaphone.heightAnchor),
                megaphone.leadingAnchor.constraint(equalTo: leadingAnchor, constant: config.padding)
            ])
        }
        
        layer.addSublayer(lozengeLayer)
        
        if let label = label {
            addSubview(label)
            
            if config.widgetConfig.showIcon {
                addSubview(megaphone)
                let megaphoneCenteringConstraint = config.theme.font.familyName == "Damascus" ? megaphone.centerYAnchor.constraint(equalTo: label.centerYAnchor, constant: -(config.theme.font.capHeight - config.theme.font.ascender)) : megaphone.centerYAnchor.constraint(equalTo: label.firstBaselineAnchor, constant: -config.textEffectiveHeightCenter)
                constraints.append(contentsOf: [
                    label.leadingAnchor.constraint(equalTo: megaphone.trailingAnchor, constant: config.spacing * config.scaleFactor),
                    megaphoneCenteringConstraint
                ])
            } else {
                constraints.append(contentsOf: [
                    label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: config.padding)
                ])
            }
            constraints.append(contentsOf: [
                label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -config.padding),
                label.topAnchor.constraint(equalTo: topAnchor),
                label.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        } else if config.widgetConfig.showIcon {
            addSubview(megaphone)
            constraints.append(contentsOf: [
                megaphone.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -config.padding),
                megaphone.topAnchor.constraint(equalTo: topAnchor, constant: config.padding),
                megaphone.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -config.padding)
            ])
        }
        
        NSLayoutConstraint.activate(constraints)
        
        addGestureRecognizer(tapGesture)
    }
    //swiftlint:enable function_body_length
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateAccessibilityFrame() {
        guard let path = lozengeLayer.path else { return }
        let x = accessibilityFrame.origin.x - path.boundingBox.origin.x
        let y = accessibilityFrame.origin.y - path.boundingBox.origin.y
        let frame = CGRect(x: x, y: y, width: path.boundingBox.size.width, height: path.boundingBox.size.height)
        accessibilityFrame = CGRectApplyAffineTransform(frame, lozengeLayer.affineTransform())
    }
    
    // MARK: Actions
    
    @objc func buttonPressed() {
        let _ = target.perform(selector)
    }
    
    // MARK: UI Elements
    
    lazy var label: UILabel? = {
        guard let text = config.widgetConfig.labelText else {
            return nil
        }
        
        let label = UILabel(frame: .zero)

#if DEBUG
        precondition(!text.isEmpty)
#endif // DEBUG
        
        if text.isEmpty {
            SentrySDKLog.warning("Attempted to show widget button with empty text label. If you don't want to show text, set `SentryUserFeedbackWidgetConfiguration.labelText` to `nil`.")
        }
        
        label.isAccessibilityElement = false
        label.text = text
        label.translatesAutoresizingMaskIntoConstraints = false

        if UIScreen.main.traitCollection.userInterfaceStyle == .dark {
            label.textColor = config.darkTheme.foreground
        } else {
            label.textColor = config.theme.foreground
        }
        
        label.font = config.theme.font
        label.adjustsFontForContentSizeCategory = true
        
        return label
    }()
    
    lazy var lozengeLayer: CAShapeLayer = {
        var finalSize = label?.intrinsicContentSize ?? sizeWithoutLabel
        
        let hasText = config.widgetConfig.labelText != nil
        let scaledLeftPadding = (config.padding * config.scaleFactor) / 2
        let scaledIconSize = svgSize * config.scaleFactor
        let scaledSpacing = config.spacing
        if hasText {
            let iconWidthAdditions = config.widgetConfig.showIcon ? scaledLeftPadding + scaledIconSize + scaledSpacing : config.padding
            finalSize.width += iconWidthAdditions + config.padding
            
            let lozengeHeight = config.theme.font.familyName == "Damascus" ? config.theme.font.lineHeight : (2 * (config.theme.font.ascender - config.textEffectiveHeightCenter))
            finalSize.height = lozengeHeight + 2 * config.padding * config.paddingScaleFactor
        }
        
        let radius: CGFloat = finalSize.height / 2

        let lozengeShape = UIBezierPath()
        lozengeShape.move(to: .init(x: radius, y: 0))
        lozengeShape.addLine(to: .init(x: finalSize.width - radius, y: 0))
        lozengeShape.addArc(withCenter: .init(x: finalSize.width - radius, y: radius), radius: radius, startAngle: 3 * .pi / 2, endAngle: .pi / 2, clockwise: true)
        lozengeShape.addLine(to: .init(x: radius, y: finalSize.height))
        lozengeShape.addArc(withCenter: .init(x: radius, y: radius), radius: radius, startAngle: .pi / 2, endAngle: 3 * .pi / 2, clockwise: true)
        lozengeShape.close()
        
        let lozengeLayer = CAShapeLayer()
        lozengeLayer.path = lozengeShape.cgPath
        
        if UIScreen.main.traitCollection.userInterfaceStyle == .dark {
            lozengeLayer.fillColor = config.darkTheme.background.cgColor
            lozengeLayer.strokeColor = config.darkTheme.outlineStyle.color.cgColor
        } else {
            lozengeLayer.fillColor = config.theme.background.cgColor
            lozengeLayer.strokeColor = config.theme.outlineStyle.color.cgColor
        }
        
        let iconSizeDifference = (scaledIconSize - svgSize) / 2
        if hasText {
            let paddingDifference = (scaledLeftPadding - config.padding) / 2
            let spacingDifference = scaledSpacing - config.spacing
            let increasedIconLeftPadAmountDueToScaling: CGFloat = config.widgetConfig.showIcon ? SentryLocale.isRightToLeftLanguage() ? paddingDifference : paddingDifference + iconSizeDifference + spacingDifference : 0
            let yTranslation = config.theme.font.familyName == "Damascus" ? -(config.padding * config.paddingScaleFactor + (config.theme.font.capHeight - config.theme.font.ascender) * config.paddingScaleFactor) : (-config.padding * config.paddingScaleFactor)
            lozengeLayer.transform = CATransform3DTranslate(lozengeLayer.transform, -increasedIconLeftPadAmountDueToScaling, yTranslation, 0)
        } else {
            lozengeLayer.transform = CATransform3DTranslate(lozengeLayer.transform, -iconSizeDifference, -iconSizeDifference, 0)
        }
        
        return lozengeLayer
    }()
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
