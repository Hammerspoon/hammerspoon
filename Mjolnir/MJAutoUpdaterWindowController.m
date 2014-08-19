#import "MJAutoUpdaterWindowController.h"

static NSString* MJReleaseNotesURL = @"https://github.com/mjolnir-io/mjolnir/blob/master/CHANGES.md";
static NSString* MJDownloadPage = @"https://github.com/mjolnir-io/mjolnir/releases/latest";

@interface MJAutoUpdaterWindowController ()

@property (weak) IBOutlet NSTabView* tabView;
@property (weak) IBOutlet NSProgressIndicator* checkingProgressBar;
@property (weak) IBOutlet NSProgressIndicator* installationProgressBar;
@property IBOutlet NSView* textViewContainer;
@property NSTextView* textView;

@end

@implementation MJAutoUpdaterWindowController

- (NSString*) windowNibName {
    return @"AutoUpdaterWindow";
}

- (void) showReleaseNotesLink {
    NSString* s = @"View Release Notes";
    NSRange r = NSMakeRange(0, [s length]);
    self.textView = [[NSTextView alloc] initWithFrame:[self.textViewContainer bounds]];
    [self.textView setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
    [self.textView insertText:s];
    [self.textView setDrawsBackground:NO];
    [self.textView setEditable:NO];
    [[self.textView textContainer] setLineFragmentPadding:2.0];
    [[self.textView textStorage] addAttribute:NSLinkAttributeName value:[NSURL URLWithString:MJReleaseNotesURL] range:r];
    [self.textViewContainer addSubview:self.textView];
}

- (void) windowDidLoad {
    [super windowDidLoad];
    [self.checkingProgressBar startAnimation:self];
    [self.installationProgressBar startAnimation:self];
    [self showReleaseNotesLink];
}

- (IBAction) dismiss:(id)sender {
    [self close];
    [self.delegate userDismissedAutoUpdaterWindow];
}

- (IBAction) cancel:(id)sender {
    [self close];
    [self.delegate userDismissedAutoUpdaterWindow];
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
}

- (void) showWindow {
    NSDisableScreenUpdates();
    if (![[self window] isVisible])
        [[self window] center];
    [[self window] makeKeyAndOrderFront: self];
    NSEnableScreenUpdates();
}

- (void) showCheckingPage {
    self.error = nil;
    [self showWindow];
    [self.tabView selectTabViewItemAtIndex:0];
}

- (void) showUpToDatePage {
    self.error = nil;
    [self showWindow];
    [self.tabView selectTabViewItemAtIndex:1];
}

- (void) showFoundPage {
    self.error = nil;
    [self showWindow];
    [self.tabView selectTabViewItemAtIndex:2];
}

- (void) showErrorPage {
    [self showWindow];
    [self.tabView selectTabViewItemAtIndex:3];
}

- (void) showInstallingPage {
    [self showWindow];
    [self.tabView selectTabViewItemAtIndex:4];
}

@end
