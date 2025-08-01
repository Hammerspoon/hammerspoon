#if canImport(UIKit) && !SENTRY_NO_UIKIT
#if os(iOS) || os(tvOS)

@_implementationOnly import _SentryPrivate
import UIKit

@objcMembers
@_spi(Private) public class SentryScreenshot: NSObject {
    private let photographer: SentryViewPhotographer
    
    public override init() {
        photographer = SentryViewPhotographer(
            renderer: SentryDefaultViewRenderer(),
            redactOptions: SentryRedactDefaultOptions(),
            enableMaskRendererV2: false
        )
        super.init()
    }
    
    /// Get a screenshot of every open window in the app.
    /// - Returns: An array of UIImage instances.
    public func appScreenshotsFromMainThread() -> [UIImage] {
        var result: [UIImage] = []
        
        let takeScreenShot = { result = self.appScreenshots() }
        
        SentryDependencyContainerSwiftHelper.dispatchSync(onMainQueue: takeScreenShot)
        
        return result
    }
    
    /// Get a screenshot of every open window in the app.
    /// - Returns: An array of Data instances containing PNG images.
    public func appScreenshotDatasFromMainThread() -> [Data] {
        var result: [Data] = []
        
        let takeScreenShot = { result = self.appScreenshotsData() }
        
        SentryDependencyContainerSwiftHelper.dispatchSync(onMainQueue: takeScreenShot)
        
        return result
    }
    
    /// Save the current app screen shots in the given directory.
    /// If an app has more than one screen, one image for each screen will be saved.
    /// - Parameter imagesDirectoryPath: The path where the images should be saved.
    public func saveScreenShots(_ imagesDirectoryPath: String) {
        // This function does not dispatch the screenshot to the main thread.
        // The caller should be aware of that.
        // We did it this way because we use this function to save screenshots
        // during signal handling, and if we dispatch it to the main thread,
        // that is probably blocked by the crash event, we freeze the application.
        let screenshotData = appScreenshotsData()
        
        for (index, data) in screenshotData.enumerated() {
            let name = index == 0 ? "screenshot.png" : "screenshot-\(index + 1).png"
            let fileName = (imagesDirectoryPath as NSString).appendingPathComponent(name)
            try? data.write(to: URL(fileURLWithPath: fileName), options: .atomic)
        }
    }
    
    public func appScreenshots() -> [UIImage] {
        let windows = SentryDependencyContainerSwiftHelper.windows() ?? []
        var result: [UIImage] = []
        result.reserveCapacity(windows.count)
        
        for window in windows {
            let size = window.frame.size
            if size.width == 0 || size.height == 0 {
                // avoid API errors reported as e.g.:
                // [Graphics] Invalid size provided to UIGraphicsBeginImageContext(): size={0, 0},
                // scale=1.000000
                continue
            }
            
            let img = photographer.image(view: window)
            
            // this shouldn't happen now that we discard windows with either 0 height or 0 width,
            // but still, we shouldn't send any images with either one.
            if img.size.width > 0 && img.size.height > 0 {
                result.append(img)
            }
        }
        return result
    }
    
    public func appScreenshotsData() -> [Data] {
        let screenshots = appScreenshots()
        var result: [Data] = []
        result.reserveCapacity(screenshots.count)
        
        for screenshot in screenshots {
            // this shouldn't happen now that we discard windows with either 0 height or 0 width,
            // but still, we shouldn't send any images with either one.
            if screenshot.size.width > 0 && screenshot.size.height > 0 {
                if let data = screenshot.pngData(), !data.isEmpty {
                    result.append(data)
                }
            }
        }
        return result
    }
}

#endif // os(iOS) || os(tvOS)
#endif // canImport(UIKit) && !SENTRY_NO_UIKIT 
