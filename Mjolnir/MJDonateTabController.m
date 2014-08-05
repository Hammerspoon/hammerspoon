#import "MJDonateTabController.h"

#define MJPayPalDonationURL @"https://www.paypal.com/cgi-bin/webscr?business=sbdegutis@gmail.com&cmd=_donations&item_name=Mjolnir.app%20donation&no_shipping=1"
#define MJCreditCardDonationURL @"https://sites.fastspring.com/sdegutis/instant/hydra"

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
