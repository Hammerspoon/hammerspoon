//swiftlint:disable todo

import Foundation
#if os(iOS) && !SENTRY_NO_UIKIT
import UIKit

var displayingForm = false

protocol SentryUserFeedbackWidgetDelegate: NSObjectProtocol {
    func showForm()
}

@available(iOS 13.0, *)
final class SentryUserFeedbackWidget {
    private lazy var button = {
        let button = SentryUserFeedbackWidgetButtonView(config: config, target: self, selector: #selector(showForm))
        return button
    }()
    lazy var rootVC = RootViewController(config: config, button: button)
    private lazy var window = SentryUserFeedbackWidget.Window(config: config)
    let config: SentryUserFeedbackConfiguration
    weak var delegate: (any SentryUserFeedbackWidgetDelegate)?

    init(config: SentryUserFeedbackConfiguration, delegate: any SentryUserFeedbackWidgetDelegate) {
        self.config = config
        self.delegate = delegate
        window.rootViewController = rootVC
        window.isHidden = false
    }

    @objc func showForm() {
        self.delegate?.showForm()
    }

    final class Window: UIWindow {
        init(config: SentryUserFeedbackConfiguration) {
            super.init(frame: UIScreen.main.bounds)
            windowLevel = config.widgetConfig.windowLevel
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard !displayingForm else {
                return super.hitTest(point, with: event)
            }
            
            guard let result = super.hitTest(point, with: event) else {
                return nil
            }
            guard result.isKind(of: SentryUserFeedbackWidgetButtonView.self) else {
                return nil
            }
            return result
        }
    }

    final class RootViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
        let defaultWidgetSpacing: CGFloat = 8
        weak var button: SentryUserFeedbackWidgetButtonView?
        init(config: SentryUserFeedbackConfiguration, button: SentryUserFeedbackWidgetButtonView) {
            self.button = button
            super.init(nibName: nil, bundle: nil)

            view.addSubview(button)

            var constraints = [NSLayoutConstraint]()
            if config.widgetConfig.location.contains(.bottom) {
                constraints.append(button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -config.widgetConfig.layoutUIOffset.vertical))
            }
            if config.widgetConfig.location.contains(.top) {
                constraints.append(button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: config.widgetConfig.layoutUIOffset.vertical))
            }
            if config.widgetConfig.location.contains(.trailing) {
                constraints.append(button.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -config.widgetConfig.layoutUIOffset.horizontal))
            }
            if config.widgetConfig.location.contains(.leading) {
                constraints.append(button.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: config.widgetConfig.layoutUIOffset.horizontal))
            }
            NSLayoutConstraint.activate(constraints)
        }

        required init?(coder: NSCoder) {
            fatalError("SentryUserFeedbackWidget.RootViewController is not intended to be initialized from a nib or storyboard.")
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            button?.updateAccessibilityFrame()
        }

        func setWidget(visible: Bool, animated: Bool) {
            if animated {
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                    self.button?.alpha = visible ? 1 : 0
                }
            } else {
                button?.isHidden = !visible
            }
        }
    }
}

#endif // os(iOS) && !SENTRY_NO_UIKIT

//swiftlint:enable todo
