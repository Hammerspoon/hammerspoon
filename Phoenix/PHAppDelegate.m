#import "PHAppDelegate.h"

#import "PHScript.h"

@implementation PHAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [[PHScript sharedScript] reload];
}

@end
