#if (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
import Foundation
import UIKit

@objcMembers
@_spi(Private) public class SentryMaskingPreviewView: UIView {
    private class PreviewRenderer: SentryViewRenderer {
        func render(view: UIView) -> UIImage {
            return UIGraphicsImageRenderer(size: view.frame.size, format: .init(for: .init(displayScale: 1))).image { _ in
                // Creates a transparent image of the view size that will be used to drawn the redact regions.
                // Transparent background is the default, so no additional drawing is required.
                // Left blank on purpose
            }
        }
    }
    
    private let photographer: SentryViewPhotographer
    private var displayLink: CADisplayLink?
    private var imageView = UIImageView()
    private var idle = true
    
    public var opacity: Float {
        get { return Float(imageView.alpha) }
        set { imageView.alpha = CGFloat(newValue)}
    }
    
    public init(redactOptions: SentryRedactOptions) {
        self.photographer = SentryViewPhotographer(
            renderer: PreviewRenderer(),
            redactOptions: redactOptions,
            enableMaskRendererV2: false
        )
        super.init(frame: .zero)
        self.isUserInteractionEnabled = false
        
        imageView.sentryReplayUnmask()
        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)
    }
        
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        displayLink?.invalidate()
    }
    
    public override func didMoveToSuperview() {
        if displayLink == nil {
            displayLink = CADisplayLink(target: self, selector: #selector(update))
            displayLink?.add(to: .main, forMode: .common)
        }

        if let superview = self.superview {
            self.frame = superview.bounds
        }
    }
    
    @objc
    private func update() {
        guard let superview = self.superview, idle else { return }
        idle = false
        self.photographer.image(view: superview) { maskedViewImage in
            DispatchQueue.main.async {
                self.imageView.image = maskedViewImage
                self.idle = true
            }
        }
    }
}

#endif // (os(iOS) || os(tvOS)) && !SENTRY_NO_UIKIT
