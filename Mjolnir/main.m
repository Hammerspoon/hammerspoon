#import <Cocoa/Cocoa.h>
#import "MJMainWindowController.h"
#import "MJExtensionManager.h"
#import "MJConfigManager.h"
#import "MJDocsManager.h"
#import "MJAutoUpdaterWindowController.h"
#import "MJUpdate.h"
#import "core.h"

#define MJCheckForUpdatesDelay (0.0)
#define MJCheckForUpdatesInterval (60.0 * 60.0 * 24.0)

@interface MJAppDelegate : NSObject <NSApplicationDelegate>
@property NSTimer* autoupdateTimer;
@property MJAutoUpdaterWindowController* updaterWindowController;
@end

@implementation MJAppDelegate

static NSStatusItem* statusItem;

- (IBAction) checkForUpdates:(id)sender {
    [self checkForUpdatesNow];
}

- (void) checkForUpdatesNow {
    [MJUpdate checkForUpdate:^(MJUpdate *update) {
        if (update) {
            if (!self.updaterWindowController)
                self.updaterWindowController = [[MJAutoUpdaterWindowController alloc] init];
            
            self.updaterWindowController.update = update;
            [self.updaterWindowController showWindow];
        }
    }];
}

- (void) checkForUpdatesTimerFired:(NSTimer*)timer {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:MJCheckForUpdatesKey])
        return;
    
    [self checkForUpdatesNow];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSImage* icon = [NSImage imageNamed:@"statusicon"];
    [icon setTemplate:YES];
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    [statusItem setImage:icon];
    [statusItem setHighlightMode:YES];
    
    self.autoupdateTimer = [NSTimer scheduledTimerWithTimeInterval:MJCheckForUpdatesInterval
                                                            target:self
                                                          selector:@selector(checkForUpdatesTimerFired:)
                                                          userInfo:nil
                                                           repeats:YES];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MJCheckForUpdatesDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self checkForUpdatesTimerFired: nil];
    });
    
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
