// Don't move Foundation.h. We need it here in order to have
// TargetConditionals.h automatically imported. This is needed
// so that `#if TARGET_OS_OSX` is working fine. If we move
// this the SDK breaks for MacOS.
#import <Foundation/Foundation.h>

#if TARGET_OS_OSX
#    import <AppKit/NSApplication.h>
@interface SentryCrashExceptionApplication : NSApplication
#else
@interface SentryCrashExceptionApplication : NSObject
#endif

@end
