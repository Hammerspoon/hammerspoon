#import <Cocoa/Cocoa.h>
#import "PKMainWindowController.h"
#import "PKExtensionManager.h"
#import "PKConfigManager.h"
#import "PKDocsManager.h"
void PKSetupLua(void);

@interface HydraAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation HydraAppDelegate

- (IBAction) showSpecificWindow:(NSMenuItem*)item {
    [[PKMainWindowController sharedMainWindowController] showAtTab:[[item title] lowercaseString]];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [PKConfigManager setupConfigDir];
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:[PKConfigManager configPath]];
    [PKDocsManager copyDocsIfNeeded];
    [[PKExtensionManager sharedManager] setup];
    [[PKMainWindowController sharedMainWindowController] showWindow:nil];
    PKSetupLua();
    [[PKExtensionManager sharedManager] loadInstalledModules];
}

@end

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}
