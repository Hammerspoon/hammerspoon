import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
import UIKit

/**
 * Settings for overriding theming components for the User Feedback Widget and Form.
 */
@available(iOS 13.0, *)
@objcMembers
public class SentryUserFeedbackThemeConfiguration: NSObject {
    /**
     * The font family to use for form text elements.
     * - note: Defaults to the system default, if this property is `nil`.
     */
    public lazy var fontFamily: String? = nil
    
    /**
     * Font for form input elements and the widget button label.
     * - note: Defaults to `UIFont.TextStyle.callout`.
     */
    lazy var font = scaledFont(style: .callout)
    
    /**
     * Font for the main header title of the feedback form.
     * - note: Defaults to `UIFont.TextStyle.title1`.
     */
    lazy var headerFont = scaledFont(style: .title1)
    
    /**
     * Font for titles of text fields and buttons in the form.
     * - note: Defaults to `UIFont.TextStyle.headline`.
     */
    lazy var titleFont = scaledFont(style: .headline)
    
    /**
     * Return a scaled font for the given style, using the configured font family.
     */
    func scaledFont(style: UIFont.TextStyle) -> UIFont {
        guard let fontFamily = fontFamily, let font = UIFont(name: fontFamily, size: UIFont.systemFontSize) else {
            return UIFont.preferredFont(forTextStyle: style)
        }
        return UIFontMetrics(forTextStyle: style).scaledFont(for: font)
    }
    
    /**
     * Helps respond to dynamic font size changes when the app is in the background, and then comes back to the foreground.
     */
    func updateDefaultFonts() {
        font = scaledFont(style: .callout)
        headerFont = scaledFont(style: .title1)
        titleFont = scaledFont(style: .headline)
    }
    
    /**
     * Foreground text color of the widget and form.
     * - note: Default light mode: `rgb(43, 34, 51)`; dark mode: `rgb(235, 230, 239)`
     */
    public var foreground = UIScreen.main.traitCollection.userInterfaceStyle == .dark ? UIColor(red: 235 / 255, green: 230 / 255, blue: 239 / 255, alpha: 1) : UIColor(red: 43 / 255, green: 34 / 255, blue: 51 / 255, alpha: 1)
    
    /**
     * Background color of the widget and form.
     * - note: Default light mode: `rgb(255, 255, 255)`; dark mode: `rgb(41, 35, 47)`
     */
    public var background = UIScreen.main.traitCollection.userInterfaceStyle == .dark ? UIColor(red: 41 / 255, green: 35 / 255, blue: 47 / 255, alpha: 1) : UIColor.white
    
    /**
     * Foreground color for the form submit button.
     * - note: Default: `rgb(255, 255, 255)` for both dark and light modes
     */
    public var submitForeground: UIColor = UIColor.white
    
    /**
     * Background color for the form submit button in light and dark modes.
     * - note: Default: `rgb(88, 74, 192)` for both light and dark modes
     */
    public var submitBackground: UIColor = UIColor(red: 88 / 255, green: 74 / 255, blue: 192 / 255, alpha: 1)
    
    /**
     * Foreground color for the cancel and screenshot buttons.
     * - note: Default: Same as `foreground` for both dark and light modes
     */
    public lazy var buttonForeground: UIColor = foreground
    
    /**
     * Background color for the form cancel and screenshot buttons in light and dark modes.
     * - note: Default: Transparent for both light and dark modes
     */
    public var buttonBackground: UIColor = UIColor.clear
    
    /**
     * Color used for error-related components (such as text color when there's an error submitting feedback).
     * - note: Default light mode: `rgb(223, 51, 56)`; dark mode: `rgb(245, 84, 89)`
     */
    public var errorColor = UIScreen.main.traitCollection.userInterfaceStyle == .dark ? UIColor(red: 245 / 255, green: 84 / 255, blue: 89 / 255, alpha: 1) : UIColor(red: 223 / 255, green: 51 / 255, blue: 56 / 255, alpha: 1)
    
    @objc public class SentryFormElementOutlineStyle: NSObject {
        /**
         * Outline color for form inputs.
         * - note: Default: The system default of a UITextField outline with borderStyle of .roundedRect.
         */
        public var color = UIColor(white: 204 / 255, alpha: 1)
        
        /**
         * Outline corner radius for form input elements.
         * - note: Default: `5`.
         */
        public var cornerRadius: CGFloat = 5
        
        /**
         * The thickness of the outline.
         * - note: Default: `0.5`.
         */
        public var outlineWidth: CGFloat = 0.5
        
        @objc public init(color: UIColor = UIColor(white: 204 / 255, alpha: 1), cornerRadius: CGFloat = 5, outlineWidth: CGFloat = 0.5) {
            self.color = color
            self.cornerRadius = cornerRadius
            self.outlineWidth = outlineWidth
        }
    }
    
    /**
     * - note: We need to keep a reference to a default instance of this for comparison purposes later. We don't use the default to give UITextFields a default style, instead, we use `UITextField.BorderStyle.roundedRect` if `SentryUserFeedbackThemeConfiguration.outlineStyle == defaultOutlineStyle`.
     */
    let defaultOutlineStyle = SentryFormElementOutlineStyle()
    
    /**
     * Options for styling the outline of input elements and buttons in the feedback form.
     */
    public lazy var outlineStyle: SentryFormElementOutlineStyle = defaultOutlineStyle
    
    /**
     * Background color to use for text inputs in the feedback form.
     */
    public var inputBackground: UIColor = UIColor.secondarySystemBackground
    
    /**
     * Background color to use for text inputs in the feedback form.
     */
    public var inputForeground: UIColor = UIScreen.main.traitCollection.userInterfaceStyle == .dark ? UIColor.lightText : UIColor.darkText
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
