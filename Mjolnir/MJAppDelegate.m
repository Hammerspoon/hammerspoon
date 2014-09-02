#import <Cocoa/Cocoa.h>
#import "MJConsoleWindowController.h"
#import "MJPreferencesWindowController.h"
#import "MJUpdateChecker.h"
#import "MJDockIcon.h"
#import "MJMenuIcon.h"
#import "MJLua.h"
#import "MJVersionUtils.h"
#import "variables.h"

@interface MJAppDelegate : NSObject <NSApplicationDelegate>
@property IBOutlet NSMenu* menuBarMenu;
@end

@implementation MJAppDelegate

static BOOL MJFirstRunForCurrentVersion(void) {
    NSString* key = [NSString stringWithFormat:@"%@_%d", MJHasRunAlreadyKey, MJVersionFromThisApp()];
    
    BOOL firstRun = ![[NSUserDefaults standardUserDefaults] boolForKey:key];
    
    if (firstRun)
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];
    
    return firstRun;
}

- (BOOL) applicationShouldHandleReopen:(NSApplication*)theApplication hasVisibleWindows:(BOOL)hasVisibleWindows {
    [[MJConsoleWindowController singleton] showWindow: nil];
    return NO;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self registerDefaultDefaults];
    MJMenuIconSetup(self.menuBarMenu);
    MJDockIconSetup();
    MJUpdateCheckerSetup();
    [[MJConsoleWindowController singleton] setup];
    MJLuaSetup();
    
    if (MJFirstRunForCurrentVersion())
        [[MJPreferencesWindowController singleton] showWindow: nil];
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
    NSString* prettypath = MJFindInitFile();
    if (!prettypath) {
        NSMutableString* msg = [@"Create one of the following files and try again:\n" mutableCopy];
        
        for (const char** iter = MJInitPaths; *iter; iter++) {
            const char* path = *iter;
            [msg appendFormat:@"\n%s", path];
        }
        
        NSAlert* alert = [[NSAlert alloc] init];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert setMessageText:@"Config file doesn't exist"];
        [alert setInformativeText:msg];
        [alert runModal];
        return;
    }
    
    NSString* fullpath = [prettypath stringByStandardizingPath];
    [[NSWorkspace sharedWorkspace] openFile: fullpath];
}

@end

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}
