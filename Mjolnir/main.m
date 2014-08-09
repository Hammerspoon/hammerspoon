#import <Cocoa/Cocoa.h>
#import "MJMainWindowController.h"
#import "MJExtensionManager.h"
#import "MJConfigManager.h"
#import "MJDocsManager.h"
#import "MJUpdaterWindowController.h"
#import "MJUpdater.h"
#import "core.h"

#define MJCheckForUpdatesDelay (5.0)
#define MJCheckForUpdatesInterval (60.0 * 60.0 * 24.0)

@interface MJAppDelegate : NSObject <NSApplicationDelegate>
@property NSTimer* autoupdateTimer;
@property MJUpdaterWindowController* updaterWindowController;
@end

@implementation MJAppDelegate

static NSStatusItem* statusItem;

- (void) checkForUpdatesNow {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:MJCheckForUpdatesKey])
        return;
    
    [MJUpdater checkForUpdate:^(MJUpdater *updater) {
        if (updater) {
            if (!self.updaterWindowController)
                self.updaterWindowController = [[MJUpdaterWindowController alloc] init];
            
            self.updaterWindowController.updater = updater;
            [self.updaterWindowController showWindow:self];
        }
    }];
}

- (void) checkForUpdatesTimerFired:(NSTimer*)timer {
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
        [self checkForUpdatesNow];
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
