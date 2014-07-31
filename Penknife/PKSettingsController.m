BOOL PKAutoLaunchGet(void);
void PKAutoLaunchSet(BOOL opensAtLogin);

@interface PKSettingsController : NSObject

@property (weak) IBOutlet NSButton* openAtLoginCheckbox;
@property (weak) IBOutlet NSButton* showDockIconCheckbox;
@property (weak) IBOutlet NSButton* checkForUpdatesCheckbox;

@end

#define PKCheckForUpdatesKey @"_checkforudpates"

@implementation PKSettingsController

- (IBAction) openSampleConfig:(id)sender {
    NSURL* url = [[NSBundle mainBundle] URLForResource:@"sample_init" withExtension:@"lua"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void) awakeFromNib {
    [self.openAtLoginCheckbox setState:PKAutoLaunchGet() ? NSOnState : NSOffState];
    [self.showDockIconCheckbox setState:[[NSApplication sharedApplication] activationPolicy] == NSApplicationActivationPolicyRegular ? NSOnState : NSOffState];
    [self.checkForUpdatesCheckbox setState:[[NSUserDefaults standardUserDefaults] boolForKey:PKCheckForUpdatesKey] ? NSOnState : NSOffState];
}

- (IBAction) toggleOpensAtLogin:(NSButton*)sender {
    PKAutoLaunchSet([sender state] == NSOnState);
}

- (IBAction) toggleShowDockIcon:(NSButton*)sender {
    NSDisableScreenUpdates();
    
    [[NSApplication sharedApplication] setActivationPolicy:[sender state] == NSOnState ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSApplication sharedApplication] unhide:self];
        [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];
        
        NSEnableScreenUpdates();
    });
}

- (IBAction) toggleCheckForUpdates:(NSButton*)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[sender state] == NSOnState forKey:PKCheckForUpdatesKey];
}

@end
