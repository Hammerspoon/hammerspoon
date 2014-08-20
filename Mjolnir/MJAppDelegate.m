#import <Cocoa/Cocoa.h>
#import "MJMainWindowController.h"
#import "MJExtensionManager.h"
#import "MJConfigManager.h"
#import "MJDocsManager.h"
#import "MJUpdateChecker.h"
#import "MJDockIcon.h"
#import "core.h"
#import "variables.h"

@interface MJAppDelegate : NSObject <NSApplicationDelegate>
@property NSStatusItem* statusItem;
@end

@implementation MJAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self registerDefaultDefaults];
    [self setupStatusItem];
    [[MJDockIcon sharedDockIcon] setup];
    [[MJUpdateChecker sharedChecker] setup];
    [MJConfigManager setupConfigDir];
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:[MJConfigManager configPath]];
    [MJDocsManager copyDocsIfNeeded];
    [[MJExtensionManager sharedManager] setup];
    [[MJMainWindowController sharedMainWindowController] maybeShowWindow];
    MJSetupLua();
    [[MJExtensionManager sharedManager] loadInstalledModules];
    MJReloadConfig();
}

- (void) registerDefaultDefaults {
    NSDictionary* defaults = @{MJCheckForUpdatesKey: @YES,
                               MJShowDockIconKey: @YES,
                               MJShowWindowAtLaunchKey: @YES};
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void) setupStatusItem {
    NSImage* icon = [NSImage imageNamed:@"statusicon"];
    [icon setTemplate:YES];
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    [self.statusItem setImage:icon];
    [self.statusItem setHighlightMode:YES];
}

- (IBAction) reloadConfig:(id)sender {
    MJReloadConfig();
}

@end

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}
