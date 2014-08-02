#import <Foundation/Foundation.h>

BOOL hydra_verifylicense(NSString* pubkey, NSString* sig, NSString* email);

@interface HydraLicense : NSObject

- (void) initialCheck;
- (void) enter;
- (BOOL) hasLicense;

@end
