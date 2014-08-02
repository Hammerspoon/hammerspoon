#import <Cocoa/Cocoa.h>

typedef void(^KOKeyDownHandler)(BOOL ctrl, BOOL alt, BOOL cmd, NSString* str);

@interface HDTextGridView : NSView

@property (readonly) CGFloat charWidth;
@property (readonly) CGFloat charHeight;

@property (readonly) int rows;
@property (readonly) int cols;

@property (copy) KOKeyDownHandler keyDownHandler;

- (void) useFont:(NSFont*)font;
- (void) useGridSize:(NSSize)size;

- (NSFont*) font;

- (NSSize) realViewSize;

- (void) clear;
- (void) setForeground:(NSColor*)fg;
- (void) setBackground:(NSColor*)bg;

- (void) postponeRedraws:(dispatch_block_t)blk;

- (void) setChar:(NSString*)c x:(int)x y:(int)y;
- (void) setForeground:(NSColor*)fg x:(int)x y:(int)y;
- (void) setBackground:(NSColor*)bg x:(int)x y:(int)y;

@end
