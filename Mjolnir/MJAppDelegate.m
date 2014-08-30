#import <Cocoa/Cocoa.h>
#import "MJConsoleWindowController.h"
#import "MJPreferencesWindowController.h"
#import "MJConfigUtils.h"
#import "MJUpdateChecker.h"
#import "MJDockIcon.h"
#import "MJMenuIcon.h"
#import "MJLua.h"
#import "variables.h"

@interface MJAppDelegate : NSObject <NSApplicationDelegate>
@property IBOutlet NSMenu* menuBarMenu;
@end

@implementation MJAppDelegate

- (BOOL) applicationShouldHandleReopen:(NSApplication*)theApplication hasVisibleWindows:(BOOL)hasVisibleWindows {
    if (!hasVisibleWindows)
        [[MJPreferencesWindowController singleton] showWindow: nil];
    
    return NO;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self registerDefaultDefaults];
    MJMenuIconSetup(self.menuBarMenu);
    MJDockIconSetup();
    MJUpdateCheckerSetup();
    MJConfigEnsureDirExists();
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:MJConfigPath()];
    [[MJConsoleWindowController singleton] setup];
    MJLuaSetup();
    
    if (![[NSUserDefaults standardUserDefaults] boolForKey: MJHasRunAlreadyKey]) {
        [[MJPreferencesWindowController singleton] showWindow: nil];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:MJHasRunAlreadyKey];
    }
}

- (void) registerDefaultDefaults {
    [[NSUserDefaults standardUserDefaults]
     registerDefaults: @{MJCheckForUpdatesKey: @YES,
                         MJShowDockIconKey: @YES,
                         MJShowMenuIconKey: @NO,
                         MJCheckForUpdatesIntervalKey: @(60.0 * 60.0 * 24.0)}];
}

- (IBAction) reloadConfig:(id)sender {
    MJLuaSetup();
}

- (IBAction) showConsoleWindow:(id)sender {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[MJConsoleWindowController singleton] showWindow: nil];
}

- (IBAction) showPreferencesWindow:(id)sender {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[MJPreferencesWindowController singleton] showWindow: nil];
}

- (IBAction) showAboutPanel:(id)sender {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    [[NSApplication sharedApplication] orderFrontStandardAboutPanel: nil];
}

- (IBAction) checkForUpdates:(id)sender {
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
    MJUpdateCheckerCheckVerbosely();
}

- (IBAction) openConfig:(id)sender {
    if (![[NSWorkspace sharedWorkspace] openFile:[MJConfigPath() stringByAppendingPathComponent:@"init.lua"]]) {
        NSAlert* alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert setMessageText:@"Config file doesn't exist"];
        [alert setInformativeText:@"You can fix this by creating an empty ~/.mjolnir/init.lua file."];
        [alert runModal];
    }
}

@end

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}
