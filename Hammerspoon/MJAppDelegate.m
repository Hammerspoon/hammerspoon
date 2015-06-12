#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>
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
#import "secrets.h"

@interface MJAppDelegate : NSObject <NSApplicationDelegate, CrashlyticsDelegate>
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

    if(NSClassFromString(@"XCTest") != nil) {
        NSLog(@"in testing mode!");
        const char *tmp = [[[NSBundle bundleForClass:NSClassFromString(@"Hammerspoon_Tests")] pathForResource:@"init" ofType:@"lua"] fileSystemRepresentation];
        NSLog(@"testing init.lua is [%s], if this is null, we crash on the next line", tmp);
        MJConfigFile = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:tmp length:strlen(tmp)];
    }

    MJEnsureDirectoryExists(MJConfigDir());
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:MJConfigDir()];

    [self registerDefaultDefaults];

    // Enable Crashlytics, if we have an API key available
#ifdef CRASHLYTICS_API_KEY
    if (HSUploadCrashData()) {
        Crashlytics *crashlytics = [Crashlytics sharedInstance];
        crashlytics.debugMode = YES;
        [Crashlytics startWithAPIKey:[NSString stringWithUTF8String:CRASHLYTICS_API_KEY] delegate:self];
    }
#endif

    MJMenuIconSetup(self.menuBarMenu);
    MJDockIconSetup();
    [[MJConsoleWindowController singleton] setup];
    MJLuaSetup();

    // FIXME: Do we care about showing the prefs on the first run of each new version? (Ng does not care)
    if (MJFirstRunForCurrentVersion() || !MJAccessibilityIsEnabled())
        [[MJPreferencesWindowController singleton] showWindow: nil];
}

- (void) registerDefaultDefaults {
    [[NSUserDefaults standardUserDefaults]
     registerDefaults: @{@"NSApplicationCrashOnExceptions": @YES,
                         MJShowDockIconKey: @YES,
                         MJShowMenuIconKey: @YES,
                         HSAutoLoadExtensions: @YES,
                         HSUploadCrashDataKey: @YES,
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

- (IBAction) quitHammerspoon:(id)sender {
    MJLuaTeardown();
    [[NSApplication sharedApplication] terminate:nil];
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

- (void)showMjolnirMigrationNotification {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:@"Hammerspoon crash detected"];
    [alert setInformativeText:@"Your init.lua is loading Mjolnir modules and a previous launch crashed.\n\nHammerspoon ships with updated versions of many of the Mjolnir modules, with both new features and many bug fixes.\n\nPlease consult our API documentation and migrate your config."];
    [alert setAlertStyle:NSCriticalAlertStyle];
    [alert runModal];
}

- (void)crashlyticsDidDetectReportForLastExecution:(CLSReport *)report completionHandler:(void (^)(BOOL submit))completionHandler {
    BOOL showMjolnirMigrationDialog = NO;

    if ([report.customKeys objectForKey:@"MjolnirModuleLoaded"]) {
        showMjolnirMigrationDialog = YES;
    }

    completionHandler(YES);

    if (showMjolnirMigrationDialog) {
        [self showMjolnirMigrationNotification];
    }
}

@end

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}
