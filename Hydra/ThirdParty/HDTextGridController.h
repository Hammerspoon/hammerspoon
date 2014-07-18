#import <Cocoa/Cocoa.h>
#import "HDTextGridView.h"

@interface HDTextGridController : NSWindowController <NSWindowDelegate>

- (void) useFont:(NSFont*)font;
- (void) useGridSize:(NSSize)size;
- (NSFont*) font;

- (int) cols;
- (int) rows;

- (void) setChar:(NSString*)c x:(int)x y:(int)y;
- (void) setForeground:(NSColor*)fg x:(int)x y:(int)y;
- (void) setBackground:(NSColor*)bg x:(int)x y:(int)y;
- (void) clear;
- (void) setForeground:(NSColor*)fg;
- (void) setBackground:(NSColor*)bg;

@property (copy) dispatch_block_t windowResizedHandler;
@property (copy) dispatch_block_t windowClosedHandler;

- (void) useKeyDownHandler:(KOKeyDownHandler)handler;

@end

@interface HDTextGridWindow : NSWindow

@end
