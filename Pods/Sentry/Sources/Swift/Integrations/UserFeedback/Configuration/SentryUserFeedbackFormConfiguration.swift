import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
import UIKit

/**
 * Settings to control the behavior and appearance of the UI form.
 */
@available(iOS 13.0, *)
@objcMembers
public class SentryUserFeedbackFormConfiguration: NSObject {
    // MARK: General settings
    
    /**
     * Sets the email and name field text content to the values contained in the current scope's
     * `SentryUser` instance, if any.
     * - seealso: `- [SentrySDK setUser:]`
     * - note: Default: `true`
     */
    public var useSentryUser: Bool = true
    
    /**
     * Displays the Sentry logo inside of the form.
     * - note: Default: `true`
     */
    public var showBranding: Bool = true
    
    /**
     * The title at the top of the feedback form.
     * - note: Default: `"Report a Bug"`
     */
    public var formTitle: String = "Report a Bug"
    
    /**
     * The label for the feedback description input field.
     * - note: Default: `"Description"`
     */
    public var messageLabel: String = "Description"
    
    lazy var messageLabelContents = fullLabelText(labelText: messageLabel, required: true)
    
    /**
     * The placeholder for the feedback description input field.
     * - note: Default: `"What's the bug? What did you expect?"`
     */
    public var messagePlaceholder: String = "What's the bug? What did you expect?"
    
    public lazy var messageTextViewAccessibilityLabel: String = messagePlaceholder
    
    /**
     * The label shown next to an input field that is required.
     * - note: Default: `"(Required)"`
     */
    public var isRequiredLabel: String = "(Required)"
    
    // MARK: Screenshots
    
    /**
     * The label of the button to remove the screenshot from the form.
     * - note: Default: `"Remove screenshot"`
     * - note: ignored if `SentryUserFeedbackConfiguration.showFormForScreenshots` is `false`.
     */
    public var removeScreenshotButtonLabel: String = "Remove screenshot"
    
    public lazy var removeScreenshotButtonAccessibilityLabel = removeScreenshotButtonLabel
    
    // MARK: Name
    
    /**
     * Requires the name field on the feedback form to be filled in.
     * - note: Default: `false`
     */
    public var isNameRequired: Bool = false
    
    /**
     * Displays the name field on the feedback form.
     * - note: Default: `true`
     * - note: ignored if `isNameRequired` is `true`.
     */
    public var showName: Bool = true
    
    /**
     * The label of the name input field.
     * - note: Default: `"Name"`
     * - note: ignored if `showName` is `false`.
     */
    public var nameLabel: String = "Name"
    
    lazy var nameLabelContents = fullLabelText(labelText: nameLabel, required: isNameRequired)
    
    /**
     * The placeholder for the name input field.
     * - note: Default: `"Your Name"`
     * - note: ignored if `showName` is `false`.
     */
    public var namePlaceholder: String = "Your Name"
    
    public lazy var nameTextFieldAccessibilityLabel = namePlaceholder
    
    // MARK: Email
    
    /**
     * Requires the email field on the feedback form to be filled in.
     * - note: Default: `false`
     */
    public var isEmailRequired: Bool = false
    
    /**
     * Displays the email field on the feedback form.
     * - note: Default: `true`
     * - note: ignored if `isEmailRequired` is `true`.
     */
    public var showEmail: Bool = true
    
    /**
     * The label of the email input field.
     * - note: Default: `"Email"`
     */
    public var emailLabel: String = "Email"
    
    lazy var emailLabelContents = fullLabelText(labelText: emailLabel, required: isEmailRequired)
    
    /**
     * The placeholder for the email input field.
     * - note: Default: `"your.email@example.org"`
     */
    public var emailPlaceholder: String = "your.email@example.org"
    
    public lazy var emailTextFieldAccessibilityLabel = "Your email address"
    
    // MARK: Buttons
    
    /**
     * The label of the submit button used in the feedback form.
     * - note: Default: `"Send Bug Report"`
     */
    public var submitButtonLabel: String = "Send Bug Report"
    
    /**
     * The accessibility label of the form's "Submit" button.
     * - note: Default: `submitButtonLabel` value
     */
    public lazy var submitButtonAccessibilityLabel: String = submitButtonLabel
    
    /**
     * The label of cancel buttons used in the feedback form.
     * - note: Default: `"Cancel"`
     */
    public var cancelButtonLabel: String = "Cancel"
    
    /**
     * The accessibility label of the form's "Cancel" button.
     * - note: Default: `cancelButtonLabel` value
     */
    public lazy var cancelButtonAccessibilityLabel: String = cancelButtonLabel
    
    func fullLabelText(labelText: String, required: Bool) -> String {
        required ? labelText + " " + isRequiredLabel : labelText
    }
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
