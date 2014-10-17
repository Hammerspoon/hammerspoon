#import "MJPreferencesWindowController.h"
#import "MJAutoLaunch.h"
#import "MJLua.h"
#import "MJDockIcon.h"
#import "MJMenuIcon.h"
#import "MJAccessibilityUtils.h"
#import "MJConsoleWindowController.h"
#import "variables.h"

#define MJSkipDockMenuIconProblemAlertKey @"MJSkipDockMenuIconProblemAlertKey"

@interface MJPreferencesWindowController ()

@property (weak) IBOutlet NSButton* openAtLoginCheckbox;
@property (weak) IBOutlet NSButton* showDockIconCheckbox;
@property (weak) IBOutlet NSButton* showMenuIconCheckbox;
@property (weak) IBOutlet NSButton* keepConsoleOnTopCheckbox;

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

- (void) showWindow:(id)sender {
    if (![[self window] isVisible])
        [[self window] center];
    [super showWindow: sender];
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
        return [NSImage imageNamed:NSImageNameStatusPartiallyAvailable];
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
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert setMessageText:@"How to get back to this window"];
    [alert setInformativeText:@"When both the dock icon and menu icon are disabled, you can get back to this Preferences window by activating Hammerspoon from Spotlight or by running `open -a Hammerspoon` from Terminal, and then pressing Command + Comma."];
    [alert setShowsSuppressionButton:YES];
    [alert beginSheetModalForWindow:[self window]
                      modalDelegate:self
                     didEndSelector:@selector(dockMenuProblemAlertDidEnd:returnCode:contextInfo:)
                        contextInfo:NULL];
}

@end
