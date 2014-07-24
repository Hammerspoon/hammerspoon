#import "HydraLicenseRequester.h"

#define HYDRA_STORE_LINK @"http://sdegutis.github.io/hydra/"

@interface HydraLicenseRequester ()
@property NSString* email;
@property NSString* license;
@property NSString* error;
@end

@implementation HydraLicenseRequester

- (NSString*) windowNibName {
    return @"HydraLicenseRequester";
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // ...
}

- (void) request {
    return; // uncomment during commits, until its done.
    
    [[NSApplication sharedApplication] setActivationPolicy:NSApplicationActivationPolicyRegular]; // so we can cmd-tab to it
    
    if (![[self window] isVisible]) {
        [[self window] center];
    }
    [[self window] orderFrontRegardless];
    
    
    
}

- (IBAction) acquire:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:HYDRA_STORE_LINK]];
}

static NSString* normalize(NSString* s) {
    return [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (IBAction) validate:(id)sender {
    self.email = normalize(self.email);
    self.license = normalize(self.license);
    
    BOOL valid = [self.delegate tryingLicense:self.license forEmail:self.email];
    if (valid) {
        // TODO: show an alert as a drop-down panel on this window saying thanks. then close the window.
    }
    else {
        self.error = @"Invalid. Try again.";
    }
}

- (BOOL) enteredBothFields {
    self.error = nil;
    return [normalize(self.email) length] > 0 && [normalize(self.license) length] > 0;
}

+ (NSSet*) keyPathsForValuesAffectingEnteredBothFields {
    return [NSSet setWithArray:@[@"email", @"license"]];
}

@end

@interface SDLineView : NSView
@end

@implementation SDLineView

- (void) drawRect:(NSRect)dirtyRect {
    NSRect top, bottom;
    NSDivideRect([self bounds], &top, &bottom, 1.0, NSMaxYEdge);
    
    [[NSColor lightGrayColor] setFill];
    [NSBezierPath fillRect:top];
    
    [[NSColor whiteColor] setFill];
    [NSBezierPath fillRect:bottom];
}

@end
