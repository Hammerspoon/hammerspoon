// Don't move Foundation.h. We need it here in order to have
// TargetConditionals.h automatically imported. This is needed
// so that `#if TARGET_OS_OSX` is working fine. If we move
// this the SDK breaks for MacOS.
#import <Foundation/Foundation.h>

// Required for capturing uncaught exceptions in macOS. For more info see
// https://docs.sentry.io/platforms/apple/guides/macos/usage/#capturing-uncaught-exceptions-in-macos
#if TARGET_OS_OSX
#    import <AppKit/NSApplication.h>
@interface SentryCrashExceptionApplication : NSApplication
#else
@interface SentryCrashExceptionApplication : NSObject
#endif

@end
