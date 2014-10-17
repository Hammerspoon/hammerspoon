#import <Cocoa/Cocoa.h>
#import "MJConsoleWindowController.h"
#import "MJPreferencesWindowController.h"
#import "MJDockIcon.h"
#import "MJMenuIcon.h"
#import "MJLua.h"
#import "MJVersionUtils.h"
#import "MJConfigUtils.h"
#import "MJFileUtils.h"
#import "MJAccessibilityUtils.h"
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
    MJEnsureDirectoryExists(MJConfigDir());
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:MJConfigDir()];
    
    [self registerDefaultDefaults];
    MJMenuIconSetup(self.menuBarMenu);
    MJDockIconSetup();
    [[MJConsoleWindowController singleton] setup];
    MJLuaSetup();
    
    if (MJFirstRunForCurrentVersion() || !MJAccessibilityIsEnabled())
        [[MJPreferencesWindowController singleton] showWindow: nil];
}

- (void) registerDefaultDefaults {
    [[NSUserDefaults standardUserDefaults]
     registerDefaults: @{MJShowDockIconKey: @YES,
                         MJShowMenuIconKey: @YES,
                         }];
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

- (IBAction) openConfig:(id)sender {
    NSString* path = MJConfigFileFullPath();
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:path]) {
        [[NSFileManager defaultManager] createFileAtPath:path
                                                contents:[NSData data]
                                              attributes:nil];
    }
    
    [[NSWorkspace sharedWorkspace] openFile: path];
}

@end

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}
