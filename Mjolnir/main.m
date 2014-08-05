#import <Cocoa/Cocoa.h>
#import "MJMainWindowController.h"
#import "MJExtensionManager.h"
#import "MJConfigManager.h"
#import "MJDocsManager.h"
void MJSetupLua(void);

@interface MJAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation MJAppDelegate

- (IBAction) showSpecificWindow:(NSMenuItem*)item {
    [[MJMainWindowController sharedMainWindowController] showAtTab:[item title]];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [MJConfigManager setupConfigDir];
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:[MJConfigManager configPath]];
    [MJDocsManager copyDocsIfNeeded];
    [[MJExtensionManager sharedManager] setup];
    [[MJMainWindowController sharedMainWindowController] showWindow:nil];
    MJSetupLua();
    [[MJExtensionManager sharedManager] loadInstalledModules];
}

@end

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}
