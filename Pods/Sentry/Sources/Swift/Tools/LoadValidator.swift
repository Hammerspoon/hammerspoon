@_implementationOnly import _SentryPrivate
import Darwin
import Foundation
import MachO

@objc
@_spi(Private) public final class LoadValidator: NSObject {
    // Any class should be fine, ObjC classes are better
    static let targetClassName = NSStringFromClass(SentryDependencyContainerSwiftHelper.self)
    
    // This function is used to check for duplicated SDKs in the binary.
    // Since `SentryBinaryImageInfo` is not public and only available through the Hybrid SDK, we use the expanded parameters.
    @objc
    @_spi(Private) public class func checkForDuplicatedSDK(imageName: String,
                                                           imageAddress: NSNumber,
                                                           imageSize: NSNumber,
                                                           objcRuntimeWrapper: SentryObjCRuntimeWrapper,
                                                           dispatchQueueWrapper: SentryDispatchQueueWrapper) {
        internalCheckForDuplicatedSDK(imageName, imageAddress.uint64Value, imageSize.uint64Value,
                                      objcRuntimeWrapper: objcRuntimeWrapper,
                                      dispatchQueueWrapper: dispatchQueueWrapper)
    }
    
    class func internalCheckForDuplicatedSDK(_ imageName: String, _ imageAddress: UInt64, _ imageSize: UInt64, objcRuntimeWrapper: SentryObjCRuntimeWrapper, dispatchQueueWrapper: SentryDispatchQueueWrapper, resultHandler: ((Bool) -> Void)? = nil) {
        let systemLibraryPath = "/usr/lib/"
        let ignoredPathDevelopers = "/Library/Developer/CoreSimulator/Volumes/"
        let ignoredPathSystem = "/System/Library/"
        guard !imageName.hasPrefix(ignoredPathDevelopers) && !imageName.hasPrefix(ignoredPathSystem) && !imageName.hasPrefix(systemLibraryPath) else {
            resultHandler?(false)
            return
        }
        dispatchQueueWrapper.dispatchAsync {
            var duplicateFound = false
            defer {
                resultHandler?(duplicateFound)
            }
            
            let loadValidatorAddress = self.getCurrentFrameworkTextPointer()
            let loadValidatorAddressValue = UInt(bitPattern: loadValidatorAddress)
            // The SDK looks for classes on each image. We might find:
            //   - Unrelated Classes, nothing to do
            //   - Classes with the exact name (`SentryDependencyContainerSwiftHelper`), if it is present in the same text section as LoadValidator is, it is our implementation, it isn't it is a duplicate class
            //   - Classes containing `SentryDependencyContainerSwiftHelper`, it also is a duplicate
            let isCurrentImageContainingLoadValidator = (loadValidatorAddressValue >= imageAddress) && (loadValidatorAddressValue < (imageAddress + imageSize))

            var classCount: UInt32 = 0
            imageName.withCString { cImageName in
                if let classNames = objcRuntimeWrapper.copyClassNamesForImage(cImageName, &classCount) {
                    defer {
                        free(classNames)
                    }
                    for j in 0..<Int(classCount) {
                        let className = classNames[j]
                        // Since we are iterating over all classes in the image, we need to be extra careful not to do unnecesarry work
                        // or calling `NSClassFromString` since that can lead to issues (see `SentrySubClassFinder` for more details).
                        let name = String(cString: UnsafeRawPointer(className).assumingMemoryBound(to: UInt8.self))
                        if name == self.targetClassName && isCurrentImageContainingLoadValidator {
                            // Skip the implementation of the class we are using as a proxy for being loaded that exists in the same binary that this instance of LoadValidator was loaded in
                            continue
                        }
                        if name.contains(self.targetClassName) {
                            var message = ["❌ Sentry SDK was loaded multiple times in the same binary ❌"]
                            message.append("⚠️ This can cause undefined behavior, crashes, or duplicate reporting.")
                            message.append("Ensure the SDK is linked only once, found `\(self.targetClassName)` class in image path: \(imageName)")
                            SentrySDKLog.error(message.joined(separator: "\n"))
                            duplicateFound = true
                            
                            break
                        }
                    }
                }
            }
        }
    }
    
    /**
     * Returns a pointer to a function inside the `__TEXT` segment of the binary containing this class
     */
    class func getCurrentFrameworkTextPointer() -> UnsafeRawPointer {
        let cFunction: @convention(c) () -> Void = { }
        let c = unsafeBitCast(cFunction, to: UnsafeRawPointer.self)
        return c
    }
}
