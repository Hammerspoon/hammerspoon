#import <Cocoa/Cocoa.h>

@interface MJConsoleWindowController : NSWindowController

+ (instancetype) singleton;
- (void) setup;

@end
