#import <Cocoa/Cocoa.h>
#import "MJMainWindowController.h"
#import "MJExtensionManager.h"
#import "MJConfigManager.h"
#import "MJDocsManager.h"
#import "MJAutoUpdaterWindowController.h"
#import "MJUpdate.h"
#import "core.h"
#import "variables.h"

@interface MJAppDelegate : NSObject <NSApplicationDelegate, MJAutoUpdaterWindowControllerDelegate, NSUserNotificationCenterDelegate>
@property NSTimer* autoupdateTimer;
@property MJAutoUpdaterWindowController* updaterWindowController;
@property NSStatusItem* statusItem;
@property NSUserNotification* updateNote;
@end

@implementation MJAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self registerDefaultDefaults];
    [self setupStatusItem];
    [self setupCheckUpdatesTimer];
    [MJConfigManager setupConfigDir];
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:[MJConfigManager configPath]];
    [MJDocsManager copyDocsIfNeeded];
    [[MJExtensionManager sharedManager] setup];
    [[MJMainWindowController sharedMainWindowController] showWindow:nil];
    MJSetupLua();
    [[MJExtensionManager sharedManager] loadInstalledModules];
    MJReloadConfig();
}

- (void) registerDefaultDefaults {
    NSDictionary* defaults = @{MJCheckForUpdatesKey: @YES};
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
}

- (void) setupStatusItem {
    NSImage* icon = [NSImage imageNamed:@"statusicon"];
    [icon setTemplate:YES];
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
    [self.statusItem setImage:icon];
    [self.statusItem setHighlightMode:YES];
}

- (void) setupCheckUpdatesTimer {
    self.autoupdateTimer = [NSTimer scheduledTimerWithTimeInterval:MJCheckForUpdatesInterval
                                                            target:self
                                                          selector:@selector(checkForUpdatesTimerFired:)
                                                          userInfo:nil
                                                           repeats:YES];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MJCheckForUpdatesDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self checkForUpdatesInBackground];
    });
}

- (IBAction) checkForUpdates:(id)sender {
    if (!self.updaterWindowController)
        self.updaterWindowController = [[MJAutoUpdaterWindowController alloc] init];
    
    [self.updaterWindowController showCheckingPage];
    
    [MJUpdate checkForUpdate:^(MJUpdate *update, NSError* connError) {
        if (update) {
            self.updaterWindowController.update = update;
            [self.updaterWindowController showFoundPage];
        }
        else if (connError) {
            self.updaterWindowController.error = [connError localizedDescription];
            [self.updaterWindowController showErrorPage];
        }
        else {
            [self.updaterWindowController showUpToDatePage];
        }
    }];
}

- (void) userDismissedAutoUpdaterWindow {
    self.updaterWindowController = nil;
}

- (void) checkForUpdatesInBackground {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:MJCheckForUpdatesKey])
        return;
    
    [MJUpdate checkForUpdate:^(MJUpdate *update, NSError* connError) {
        if (update) {
            self.updateNote = [[NSUserNotification alloc] init];
            self.updateNote.title = @"Mjolnir update available";
            
            NSUserNotificationCenter* center = [NSUserNotificationCenter defaultUserNotificationCenter];
            [center setDelegate: self];
            [center deliverNotification: self.updateNote];
            
            if (!self.updaterWindowController)
                self.updaterWindowController = [[MJAutoUpdaterWindowController alloc] init];
            
            self.updaterWindowController.update = update;
        }
    }];
}

- (void)userNotificationCenter:(NSUserNotificationCenter *)center didActivateNotification:(NSUserNotification *)notification {
    [[NSUserNotificationCenter defaultUserNotificationCenter] removeDeliveredNotification:self.updateNote];
    self.updateNote = nil;
    [self.updaterWindowController showFoundPage];
}

- (BOOL) userNotificationCenter:(NSUserNotificationCenter *)center shouldPresentNotification:(NSUserNotification *)notification {
    return YES;
}

- (void) checkForUpdatesTimerFired:(NSTimer*)timer {
    [self checkForUpdatesInBackground];
}

@end

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}
