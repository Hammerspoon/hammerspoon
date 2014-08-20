#import "MJDockIcon.h"
#import "variables.h"

@implementation MJDockIcon

+ (MJDockIcon*) sharedDockIcon {
    static MJDockIcon* sharedDockIcon;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedDockIcon = [[MJDockIcon alloc] init];
    });
    return sharedDockIcon;
}

- (BOOL) visible {
    return [[NSUserDefaults standardUserDefaults] boolForKey:MJShowDockIconKey];
}

- (void) setVisible:(BOOL)visible {
    [[NSUserDefaults standardUserDefaults] setBool:visible
                                            forKey:MJShowDockIconKey];
    [self reflectDefaults];
}

- (void) setup {
    [self reflectDefaults];
}

- (void) reflectDefaults {
    NSApplication* app = [NSApplication sharedApplication]; // NSApp is typed to 'id'; lame
    NSDisableScreenUpdates();
    [app setActivationPolicy: self.visible ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory];
    dispatch_async(dispatch_get_main_queue(), ^{
        [app unhide:self];
        [app activateIgnoringOtherApps:YES];
        NSEnableScreenUpdates();
    });
}

@end
