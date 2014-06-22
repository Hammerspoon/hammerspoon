#import <Cocoa/Cocoa.h>
#import "HDTextGridView.h"

@interface HDTextGridController : NSWindowController <NSWindowDelegate>

- (void) useFont:(NSFont*)font;
- (void) useGridSize:(NSSize)size;
- (NSFont*) font;

- (int) cols;
- (int) rows;

- (void) setChar:(unsigned short)c x:(int)x y:(int)y fg:(NSColor*)fg bg:(NSColor*)bg;
- (void) clear:(NSColor*)bg;

@property (copy) dispatch_block_t windowResizedHandler;

- (void) useKeyDownHandler:(KOKeyDownHandler)handler;

@end
