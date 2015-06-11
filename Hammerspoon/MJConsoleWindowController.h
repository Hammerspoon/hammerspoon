#import <Cocoa/Cocoa.h>
#import "HSGrowingTextField.h"

@interface MJConsoleWindowController : NSWindowController

+ (instancetype) singleton;
- (void) setup;

@end

BOOL MJConsoleWindowAlwaysOnTop(void);
void MJConsoleWindowSetAlwaysOnTop(BOOL alwaysOnTop);
