#import <Foundation/Foundation.h>

@interface MJMainWindowController : NSWindowController <NSToolbarDelegate>

+ (MJMainWindowController*) sharedMainWindowController;

- (void) setup;
- (void) showREPL;

@end
