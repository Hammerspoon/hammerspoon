#import "MJAutoUpdaterWindowController.h"
#import "variables.h"

@interface MJAutoUpdaterWindowController ()

@property (weak) IBOutlet NSTabView* tabView;
@property (weak) IBOutlet NSProgressIndicator* checkingProgressBar;
@property (weak) IBOutlet NSProgressIndicator* installationProgressBar;
@property (weak) IBOutlet NSButton* showChangeLogButton;

@end

@implementation MJAutoUpdaterWindowController

- (NSString*) windowNibName {
    return @"AutoUpdaterWindow";
}

- (IBAction) showReleaseNotes:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:MJReleaseNotesURL]];
}

- (void) windowDidLoad {
    [super windowDidLoad];
    [self.checkingProgressBar startAnimation:self];
    [self.installationProgressBar startAnimation:self];
    [self makeFakeLink];
}

- (void) makeFakeLink {
    NSRange r = NSMakeRange(0, [[self.showChangeLogButton title] length]);
    NSMutableAttributedString* title = [[self.showChangeLogButton attributedTitle] mutableCopy];
    [title addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range: r];
    [title addAttribute:NSUnderlineStyleAttributeName value:@1 range: r];
    [self.showChangeLogButton setAttributedTitle:title];
}

- (IBAction) dismiss:(id)sender {
    [self close];
}

- (IBAction) cancel:(id)sender {
    [self close];
}

- (IBAction) install:(id)sender {
    [self showInstallingPage];
    [self.update install:^(NSString *error, NSString *reason) {
        self.error = [NSString stringWithFormat:@"%@ (%@)", error, reason];
        [self showErrorPage];
    }];
}

- (IBAction) visitDownloadPage:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:MJDownloadPage]];
    [self close];
}

- (void) showTab:(int)n {
    NSDisableScreenUpdates();
    if (![[self window] isVisible])
        [[self window] center];
    [[self window] makeKeyAndOrderFront: self];
    [self.tabView selectTabViewItemAtIndex:n];
    NSEnableScreenUpdates();
}

- (void) showCheckingPage {
    self.error = nil;
    [self showTab: 0];
}

- (void) showUpToDatePage {
    self.error = nil;
    [self showTab: 1];
}

- (void) showFoundPage {
    self.error = nil;
    [self showTab: 2];
}

- (void) showErrorPage {
    [self showTab: 3];
}

- (void) showInstallingPage {
    self.error = nil;
    [self showTab: 4];
}

@end

@interface MJLinkButton : NSButton
@end

@implementation MJLinkButton

- (void)resetCursorRects {
    [self addCursorRect:[self bounds]
                 cursor:[NSCursor pointingHandCursor]];
}

@end
