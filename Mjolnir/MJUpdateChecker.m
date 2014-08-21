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

void MJUpdateCheckerSetup(void) {
    autoupdateTimer = CFRunLoopTimerCreate(NULL, 0, MJCheckForUpdatesInterval, 0, 0, &callback, NULL);
    CFRunLoopTimerSetNextFireDate(autoupdateTimer, CFAbsoluteTimeGetCurrent() + MJCheckForUpdatesDelay);
    CFRunLoopAddTimer(CFRunLoopGetMain(), autoupdateTimer, kCFRunLoopCommonModes);
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
}

void MJUpdateCheckerCheckVerbosely(void) {
    MJAutoUpdaterWindowController* wc = definitelyRealWindowController();
    
    [wc showCheckingPage];
    
    [MJUpdate checkForUpdate:^(MJUpdate *update, NSError* connError) {
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
