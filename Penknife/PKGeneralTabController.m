BOOL PKAutoLaunchGet(void);
void PKAutoLaunchSet(BOOL opensAtLogin);

extern Boolean AXIsProcessTrustedWithOptions(CFDictionaryRef options) __attribute__((weak_import));
extern CFStringRef kAXTrustedCheckOptionPrompt __attribute__((weak_import));

@interface PKGeneralTabController : NSObject

@property (weak) IBOutlet NSButton* openAtLoginCheckbox;
@property (weak) IBOutlet NSButton* showDockIconCheckbox;
@property (weak) IBOutlet NSButton* checkForUpdatesCheckbox;

@property BOOL isAccessibilityEnabled;

@end

#define PKCheckForUpdatesKey @"_checkforupdates"

@implementation PKGeneralTabController

- (IBAction) openSampleConfig:(id)sender {
    NSURL* url = [[NSBundle mainBundle] URLForResource:@"sample_init" withExtension:@"lua"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void) accessibilityChanged:(NSNotification*)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self cacheIsAccessibilityEnabled];
    });
}

- (void) cacheIsAccessibilityEnabled {
    if (AXIsProcessTrustedWithOptions != NULL)
        self.isAccessibilityEnabled = AXIsProcessTrustedWithOptions(NULL);
    else
        self.isAccessibilityEnabled = AXAPIEnabled();
}

- (NSString*) maybeEnableAccessibilityString {
    if (self.isAccessibilityEnabled)
        return @"Accessibility is enabled, you're all set!";
    else
        return @"Enable Accessibility for best results.";
}

+ (NSSet*) keyPathsForValuesAffectingMaybeEnableAccessibilityString {
    return [NSSet setWithArray:@[@"isAccessibilityEnabled"]];
}

- (IBAction) openAccessibility:(id)sender {
    if (AXIsProcessTrustedWithOptions != NULL) {
        AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge id)kAXTrustedCheckOptionPrompt: @YES});
    }
    else {
        static NSString* script = @"tell application \"System Preferences\"\nactivate\nset current pane to pane \"com.apple.preference.universalaccess\"\nend tell";
        [[[NSAppleScript alloc] initWithSource:script] executeAndReturnError:nil];
    }
}

- (void) awakeFromNib {
    [self cacheIsAccessibilityEnabled];
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(accessibilityChanged:) name:@"com.apple.accessibility.api" object:nil];
    
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

- (IBAction) reloadConfig:(id)sender {
    // TODO
}

@end
