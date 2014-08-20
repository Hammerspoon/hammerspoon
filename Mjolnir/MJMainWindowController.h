#import <Foundation/Foundation.h>

@interface MJMainWindowController : NSWindowController <NSToolbarDelegate>

+ (MJMainWindowController*) sharedMainWindowController;

- (void) maybeShowWindow;
- (void) showREPL;

@end
