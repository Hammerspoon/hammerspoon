#import "MJDockIcon.h"
#import "variables.h"

static void reflect_defaults(void);

void MJDockIconSetup(void) {
    reflect_defaults();
}

BOOL MJDockIconVisible(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:MJShowDockIconKey];
}

void MJDockIconSetVisible(BOOL visible) {
    [[NSUserDefaults standardUserDefaults] setBool:visible
                                            forKey:MJShowDockIconKey];
    reflect_defaults();
}

static void reflect_defaults(void) {
    NSApplication* app = [NSApplication sharedApplication]; // NSApp is typed to 'id'; lame
    NSDisableScreenUpdates();
    [app setActivationPolicy: MJDockIconVisible() ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [app unhide: nil];
        [app activateIgnoringOtherApps:YES];
        NSEnableScreenUpdates();
    });
}

//
// Open Console on Dock Icon Click:
//
BOOL HSOpenConsoleOnDockClickEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:HSOpenConsoleOnDockClickKey];
}

void HSOpenConsoleOnDockClickSetEnabled(BOOL enabled) {
    [[NSUserDefaults standardUserDefaults] setBool:enabled
                                            forKey:HSOpenConsoleOnDockClickKey];
}
