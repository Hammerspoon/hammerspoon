#import <Cocoa/Cocoa.h>
#import "HSGrowingTextField.h"

@interface MJConsoleWindowController : NSWindowController

@property NSColor *MJColorForStdout ;
@property NSColor *MJColorForCommand ;
@property NSColor *MJColorForResult ;
@property NSFont  *consoleFont ;
@property NSNumber *maxConsoleOutputHistory ;

+ (instancetype) singleton;
- (void) setup;

- (void)initializeConsoleColorsAndFont ;

BOOL MJConsoleWindowAlwaysOnTop(void);
void MJConsoleWindowSetAlwaysOnTop(BOOL alwaysOnTop);

#pragma mark - NSTextFieldDelegate
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command;
@end

//
// Enable & Disable Console Dark Mode:
//
BOOL ConsoleDarkModeEnabled(void);
void ConsoleDarkModeSetEnabled(BOOL enabled);
