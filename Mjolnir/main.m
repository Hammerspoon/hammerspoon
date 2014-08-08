#import <Cocoa/Cocoa.h>
#import "MJMainWindowController.h"
#import "MJExtensionManager.h"
#import "MJConfigManager.h"
#import "MJDocsManager.h"
#import "core.h"

@interface MJAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation MJAppDelegate

static NSStatusItem* statusItem;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSImage* icon = [NSImage imageNamed:@"statusicon"];
    [icon setTemplate:YES];
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    [statusItem setImage:icon];
    [statusItem setHighlightMode:YES];
    
    [MJConfigManager setupConfigDir];
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:[MJConfigManager configPath]];
    [MJDocsManager copyDocsIfNeeded];
    [[MJExtensionManager sharedManager] setup];
    [[MJMainWindowController sharedMainWindowController] showWindow:nil];
    MJSetupLua();
    [[MJExtensionManager sharedManager] loadInstalledModules];
    MJReloadConfig();
}

@end

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}
