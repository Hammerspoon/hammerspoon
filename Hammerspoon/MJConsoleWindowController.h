#import <Cocoa/Cocoa.h>
#import "HSGrowingTextField.h"

@interface MJConsoleWindowController : NSWindowController

+ (instancetype) singleton;
- (void) setup;

BOOL MJConsoleWindowAlwaysOnTop(void);
void MJConsoleWindowSetAlwaysOnTop(BOOL alwaysOnTop);

#pragma mark - NSTextFieldDelegate
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command;
@end
