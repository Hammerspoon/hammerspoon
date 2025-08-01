#import <Foundation/Foundation.h>

#if TARGET_OS_OSX

#    import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryUncaughtNSExceptions : NSObject

/**
 * This method will force the application to crash when an uncaught exception occurs. We recommended
 * this approach cause otherwise, the application can end up in a corrupted state because the Cocoa
 * Frameworks are generally not exception-safe:
 * https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Exceptions/Articles/ExceptionsAndCocoaFrameworks.html.
 */
+ (void)configureCrashOnExceptions;

+ (void)swizzleNSApplicationReportException;

+ (void)capture:(nullable NSException *)exception;

@end

NS_ASSUME_NONNULL_END

#endif // TARGET_OS_OSX
