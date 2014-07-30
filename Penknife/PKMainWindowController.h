#import <Cocoa/Cocoa.h>

@interface PKMainWindowController : NSWindowController <NSToolbarDelegate>

- (void) showAtTab:(NSString*)tab;

@end
