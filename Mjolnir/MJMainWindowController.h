#import <Foundation/Foundation.h>

@interface MJMainWindowController : NSWindowController <NSToolbarDelegate>

+ (MJMainWindowController*) sharedMainWindowController;
- (void) showAtTab:(NSString*)tab;

@end
