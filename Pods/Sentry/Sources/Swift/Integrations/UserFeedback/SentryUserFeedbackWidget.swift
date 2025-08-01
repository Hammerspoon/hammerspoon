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

    private var window: Window?

    let config: SentryUserFeedbackConfiguration
    weak var delegate: (any SentryUserFeedbackWidgetDelegate)?

    init(config: SentryUserFeedbackConfiguration, delegate: any SentryUserFeedbackWidgetDelegate) {
        self.config = config
        self.delegate = delegate

        /*
         * We must have a UIScene in order to display an overlaying UIWindow in a SwiftUI app, which is currently how we display the widget. SentryUserFeedbackIntegrationDriver won't try to initialize this class if there are no connected UIScenes _and_ there is no UIApplicationDelegate at the time the integration is being installed.
         *
         * Both UIKit and SwiftUI apps can have connected UIScenes. Here's how we then try to tell the difference:
         * - If there is no connected UIScene but there is already a UIApplicationDelegate by the time this integration is being installed, then we are either in a UIKit app, or inside a SwiftUI app that for whatever reason delays the call to SentrySDK.start until there is a connected scene. In either case, we'll just grab the first connected UIScene and proceed.
         * - Otherwise, we're either in a SwiftUI app that _does_ call SentrySDK.start at the recommended time (SwiftUIApp.init), or there is a more complicated initialization procedure in a UIKit app that we can't automatically detect, and the app will need to call SentrySDK.feedback.showWidget() at the appropriate time, the same as how SwiftUI apps must currently do once they've connected a UIScene to their UIApplicationDelegateAdaptor.
         */
        let window: Window
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            window = SentryUserFeedbackWidget.Window(config: config, windowScene: scene)
        } else {
            window = SentryUserFeedbackWidget.Window(config: config)
        }
        window.rootViewController = rootVC
        window.isHidden = false
        self.window = window
    }

    @objc func showForm() {
        self.delegate?.showForm()
    }

    final class Window: UIWindow {
        private func _init(config: SentryUserFeedbackConfiguration) {
            windowLevel = config.widgetConfig.windowLevel
        }

        init(config: SentryUserFeedbackConfiguration, windowScene: UIWindowScene) {
            super.init(windowScene: windowScene)
            _init(config: config)
        }

        init(config: SentryUserFeedbackConfiguration) {
            super.init(frame: UIScreen.main.bounds)
            _init(config: config)
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
