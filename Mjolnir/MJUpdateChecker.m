#import "MJUpdateChecker.h"
#import "MJAutoUpdaterWindowController.h"
#import "MJUserNotificationManager.h"
#import "MJUpdate.h"
#import "variables.h"

@interface MJUpdateChecker () <MJAutoUpdaterWindowControllerDelegate>
@property NSTimer* autoupdateTimer;
@property MJAutoUpdaterWindowController* updaterWindowController;
@end

@implementation MJUpdateChecker

+ (MJUpdateChecker*) sharedChecker {
    static MJUpdateChecker* sharedChecker;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedChecker = [[MJUpdateChecker alloc] init];
    });
    return sharedChecker;
}

- (void) setup {
    [self setupTimer];
}

- (void) setupTimer {
    self.autoupdateTimer = [NSTimer scheduledTimerWithTimeInterval:MJCheckForUpdatesInterval
                                                            target:self
                                                          selector:@selector(checkForUpdatesTimerFired:)
                                                          userInfo:nil
                                                           repeats:YES];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(MJCheckForUpdatesDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self checkForUpdatesInBackground];
    });
}

- (MJAutoUpdaterWindowController*) definitelyRealWindowController {
    if (!self.updaterWindowController) {
        self.updaterWindowController = [[MJAutoUpdaterWindowController alloc] init];
        self.updaterWindowController.delegate = self;
    }
    
    return self.updaterWindowController;
}

- (IBAction) checkForUpdates:(id)sender {
    MJAutoUpdaterWindowController* wc = [self definitelyRealWindowController];
    
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

- (void) userDismissedAutoUpdaterWindow {
    self.updaterWindowController = nil;
}

- (void) checkForUpdatesInBackground {
    if (!self.checkingEnabled)
        return;
    
    [MJUpdate checkForUpdate:^(MJUpdate *update, NSError* connError) {
        if (update) {
            MJAutoUpdaterWindowController* wc = [self definitelyRealWindowController];
            wc.update = update;
            
            [[MJUserNotificationManager sharedManager] sendNotification:@"Mjolnir update available" handler:^{
                [wc showFoundPage];
            }];
        }
    }];
}

- (void) checkForUpdatesTimerFired:(NSTimer*)timer {
    [self checkForUpdatesInBackground];
}

- (BOOL) checkingEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:MJCheckForUpdatesKey];
}

- (void) setCheckingEnabled:(BOOL)checkingEnabled {
    [[NSUserDefaults standardUserDefaults] setBool:checkingEnabled
                                            forKey:MJCheckForUpdatesKey];
}

@end
