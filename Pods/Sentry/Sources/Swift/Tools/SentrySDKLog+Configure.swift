@_implementationOnly import _SentryPrivate
import Foundation

// This helper class exists because if it was just an extension on SentrySDKLog the linker would strip this code unless the "-ObjC" flag was passed.
// The result would be the selector would be missing at runtime and objc code that calls the method would crash.
// More details here: https://github.com/swiftlang/swift/issues/48561
@objc
@_spi(Private) public class SentrySDKLogSupport: NSObject {

  @objc
  public static func configure(_ isDebug: Bool, diagnosticLevel: SentryLevel) {
      SentrySDKLog._configure(isDebug, diagnosticLevel: diagnosticLevel)
      SentryAsyncLogWrapper.initializeAsyncLogFile()
  }
}
