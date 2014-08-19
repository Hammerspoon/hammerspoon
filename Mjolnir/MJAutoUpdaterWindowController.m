#import "MJAutoUpdaterWindowController.h"

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

- (void)windowDidLoad {
    [super windowDidLoad];
    
    self.oldVersion = [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"];
    [self.progressBar startAnimation:self];
    
    NSString* s = @"View Release Notes";
    NSRange r = NSMakeRange(0, [s length]);
    self.textView = [[NSTextView alloc] initWithFrame:[self.textViewContainer bounds]];
    [self.textView setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
    [self.textView insertText:s];
    [self.textView setDrawsBackground:NO];
    [self.textView setEditable:NO];
    [[self.textView textContainer] setLineFragmentPadding:2.0];
    [[self.textView textStorage] addAttribute:NSLinkAttributeName value:self.releaseNotesAddress range:r];
    [self.textViewContainer addSubview:self.textView];
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
    [self close];
    [self.delegate userDismissedAutoUpdaterWindow];
    [self.delegate userWantsInstallAtQuit];
}

- (void) showWindow {
    NSDisableScreenUpdates();
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
