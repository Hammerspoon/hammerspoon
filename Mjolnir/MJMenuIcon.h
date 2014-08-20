#import <Foundation/Foundation.h>

@interface MJMenuIcon : NSObject

+ (MJMenuIcon*) sharedIcon;

- (void) setup;

@property BOOL visible;

@end
