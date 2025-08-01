//swiftlint:disable type_body_length

import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
import UIKit

@available(iOS 13.0, *)
protocol SentryUserFeedbackFormDelegate: NSObjectProtocol {
    func finished(with feedback: SentryFeedback?)
}

@available(iOS 13.0, *)
final class SentryUserFeedbackFormController: UIViewController {
    let config: SentryUserFeedbackConfiguration
    weak var delegate: SentryUserFeedbackFormDelegate?
    let screenshot: UIImage?
    lazy var viewModel = SentryUserFeedbackFormViewModel(config: config, controller: self, screenshot: screenshot)
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        config.theme.updateDefaultFonts()
        config.recalculateScaleFactors()
        viewModel.updateLayout()
    }
    
    init(config: SentryUserFeedbackConfiguration, delegate: SentryUserFeedbackFormDelegate?, screenshot: UIImage?) {
        self.config = config
        self.delegate = delegate
        self.screenshot = screenshot
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = config.theme.background
        initLayout()
        viewModel.themeElements()
        
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(showedKeyboard(note:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        nc.addObserver(self, selector: #selector(hidKeyboard), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: Layout
@available(iOS 13.0, *)
extension SentryUserFeedbackFormController {
    func initLayout() {
        viewModel.setScrollViewBottomInset(0)
        view.addSubview(viewModel.scrollView)
        NSLayoutConstraint.activate(viewModel.allConstraints(view: view))
    }
    
    @objc
    func showedKeyboard(note: Notification) {
        guard let keyboardValue = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else {
            SentrySDKLog.warning("Received a keyboard display notification with no frame information.")
            return
        }
        let keyboardViewEndFrame = self.view.convert(keyboardValue.cgRectValue, from: self.view.window)
        viewModel.setScrollViewBottomInset(keyboardViewEndFrame.height - self.view.safeAreaInsets.bottom)
    }
    
    @objc
    func hidKeyboard() {
        viewModel.setScrollViewBottomInset(0)
    }
}

// MARK: SentryUserFeedbackFormViewModelDelegate
@available(iOS 13.0, *)
extension SentryUserFeedbackFormController: SentryUserFeedbackFormViewModelDelegate {
    func submitFeedback() {
        switch viewModel.validate() {
        case .success(_):
            let feedback = viewModel.feedbackObject()
            SentrySDKLog.debug("Sending user feedback")
            if let block = config.onSubmitSuccess {
                block(feedback.dataDictionary())
            }
            delegate?.finished(with: feedback)
        case .failure(let error):
            func presentAlert(message: String, errorCode: Int, info: [String: Any]) {
                let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: config.animations) {
                    if let block = self.config.onSubmitError {
                        // we use NSError here instead of Swift.Error because NSError automatically bridges to Swift.Error, but the same is not true in the other direction if you want to include a userInfo dictionary. Using Swift.Error would require additional implementation for this to work with ObjC consumers.
                        block(NSError(domain: "io.sentry.error", code: errorCode, userInfo: info))
                    }
                }
            }
            
            guard case let SentryUserFeedbackFormViewModel.InputError.validationError(missing) = error else {
                SentrySDKLog.warning("Unexpected error type.")
                presentAlert(message: "Unexpected client error.", errorCode: 2, info: [NSLocalizedDescriptionKey: "Client error: ."])
                return
            }
            
            presentAlert(message: error.description, errorCode: 1, info: ["missing_fields": missing, NSLocalizedDescriptionKey: "The user did not complete the feedback form."])
        }
    }
    
    func cancel() {
        delegate?.finished(with: nil)
    }
}

// MARK: UITextFieldDelegate
@available(iOS 13.0, *)
extension SentryUserFeedbackFormController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        viewModel.updateSubmitButtonAccessibilityHint()
    }
}

// MARK: UITextViewDelegate
@available(iOS 13.0, *)
extension SentryUserFeedbackFormController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        viewModel.messageTextViewPlaceholder.isHidden = textView.text != ""
        viewModel.updateSubmitButtonAccessibilityHint()
    }
}

#if DEBUG && swift(>=5.10)
import SwiftUI

@available(iOS 13.0, *)
struct ViewControllerWrapper: UIViewControllerRepresentable {
    let viewController: UIViewController

    func makeUIViewController(context: Context) -> UIViewController {
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }
}

@available(iOS 17.0, *)
#Preview {
    SentryUserFeedbackFormController(config: .init(), delegate: nil, screenshot: nil)
}

@available(iOS 17.0, *)
#Preview {
    ViewControllerWrapper(
        viewController: SentryUserFeedbackFormController(
            config: .init(),
            delegate: nil,
            screenshot: nil))
    .preferredColorScheme(.dark).colorScheme(.dark)
}

@available(iOS 17.0, *)
#Preview {
    ViewControllerWrapper(
        viewController: SentryUserFeedbackFormController(
            config: .init(),
            delegate: nil,
            screenshot: nil))
    .dynamicTypeSize(.accessibility5)
}
#endif // DEBUG && swift(>=5.10)

#endif // os(iOS) && !SENTRY_NO_UIKIT

//swiftlint:enable type_body_length
