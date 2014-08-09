#import "MJUpdaterWindowController.h"

static NSString* MJReleaseNotesURL = @"https://github.com/mjolnir-io/mjolnir/blob/master/CHANGES.md";

@interface MJUpdaterWindowController ()
@property (weak) IBOutlet NSProgressIndicator* spinner;
@property NSString* error;
@end

@implementation MJUpdaterWindowController

- (NSString*) windowNibName {
    return @"UpdaterWindow";
}

- (void) showWindow:(id)sender {
    if (![[self window] isVisible]) [[self window] center];
    [super showWindow:sender];
}

- (IBAction) install:(id)sender {
    [self.spinner startAnimation:self];
    [self.updater install:^(NSString *error, NSString *reason) {
        self.error = [NSString stringWithFormat:@"%@ (%@)", error, reason];
        [self.spinner stopAnimation:self];
    }];
}

- (IBAction) remind:(id)sender {
    [self close];
}

- (IBAction) showChanges:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:MJReleaseNotesURL]];
}

@end
