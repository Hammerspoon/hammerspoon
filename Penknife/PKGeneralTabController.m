BOOL PKAutoLaunchGet(void);
void PKAutoLaunchSet(BOOL opensAtLogin);

extern Boolean AXIsProcessTrustedWithOptions(CFDictionaryRef options) __attribute__((weak_import));
extern CFStringRef kAXTrustedCheckOptionPrompt __attribute__((weak_import));

@interface PKGeneralTabController : NSObject

@property (weak) IBOutlet NSButton* openAtLoginCheckbox;
@property (weak) IBOutlet NSButton* showDockIconCheckbox;
@property (weak) IBOutlet NSButton* checkForUpdatesCheckbox;

@end

#define PKCheckForUpdatesKey @"_checkforupdates"

@implementation PKGeneralTabController

- (IBAction) openSampleConfig:(id)sender {
    NSURL* url = [[NSBundle mainBundle] URLForResource:@"sample_init" withExtension:@"lua"];
    [[NSWorkspace sharedWorkspace] openURL:url];
}

- (void) hello:(NSNotification*)note {
    NSLog(@"%@", note);
}

- (void) awakeFromNib {
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(hello:) name:nil object:nil];
    // name="com.apple.accessibility.api" seems to happen if you change an app's accessibility!
    
    
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

//- (void) thing {
//    BOOL shouldprompt = lua_toboolean(L, 1);
//    BOOL enabled;
//    
//    if (AXIsProcessTrustedWithOptions != NULL) {
//        NSDictionary* opts = @{(__bridge id)kAXTrustedCheckOptionPrompt: @(shouldprompt)};
//        enabled = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)opts);
//    }
//    else {
//        enabled = AXAPIEnabled();
//        
//        if (shouldprompt) {
//            NSString* src = @"tell application \"System Preferences\"\nactivate\nset current pane to pane \"com.apple.preference.universalaccess\"\nend tell";
//            NSAppleScript *a = [[NSAppleScript alloc] initWithSource:src];
//            [a executeAndReturnError:nil];
//        }
//    }
//    
//    lua_pushboolean(L, enabled);
//    return 1;
//}

@end
