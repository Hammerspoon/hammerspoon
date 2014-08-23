#import "MJDonateTabController.h"
#import "MJLinkTextField.h"
#import "variables.h"

@interface MJDonateTabController ()
@property (weak) IBOutlet MJLinkTextField* label;
@end

@implementation MJDonateTabController

@synthesize initialFirstResponder;
- (NSString*) nibName { return @"DonateTab"; }
- (NSString*) title   { return @"Donate"; }
- (NSImage*)  icon    { return [NSImage imageNamed:@"Donate"]; }

- (void) awakeFromNib {
    [super awakeFromNib];
    MJLinkTextFieldAddLink(self.label, MJPayPalDonationURL, [[self.label stringValue] rangeOfString:@"by PayPal"]);
    MJLinkTextFieldAddLink(self.label, MJCreditCardDonationURL, [[self.label stringValue] rangeOfString:@"with a credit card"]);
}

@end
