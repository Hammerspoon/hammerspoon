import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
@_implementationOnly import _SentryPrivate
import UIKit

@available(iOS 13.0, *) @objc
protocol SentryUserFeedbackIntegrationDriverDelegate: NSObjectProtocol {
    func capture(feedback: SentryFeedback)
}

/**
 * An integration managing a workflow for end users to report feedback via Sentry.
 * - note: The default method to show the feedback form is via a floating widget placed in the bottom trailing corner of the screen. See the configuration classes for alternative options.
 */
@available(iOS 13.0, *)
@objcMembers
class SentryUserFeedbackIntegrationDriver: NSObject {
    let configuration: SentryUserFeedbackConfiguration
    private var widget: SentryUserFeedbackWidget?
    weak var delegate: (any SentryUserFeedbackIntegrationDriverDelegate)?
    let screenshotProvider: SentryScreenshot
    weak var customButton: UIButton?

    public init(configuration: SentryUserFeedbackConfiguration, delegate: any SentryUserFeedbackIntegrationDriverDelegate, screenshotProvider: SentryScreenshot) {
        self.configuration = configuration
        self.delegate = delegate
        self.screenshotProvider = screenshotProvider
        super.init()

        if let uiFormConfigBuilder = configuration.configureForm {
            uiFormConfigBuilder(configuration.formConfig)
        }
        if let themeOverrideBuilder = configuration.configureTheme {
            themeOverrideBuilder(configuration.theme)
        }
        if let darkThemeOverrideBuilder = configuration.configureDarkTheme {
            darkThemeOverrideBuilder(configuration.darkTheme)
        }

        if let customButton = configuration.customButton {
            customButton.addTarget(self, action: #selector(showForm(sender:)), for: .touchUpInside)
        } else if let widgetConfigBuilder = configuration.configureWidget {
            widgetConfigBuilder(configuration.widgetConfig)
            validate(configuration.widgetConfig)
            if configuration.widgetConfig.autoInject {
                widget = SentryUserFeedbackWidget(config: configuration, delegate: self)
            }
        }

        observeScreenshots()
    }

    deinit {
        customButton?.removeTarget(self, action: #selector(showForm(sender:)), for: .touchUpInside)
    }

    @objc public func showWidget() {
        if widget == nil {
            widget = SentryUserFeedbackWidget(config: configuration, delegate: self)
        } else {
            widget?.rootVC.setWidget(visible: true, animated: configuration.animations)
        }
    }

    @objc public func hideWidget() {
        widget?.rootVC.setWidget(visible: false, animated: configuration.animations)
    }

    @objc func showForm(sender: UIButton) {
        presenter?.present(SentryUserFeedbackFormController(config: configuration, delegate: self, screenshot: nil), animated: configuration.animations) {
            self.configuration.onFormOpen?()
        }
    }
}

// MARK: SentryUserFeedbackFormDelegate
@available(iOSApplicationExtension 13.0, *)
extension SentryUserFeedbackIntegrationDriver: SentryUserFeedbackFormDelegate {
    func finished(with feedback: SentryFeedback?) {
        if let feedback = feedback {
            delegate?.capture(feedback: feedback)
        }
        presenter?.dismiss(animated: configuration.animations) {
            self.configuration.onFormClose?()
        }
        widget?.rootVC.setWidget(visible: true, animated: configuration.animations)
        displayingForm = false
    }
}

// MARK: SentryUserFeedbackWidgetDelegate
@available(iOSApplicationExtension 13.0, *)
extension SentryUserFeedbackIntegrationDriver: SentryUserFeedbackWidgetDelegate {
    func showForm() {
        showForm(screenshot: nil)
    }
}

// MARK: UIAdaptivePresentationControllerDelegate
@available(iOSApplicationExtension 13.0, *)
extension SentryUserFeedbackIntegrationDriver: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        widget?.rootVC.setWidget(visible: true, animated: configuration.animations)
        displayingForm = false
        configuration.onFormClose?()
    }
}

// MARK: Private
@available(iOSApplicationExtension 13.0, *)
private extension SentryUserFeedbackIntegrationDriver {
    func showForm(screenshot: UIImage?) {
        let form = SentryUserFeedbackFormController(config: configuration, delegate: self, screenshot: screenshot)
        form.presentationController?.delegate = self
        widget?.rootVC.setWidget(visible: false, animated: configuration.animations)
        displayingForm = true
        presenter?.present(form, animated: configuration.animations) {
            self.configuration.onFormOpen?()
        }
    }

    func validate(_ config: SentryUserFeedbackWidgetConfiguration) {
        let noOpposingHorizontals = config.location.contains(.trailing) && !config.location.contains(.leading)
        || !config.location.contains(.trailing) && config.location.contains(.leading)
        let noOpposingVerticals = config.location.contains(.top) && !config.location.contains(.bottom)
        || !config.location.contains(.top) && config.location.contains(.bottom)
        let atLeastOneLocation = config.location.contains(.trailing)
        || config.location.contains(.leading)
        || config.location.contains(.top)
        || config.location.contains(.bottom)
        let notAll = !config.location.contains(.all)
        let valid = noOpposingVerticals && noOpposingHorizontals && atLeastOneLocation && notAll
#if DEBUG
        assert(valid, "Invalid widget location specified: \(config.location). Must specify either one edge or one corner of the screen rect to place the widget.")
#endif // DEBUG
        if !valid {
            SentryLog.warning("Invalid widget location specified: \(config.location). Must specify either one edge or one corner of the screen rect to place the widget.")
        }
    }

    func observeScreenshots() {
        if configuration.showFormForScreenshots {
            NotificationCenter.default.addObserver(self, selector: #selector(userCapturedScreenshot), name: UIApplication.userDidTakeScreenshotNotification, object: nil)
        }
    }

    @objc func userCapturedScreenshot() {
        stopObservingScreenshots()
        showForm(screenshot: screenshotProvider.appScreenshots().first)
    }

    func stopObservingScreenshots() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.userDidTakeScreenshotNotification, object: nil)
    }

    var presenter: UIViewController? {
        if let customButton = configuration.customButton {
            return customButton.controller
        }
        
        return widget?.rootVC
    }
}

extension UIView {
    /// In order to present our form, we need a `UIViewController` on which to call `presentViewController`. This computed var helps to find one. While we may know the owning UIVC for our own widget button, we won't know the makeup of the view/controller hierarchy if a customer uses their own button with `SentryUserFeedbackConfiguration.customButton`.
    /// - returns: The innermost `UIViewController` instance managing the receiving view.
    var controller: UIViewController? {
        var responder = next
        while responder != nil {
            guard let resolvedResponder = responder else { break }
            let klass = type(of: resolvedResponder)
            guard klass.isSubclass(of: UIViewController.self) else {
                responder = resolvedResponder.next
                continue
            }
            return resolvedResponder as? UIViewController
        }
        return nil
    }
}

#endif // os(iOS) && !SENTRY_NO_UIKIT
