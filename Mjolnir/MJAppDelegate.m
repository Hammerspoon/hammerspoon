#import <Cocoa/Cocoa.h>
#import "MJMainWindowController.h"
#import "MJExtensionManager.h"
#import "MJConfigManager.h"
#import "MJDocsManager.h"
#import "MJUpdateChecker.h"
#import "MJDockIcon.h"
#import "MJMenuIcon.h"
#import "core.h"
#import "variables.h"

@interface MJAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation MJAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self registerDefaultDefaults];
    MJMenuIconSetup();
    MJDockIconSetup();
    MJUpdateCheckerSetup();
    MJConfigSetupDir();
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:MJConfigPath()];
    MJDocsCopyIfNeeded();
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

- (IBAction) reloadConfig:(id)sender {
    MJReloadConfig();
}

- (IBAction) checkForUpdates:(id)sender {
    MJUpdateCheckerCheckVerbosely();
}

@end

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}
