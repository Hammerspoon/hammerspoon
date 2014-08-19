#import "MJDonateTabController.h"
#import "variables.h"

@interface MJDonateTabController ()
@end

@implementation MJDonateTabController

@synthesize initialFirstResponder;
- (NSString*) nibName { return @"DonateTab"; }
- (NSString*) title   { return @"Donate"; }
- (NSImage*)  icon    { return [NSImage imageNamed:@"Donate"]; }

- (IBAction) donateWithPayPal:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:MJPayPalDonationURL]];
}

- (IBAction) donateWithCreditCard:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:MJCreditCardDonationURL]];
}

@end
