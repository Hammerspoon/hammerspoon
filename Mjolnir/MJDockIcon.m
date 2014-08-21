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
    dispatch_async(dispatch_get_main_queue(), ^{
        [app unhide: nil];
        [app activateIgnoringOtherApps:YES];
        NSEnableScreenUpdates();
    });
}
