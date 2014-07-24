#import "HydraLicenseRequester.h"

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
    return; // leave commented during commits until its done.
    
    if (![[self window] isVisible]) {
        [[self window] center];
    }
    [[self window] orderFrontRegardless];
    
    
    
}

- (IBAction) validate:(id)sender {
    BOOL valid = [self.delegate tryingLicense:self.license forEmail:self.email];
    if (valid) {
        NSLog(@"woot");
    }
    else {
        self.error = @"nope try again";
    }
}

- (BOOL) enteredBothFields {
    self.error = nil;
    return [self.email length] > 0 && [self.license length] > 0;
}

+ (NSSet*) keyPathsForValuesAffectingEnteredBothFields {
    return [NSSet setWithArray:@[@"email", @"license"]];
}

@end
