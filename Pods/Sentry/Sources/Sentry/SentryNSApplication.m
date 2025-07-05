#import "SentryNSApplication.h"

#if TARGET_OS_OSX

#    import <AppKit/AppKit.h>

@implementation SentryNSApplication

- (BOOL)isActive
{
    NSApplication *application = [NSApplication sharedApplication];
    return application.isActive;
}

@end

#endif // TARGET_OS_OSX
