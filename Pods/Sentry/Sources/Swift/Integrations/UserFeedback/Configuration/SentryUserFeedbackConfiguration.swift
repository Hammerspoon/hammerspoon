import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
import UIKit

/**
 * The settings to use for how the user feedback form is presented, what data is required and how
 * it's submitted, and some auxiliary hooks to customize the workflow.
 */
@available(iOS 13.0, *)
@objcMembers
public class SentryUserFeedbackConfiguration: NSObject {
    /**
     * Whether or not to show animations, like for presenting and dismissing the form.
     * - note: Default: `true`.
     */
    public var animations: Bool = true
    
    /**
     * Configuration settings specific to the managed widget that displays the UI form.
     * - note: Default: `nil` to use the default widget settings.
     */
    public var configureWidget: ((SentryUserFeedbackWidgetConfiguration) -> Void)?
    
    lazy var widgetConfig = SentryUserFeedbackWidgetConfiguration()
    
    /**
     * Use a shake gesture to display the form.
     * - note: Default: `false`
     * - note: Setting this to true does not disable the widget. In order to do so, you must set `SentryUserFeedbackWidgetConfiguration.autoInject` to `false` using the `SentryUserFeedbackConfiguration.configureWidget` config builder.
     */
    public var useShakeGesture: Bool = false
    
    /**
     * Any time a user takes a screenshot, bring up the form with the screenshot attached.
     * - note: Default: `false`
     * - note: Setting this to true does not disable the widget. In order to do so, you must set `SentryUserFeedbackWidgetConfiguration.autoInject` to `false` using the `SentryUserFeedbackConfiguration.configureWidget` config builder.
     */
    public var showFormForScreenshots: Bool = false

    /**
     * Install a hook for the specified button to show the form when it is pressed.
     * - note: If this is set, `configureWidget` is ignored.
     * - note: Default: `nil`
     */
    public var customButton: UIButton?

    /**
     * Configuration settings specific to the managed UI form to gather user input.
     * - note: Default: `nil`
     */
    public var configureForm: ((SentryUserFeedbackFormConfiguration) -> Void)?
    
    lazy var formConfig = SentryUserFeedbackFormConfiguration()

    /**
     * Tags to set on the feedback event. This is a dictionary where keys are strings
     * and values can be different data types such as `NSNumber`, `NSString`, etc.
     * - note: Default: `nil`
     */
    public var tags: [String: Any]?
    
    /**
     * Called when the managed feedback form is opened.
     * - note: Default: `nil`
     */
    public var onFormOpen: (() -> Void)?
    
    /**
     * Called when the managed feedback form is closed.
     * - note: Default: `nil`
     */
    public var onFormClose: (() -> Void)?
    
    /**
     * Called when feedback is successfully submitted via the managed feedback form, indicating that the
     * user correctly filled out the form and confirmed submission. The data dictionary contains the feedback details.
     * - note: Default: `nil`
     * - note: This is unrelated to `SentrySDK.captureUserFeedback` and is not called when using 
     * that function.
     */
    public var onSubmitSuccess: (([String: Any]) -> Void)?
    
    /**
     * Called when there is an error submitting feedback via the managed feedback form, like missing
     * required inputs. The error object contains details of the error.
     * - note: Default: `nil`
     * - note: This is unrelated to `SentrySDK.captureUserFeedback` and is not called when using 
     * that function.
     */
    public var onSubmitError: ((Error) -> Void)?
    
    // MARK: Theme
    
    /**
     * Builder for default/light theme overrides.
     * - note: On iOS versions predating dark mode (≤12) this is the only theme override used. Apps
     * running on later versions that include dark mode should also consider `configureDarkTheme`.
     * - note: Default: `nil`
     */
    public var configureTheme: ((SentryUserFeedbackThemeConfiguration) -> Void)?
    
    lazy var theme = SentryUserFeedbackThemeConfiguration()
    
    /**
     * Builder for dark mode theme overrides. If your app does not deploy a different theme for dark
     * mode, but you still want to override some theme settings, assign the same builder to this
     * property as you do for `configureTheme`.
     * - note: Default: `nil`
     * - note: Only applies to iOS ≤12.
     */
    public var configureDarkTheme: ((SentryUserFeedbackThemeConfiguration) -> Void)?
    
    lazy var darkTheme = SentryUserFeedbackThemeConfiguration()
    
    // MARK: Derived properties
    
    lazy var textEffectiveHeightCenter: CGFloat = {
        theme.font.familyName == "Damascus" ? theme.font.lineHeight / 2 + theme.font.lineHeight - theme.font.capHeight : theme.font.capHeight / 2
    }()
    
    /// The ratio of the configured font size to the system default font size, to know how large to scale things like the icon and lozenge shape.
    lazy var scaleFactor = calculateScaleFactor()
    
    func calculateScaleFactor() -> CGFloat {
        let fontSize = theme.font.pointSize
        guard fontSize > 0 else {
            return 1
        }
            
        return fontSize / UIFont.systemFontSize
    }
    
    /// Too much padding as the font size grows larger makes the button look weird with lots of negative space. Keeping the padding constant looks weird if the text is too small. So, scale it down below system default font sizes, but keep it fixed with larger font sizes.
    lazy var paddingScaleFactor = calculatePaddingScaleFactor()
    
    func calculatePaddingScaleFactor() -> CGFloat {
        scaleFactor > 1 ? 1 : scaleFactor
    }
    
    func recalculateScaleFactors() {
        scaleFactor = calculateScaleFactor()
        paddingScaleFactor = calculatePaddingScaleFactor()
    }
    
    // MARK: Layout
    
    let padding: CGFloat = 16
    let spacing: CGFloat = 8
    let margin: CGFloat = 32
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
