#import "MJDonateTabController.h"
#import "MJLinkTextField.h"
#import "variables.h"

@interface MJDonateTabController ()
@property IBOutlet NSTextView* message;
@end

@implementation MJDonateTabController

@synthesize initialFirstResponder;
- (NSString*) nibName { return @"DonateTab"; }
- (NSString*) title   { return @"Donate"; }
- (NSImage*)  icon    { return [NSImage imageNamed:@"Donate"]; }

- (void) awakeFromNib {
    [super awakeFromNib];
    [self.message setSelectable:YES];
    
    NSMutableAttributedString* s = [self.message textStorage];
    [s beginEditing];
    [s addAttribute:NSFontAttributeName value:[NSFont systemFontOfSize:[NSFont systemFontSize]] range:NSMakeRange(0, [s length])];
    [s addAttribute:NSLinkAttributeName value:[NSURL URLWithString:MJPayPalDonationURL] range:[[s string] rangeOfString:@"by PayPal"]];
    [s addAttribute:NSLinkAttributeName value:[NSURL URLWithString:MJCreditCardDonationURL] range:[[s string] rangeOfString:@"with a credit card"]];
    [s endEditing];
}

@end
