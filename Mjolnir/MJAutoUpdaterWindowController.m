#import "MJAutoUpdaterWindowController.h"
#import "MJLinkTextField.h"
#import "variables.h"

@interface MJAutoUpdaterWindowController ()

@property (weak) IBOutlet NSTabView* tabView;
@property (weak) IBOutlet NSProgressIndicator* checkingProgressBar;
@property (weak) IBOutlet NSProgressIndicator* installationProgressBar;
@property (weak) IBOutlet MJLinkTextField* releaseNotesLabel;

@end

@implementation MJAutoUpdaterWindowController

- (NSString*) windowNibName {
    return @"AutoUpdaterWindow";
}

- (void) showReleaseNotesLink {
    [self.releaseNotesLabel addLink:MJReleaseNotesURL
                            inRange:NSMakeRange(0, [[self.releaseNotesLabel stringValue] length])];
}

- (void) windowDidLoad {
    [super windowDidLoad];
    [self.checkingProgressBar startAnimation:self];
    [self.installationProgressBar startAnimation:self];
    [self showReleaseNotesLink];
}

- (void) dismiss {
    [self close];
    [self.delegate userDismissedAutoUpdaterWindow];
}

- (IBAction) dismiss:(id)sender {
    [self dismiss];
}

- (IBAction) cancel:(id)sender {
    [self dismiss];
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
    [self dismiss];
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
