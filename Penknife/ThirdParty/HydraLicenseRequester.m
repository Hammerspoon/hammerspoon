#import "HydraLicenseRequester.h"

#define HYDRA_STORE_LINK @"https://sites.fastspring.com/sdegutis/instant/hydra"

@interface HydraLicenseRequester ()
@property NSString* email;
@property NSString* license;
@property NSString* error;
@property NSApplicationActivationPolicy previousPolicy;
@end

@implementation HydraLicenseRequester

- (NSString*) windowNibName {
    return @"HydraLicenseRequester";
}

- (void) request {
    if (![[self window] isVisible]) {
        self.previousPolicy = [[NSApplication sharedApplication] activationPolicy];
        [[self window] center];
    }
    
    // so the user can cmd-tab to this window
    [[NSApplication sharedApplication] setActivationPolicy:NSApplicationActivationPolicyRegular];
    
    [[self window] orderFrontRegardless];
}

- (void) windowWillClose:(NSNotification *)notification {
    [[NSApplication sharedApplication] setActivationPolicy:self.previousPolicy];
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
    
    if ([self.delegate tryLicense:self.license forEmail:self.email]) {
        NSAlert* alert = [[NSAlert alloc] init];
        alert.icon = [NSImage imageNamed:@"thumbsup.png"];
        alert.messageText = @"Your licensed verified successfully.";
        alert.informativeText = @"Thank you for your support! I hope you have a lot of fun using Hydra to do really cool things.";
        [alert beginSheetModalForWindow:[self window]
                      completionHandler:^(NSModalResponse returnCode) {
                          [[self window] close];
                          [self.delegate closed];
                      }];
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
