#import "MJUpdateChecker.h"
#import "MJAutoUpdaterWindowController.h"
#import "MJUserNotificationManager.h"
#import "MJUpdate.h"
#import "variables.h"

static CFRunLoopTimerRef autoupdateTimer;
static MJAutoUpdaterWindowController* updaterWindowController;
static id closedObserver;

void callback(CFRunLoopTimerRef timer, void *info) {
    MJUpdateCheckerCheckSilently();
}

static void reflect_defaults(void) {
    if (MJUpdateCheckerEnabled())
        CFRunLoopAddTimer(CFRunLoopGetMain(), autoupdateTimer, kCFRunLoopCommonModes);
    else
        CFRunLoopRemoveTimer(CFRunLoopGetMain(), autoupdateTimer, kCFRunLoopCommonModes);
}

void MJUpdateCheckerSetup(void) {
    CFTimeInterval interval = [[NSUserDefaults standardUserDefaults] doubleForKey:MJCheckForUpdatesIntervalKey];
    autoupdateTimer = CFRunLoopTimerCreate(NULL, 0, interval, 0, 0, &callback, NULL);
    reflect_defaults();
    
    if (MJUpdateCheckerEnabled())
        CFRunLoopTimerSetNextFireDate(autoupdateTimer, CFAbsoluteTimeGetCurrent());
}

static MJAutoUpdaterWindowController* definitelyRealWindowController(void) {
    if (!updaterWindowController) {
        updaterWindowController = [[MJAutoUpdaterWindowController alloc] init];
        closedObserver = [[NSNotificationCenter defaultCenter]
                          addObserverForName:NSWindowWillCloseNotification
                          object:[updaterWindowController window]
                          queue:[NSOperationQueue mainQueue]
                          usingBlock:^(NSNotification *note) {
                              updaterWindowController = nil;
                              
                              [[NSNotificationCenter defaultCenter]
                               removeObserver:closedObserver];
                              closedObserver = nil;
                          }];
    }
    
    return updaterWindowController;
}

void MJUpdateCheckerCheckSilently(void) {
    if (!MJUpdateCheckerEnabled())
        return;
    
    [MJUpdate checkForUpdate:^(MJUpdate *update, NSError* connError) {
        if (update) {
            MJAutoUpdaterWindowController* wc = definitelyRealWindowController();
            wc.update = update;
            
            [[MJUserNotificationManager sharedManager] sendNotification:@"Mjolnir update available" handler:^{
                [wc showFoundPage];
            }];
        }
    }];
}

BOOL MJUpdateCheckerEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:MJCheckForUpdatesKey];
}

void MJUpdateCheckerSetEnabled(BOOL checkingEnabled) {
    [[NSUserDefaults standardUserDefaults] setBool:checkingEnabled
                                            forKey:MJCheckForUpdatesKey];
    reflect_defaults();
}

void MJUpdateCheckerCheckVerbosely(void) {
    MJAutoUpdaterWindowController* wc = definitelyRealWindowController();
    
    [wc showCheckingPage];
    
    [MJUpdate checkForUpdate:^(MJUpdate *update, NSError* connError) {
        if (!updaterWindowController)
            return;
        
        if (update) {
            wc.update = update;
            [wc showFoundPage];
        }
        else if (connError) {
            wc.error = [connError localizedDescription];
            [wc showErrorPage];
        }
        else {
            [wc showUpToDatePage];
        }
    }];
}
