#import "MJAutoUpdaterWindowController.h"

static NSString* MJReleaseNotesURL = @"https://github.com/mjolnir-io/mjolnir/blob/master/CHANGES.md";

@interface MJAutoUpdaterWindowController ()

@property (weak) IBOutlet NSTabView* tabView;
@property (weak) IBOutlet NSProgressIndicator* progressBar;
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
    [self.progressBar startAnimation:self];
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

- (IBAction) upgradeOnQuit:(id)sender {
//    [self.spinner startAnimation:self];
    [self.update install:^(NSString *error, NSString *reason) {
//        self.error = [NSString stringWithFormat:@"%@ (%@)", error, reason];
//        [self.spinner stopAnimation:self];
    }];
}

- (void) showWindow {
    NSDisableScreenUpdates();
    if (![[self window] isVisible])
        [[self window] center];
    [[self window] orderFront:self];
    NSEnableScreenUpdates();
}

- (void) showCheckingPage {
    [self.tabView selectTabViewItemAtIndex:0];
}

- (void) showUpToDatePage {
    [self.tabView selectTabViewItemAtIndex:1];
}

- (void) showFoundPage {
    [self.tabView selectTabViewItemAtIndex:2];
}

- (void) showErrorPage {
    [self.tabView selectTabViewItemAtIndex:3];
}

@end
