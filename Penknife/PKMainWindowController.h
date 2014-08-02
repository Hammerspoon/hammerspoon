#import <Foundation/Foundation.h>

@interface PKMainWindowController : NSWindowController <NSToolbarDelegate>

+ (PKMainWindowController*) sharedMainWindowController;
- (void) showAtTab:(NSString*)tab;

@end
