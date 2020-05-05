#if TARGET_OS_OSX
#import <Cocoa/Cocoa.h>
@interface SentryCrashExceptionApplication : NSApplication
#else
#import <Foundation/Foundation.h>
@interface SentryCrashExceptionApplication : NSObject
#endif

@end
