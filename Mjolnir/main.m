#import <Cocoa/Cocoa.h>
#import "MJMainWindowController.h"
#import "MJExtensionManager.h"
#import "MJConfigManager.h"
#import "MJDocsManager.h"
#import "MJUpdaterWindowController.h"
#import "MJUpdater.h"
#import "core.h"

#import "MJVerifiers.h"

#define MJCheckForUpdatesDelay (5.0)
#define MJCheckForUpdatesInterval (60.0 * 60.0 * 24.0)

@interface MJAppDelegate : NSObject <NSApplicationDelegate>
@property NSTimer* autoupdateTimer;
@property MJUpdaterWindowController* updaterWindowController;
@end

@implementation MJAppDelegate

static NSStatusItem* statusItem;

- (IBAction) checkForUpdates:(id)sender {
    [self checkForUpdatesNow];
}

- (void) checkForUpdatesNow {
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
    if (![[NSUserDefaults standardUserDefaults] boolForKey:MJCheckForUpdatesKey])
        return;
    
    [self checkForUpdatesNow];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSData* tgzdata = [NSData dataWithContentsOfFile:@"/Users/sdegutis/projects/mjolnir/Mjolnir-0.1.tgz"];
    BOOL verified = MJVerifySignedData([@"MCwCFGMFozJWzloeHM649+4zU3W5rnfPAhRYCnXEH0hXNuUiREXIMHdz1DzwPg==" dataUsingEncoding:NSUTF8StringEncoding], tgzdata);
    assert(verified); // "file isn't verifying for some reason"
    
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
