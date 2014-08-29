#import <Cocoa/Cocoa.h>
#import "MJMainWindowController.h"
#import "MJConfigUtils.h"
#import "MJUpdateChecker.h"
#import "MJDockIcon.h"
#import "MJMenuIcon.h"
#import "MJLua.h"
#import "variables.h"

@interface MJAppDelegate : NSObject <NSApplicationDelegate>
@property IBOutlet NSMenu* menuBarMenu;
@property IBOutlet NSMenu* dockIconMenu;
@property BOOL finishedLaunching;
@end

@implementation MJAppDelegate

- (BOOL) applicationOpenUntitledFile:(NSApplication *)sender {
    if (!self.finishedLaunching && ![[NSUserDefaults standardUserDefaults] boolForKey: MJShowWindowAtLaunchKey])
        return NO;
    
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[MJMainWindowController sharedMainWindowController] showWindow: nil];
    return YES;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.finishedLaunching = YES; // because Apple doesn't seem to keep track of this variable themselves
    
    [self registerDefaultDefaults];
    MJMenuIconSetup(self.menuBarMenu);
    MJDockIconSetup();
    MJUpdateCheckerSetup();
    MJConfigEnsureDirExists();
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:MJConfigPath()];
    [[MJMainWindowController sharedMainWindowController] setup];
    MJLuaSetup();
    MJLuaReloadConfig();
}

- (NSMenu *)applicationDockMenu:(NSApplication *)sender {
    return self.dockIconMenu;
}

- (void) registerDefaultDefaults {
    [[NSUserDefaults standardUserDefaults]
     registerDefaults: @{MJCheckForUpdatesKey: @YES,
                         MJShowDockIconKey: @YES,
                         MJShowWindowAtLaunchKey: @YES,
                         MJShowMenuIconKey: @NO}];
}

- (IBAction) reloadConfig:(id)sender {
    MJLuaReloadConfig();
}

- (IBAction) showMainWindow:(id)sender {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[MJMainWindowController sharedMainWindowController] showWindow: nil];
}

- (IBAction) showAboutPanel:(id)sender {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[NSApplication sharedApplication] orderFrontStandardAboutPanel: nil];
}

- (IBAction) checkForUpdates:(id)sender {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    MJUpdateCheckerCheckVerbosely();
}

@end

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}
