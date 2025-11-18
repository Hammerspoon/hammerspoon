import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
import UIKit

/**
 * Settings for whether to show the widget and how it should appear.
 */
@available(iOS 13.0, *)
@objcMembers
public class SentryUserFeedbackWidgetConfiguration: NSObject {
    /**
     * Automatically inject the widget button into the application UI.
     * - note: Default: `true`
     * - warning: Does not currently work for SwiftUI apps. See https://docs.sentry.io/platforms/apple/user-feedback/#swiftui
     */
    public var autoInject: Bool = true
    
    let defaultLabelText = "Report a Bug"
    
    /**
     * The label of the injected button that opens up the feedback form when clicked. If `nil`, no
     * text is displayed and only the icon image is shown.
     * - note: Default: `"Report a Bug"`
     */
    public lazy var labelText: String? = defaultLabelText
    
    /**
     * Whether or not to show our icon along with the text in the button.
     * - note: Default: `true`.
     */
    public var showIcon: Bool = true
    
    /**
     * The accessibility label of the injected button that opens up the feedback form when clicked.
     * - note: Default: `labelText` value
     */
    public lazy var widgetAccessibilityLabel: String? = labelText ?? defaultLabelText
    
    /**
     * The window level of the widget.
     * - note: Default: `UIWindow.Level.normal + 1`
     */
    public var windowLevel: UIWindow.Level = UIWindow.Level.normal + 1
    
    /**
     * The location for positioning the widget.
     * - note: Default: `[.bottom, .right]`
     */
    public var location: NSDirectionalRectEdge = [.bottom, .trailing]
    
    /**
     * The distance to use from the widget button to the `safeAreaLayoutGuide` of the root view in the widget's container window.
     * - note: Default: `UIOffset.zero`
     */
    public var layoutUIOffset: UIOffset = UIOffset.zero
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
