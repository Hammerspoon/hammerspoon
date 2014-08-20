#import <Foundation/Foundation.h>

@interface MJDockIcon : NSObject

+ (MJDockIcon*) sharedDockIcon;

@property BOOL visible;

- (void) setup;

@end
