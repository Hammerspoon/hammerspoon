#import <Foundation/Foundation.h>

@interface HydraLicense : NSObject

- (void) initialCheck;
- (void) enter;
- (BOOL) hasLicense;

@end
