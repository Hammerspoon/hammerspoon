#import "MJPreferencesWindowController.h"
#import "MJAutoLaunch.h"
#import "MJLua.h"
#import "MJDockIcon.h"
#import "MJMenuIcon.h"
#import "MJAccessibilityUtils.h"
#import "MJConsoleWindowController.h"
#import "variables.h"
#import "secrets.h"

//
// Enable & Disable Preferences Dark Mode:
//
BOOL PreferencesDarkModeEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:HSPreferencesDarkModeKey];
}

void PreferencesDarkModeSetEnabled(BOOL enabled) {
    [[NSUserDefaults standardUserDefaults] setBool:enabled
                                            forKey:HSPreferencesDarkModeKey];
}


#define MJSkipDockMenuIconProblemAlertKey @"MJSkipDockMenuIconProblemAlertKey"

@interface MJPreferencesWindowController ()

@property (weak) IBOutlet NSButton* openAtLoginCheckbox;
@property (weak) IBOutlet NSButton* showDockIconCheckbox;
@property (weak) IBOutlet NSButton* showMenuIconCheckbox;
@property (weak) IBOutlet NSButton* keepConsoleOnTopCheckbox;
@property (weak) IBOutlet NSButton* uploadCrashDataCheckbox;
@property (weak) IBOutlet NSButton* updatesCheckbox;

@property BOOL isAccessibilityEnabled;

@end

@implementation MJPreferencesWindowController

+ (instancetype) singleton {
    static MJPreferencesWindowController* s;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s = [[MJPreferencesWindowController alloc] init];
    });
    return s;
}

- (void) setup {
    [self reflectDefaults];
}

- (void) reflectDefaults {
    
    //
    // Dark Mode:
    //
    if (PreferencesDarkModeEnabled()) {
        self.window.appearance = [NSAppearance appearanceNamed: NSAppearanceNameVibrantDark] ;
        self.window.titlebarAppearsTransparent = YES ;
    } else {
        self.window.appearance = [NSAppearance appearanceNamed: NSAppearanceNameVibrantLight] ;
        self.window.titlebarAppearsTransparent = NO ;
    }
    
}

- (void)updateFeedbackDisplay:(NSNotification __unused *)notification {
    [self.openAtLoginCheckbox setState:MJAutoLaunchGet() ? NSOnState : NSOffState];
    [self.showDockIconCheckbox setState: MJDockIconVisible() ? NSOnState : NSOffState];
    [self.showMenuIconCheckbox setState: MJMenuIconVisible() ? NSOnState : NSOffState];
    [self.keepConsoleOnTopCheckbox setState: MJConsoleWindowAlwaysOnTop() ? NSOnState : NSOffState];
    [self.uploadCrashDataCheckbox setState: HSUploadCrashData() ? NSOnState : NSOffState];
#ifndef SENTRY_API_URL
    [self.uploadCrashDataCheckbox setState:NSOffState];
    [self.uploadCrashDataCheckbox setEnabled:NO];
#endif

}

- (void) showWindow:(id)sender {
    if (![[self window] isVisible])
        [[self window] center];
    [super showWindow: sender];
    [self reflectDefaults];
}

- (NSString*) windowNibName {
    return @"PreferencesWindow";
}

- (void)windowDidLoad {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self cacheIsAccessibilityEnabled];
    });

    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(accessibilityChanged:) name:@"com.apple.accessibility.api" object:nil];

    [self.openAtLoginCheckbox setState:MJAutoLaunchGet() ? NSOnState : NSOffState];
    [self.showDockIconCheckbox setState: MJDockIconVisible() ? NSOnState : NSOffState];
    [self.showMenuIconCheckbox setState: MJMenuIconVisible() ? NSOnState : NSOffState];
    [self.keepConsoleOnTopCheckbox setState: MJConsoleWindowAlwaysOnTop() ? NSOnState : NSOffState];
    [self.uploadCrashDataCheckbox setState: HSUploadCrashData() ? NSOnState : NSOffState];

    if (NSClassFromString(@"SUUpdater")) {
        NSString *frameworkPath = [[[NSBundle bundleForClass:[self class]] privateFrameworksPath] stringByAppendingPathComponent:@"Sparkle.framework"];
        if ([[NSBundle bundleWithPath:frameworkPath] load]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
            id updater = [NSClassFromString(@"SUUpdater") performSelector:@selector(sharedUpdater)];
#pragma clang diagnostic pop
            [self.updatesCheckbox bind:@"value" toObject:updater withKeyPath:@"automaticallyChecksForUpdates" options:nil];
        } else {
            NSLog(@"Could not load %@ while trying to construct SUUpdater!", frameworkPath);
        }
    } else {
        NSLog(@"SUUpdater doesn't exist, disabling updates checkbox in Preferences");
        [self.updatesCheckbox setState:NSOffState];
        [self.updatesCheckbox setEnabled:NO];
    }

#ifndef SENTRY_API_URL
    [self.uploadCrashDataCheckbox setState:NSOffState];
    [self.uploadCrashDataCheckbox setEnabled:NO];
#endif

    NSNotificationCenter *changeWatcher = [NSNotificationCenter defaultCenter];
    [changeWatcher addObserver:self
                      selector:@selector(updateFeedbackDisplay:)
                          name:NSUserDefaultsDidChangeNotification
                        object:nil];

}

- (void) accessibilityChanged:(NSNotification*)note {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self cacheIsAccessibilityEnabled];
    });
}

- (void) cacheIsAccessibilityEnabled {
    self.isAccessibilityEnabled = MJAccessibilityIsEnabled();
}

- (NSString*) maybeEnableAccessibilityString {
    if (self.isAccessibilityEnabled)
        return @"Accessibility is enabled. You're all set!";
    else
        return @"WARNING! Accessibility is not enabled!";
}

- (NSImage*) isAccessibilityEnabledImage {
    if (self.isAccessibilityEnabled)
        return [NSImage imageNamed:NSImageNameStatusAvailable];
    else
        return [NSImage imageNamed:NSImageNameStatusUnavailable];
}

+ (NSSet*) keyPathsForValuesAffectingMaybeEnableAccessibilityString {
    return [NSSet setWithArray:@[@"isAccessibilityEnabled"]];
}

+ (NSSet*) keyPathsForValuesAffectingIsAccessibilityEnabledImage {
    return [NSSet setWithArray:@[@"isAccessibilityEnabled"]];
}

- (IBAction) openAccessibility:(id)sender {
    MJAccessibilityOpenPanel();
}

- (IBAction) toggleOpensAtLogin:(NSButton*)sender {
    BOOL enabled = [sender state] == NSOnState;
    MJAutoLaunchSet(enabled);
}

- (IBAction) toggleShowDockIcon:(NSButton*)sender {
    [[self class] cancelPreviousPerformRequestsWithTarget:self selector:@selector(actuallyToggleShowDockIcon) object:nil];
    [self performSelector:@selector(actuallyToggleShowDockIcon) withObject:nil afterDelay:0.3];
}

- (void) actuallyToggleShowDockIcon {
    BOOL enabled = [self.showDockIconCheckbox state] == NSOnState;
    MJDockIconSetVisible(enabled);
    [self maybeWarnAboutDockMenuProblem];
}

- (IBAction) toggleMenuDockIcon:(NSButton*)sender {
    BOOL enabled = [sender state] == NSOnState;
    MJMenuIconSetVisible(enabled);
    [self maybeWarnAboutDockMenuProblem];
}

- (IBAction) toggleKeepConsoleOnTop:(id)sender {
    MJConsoleWindowSetAlwaysOnTop([sender state] == NSOnState);
}

- (IBAction) toggleUploadCrashData:(id)sender {
    HSSetUploadCrashData([sender state] == NSOnState);
}

- (IBAction) privacyPolicyClicked:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.hammerspoon.org/privacy"]];
}

- (void) dockMenuProblemAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    BOOL skipNextTime = ([[alert suppressionButton] state] == NSOnState);
    [[NSUserDefaults standardUserDefaults] setBool:skipNextTime forKey:MJSkipDockMenuIconProblemAlertKey];
}

- (void) maybeWarnAboutDockMenuProblem {
    if (MJMenuIconVisible() || MJDockIconVisible())
        return;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:MJSkipDockMenuIconProblemAlertKey])
        return;

    NSAlert* alert = [[NSAlert alloc] init];
    [alert setAlertStyle:NSAlertStyleWarning];
    [alert setMessageText:@"How to get back to this window"];
    [alert setInformativeText:@"When both the dock icon and menu icon are disabled, you can get back to this Preferences window by activating Hammerspoon from Spotlight or by running `open -a Hammerspoon` from Terminal, and then pressing Command + Comma."];
    [alert setShowsSuppressionButton:YES];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [alert beginSheetModalForWindow:[self window]
                      modalDelegate:self
                     didEndSelector:@selector(dockMenuProblemAlertDidEnd:returnCode:contextInfo:)
                        contextInfo:NULL];
#pragma clang diagnostic pop
}

@end


BOOL HSUploadCrashData(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey: HSUploadCrashDataKey];
}

void HSSetUploadCrashData(BOOL uploadCrashData) {
    [[NSUserDefaults standardUserDefaults] setBool:uploadCrashData forKey:HSUploadCrashDataKey];
}
