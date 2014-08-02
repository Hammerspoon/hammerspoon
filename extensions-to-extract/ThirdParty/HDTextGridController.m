#import "HDTextGridController.h"

@interface HDTextGridController ()

@property (weak) IBOutlet HDTextGridView* tv;
@property BOOL ignoreResizesForASecond;
@property NSSize padding;

@end

@implementation HDTextGridController

- (NSString*) windowNibName {
    return @"textgrid";
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [self usePadding:NSMakeSize(5, 5)];
    [self useFont:[NSFont fontWithName:@"Menlo" size:12]];
    [self useGridSize:NSMakeSize(80, 24)];
}

- (void) usePadding:(NSSize)size {
    self.padding = size;
}

- (void) useKeyDownHandler:(KOKeyDownHandler)handler {
    self.tv.keyDownHandler = handler;
}

- (void) windowDidResize:(NSNotification *)notification {
    if (self.ignoreResizesForASecond)
        return;
    
    NSSize newViewSize = [[[self window] contentView] frame].size;
    
    // i have NO idea what this equation does or why it works. but IT WORKS. granted im afraid to touch it ever again.
    CGFloat newGridWidth  = floor((newViewSize.width -  self.padding.width  * 2) / self.tv.charWidth);
    CGFloat newGridHeight = floor((newViewSize.height - self.padding.height * 2) / self.tv.charHeight);
    
    [self useGridSize:NSMakeSize(newGridWidth, newGridHeight)];
}

- (void) windowWillClose:(NSNotification *)notification {
    if (self.windowClosedHandler)
        self.windowClosedHandler();
}

- (void) useFont:(NSFont*)font {
    [self.tv useFont:font];
    [[self window] setContentResizeIncrements:NSMakeSize(floor(self.tv.charWidth), floor(self.tv.charHeight))];
    [self useGridSize:NSMakeSize(self.tv.cols, self.tv.rows)];
}

- (NSFont*) font {
    return [self.tv font];
}

- (int) cols {
    return self.tv.cols;
}

- (int) rows {
    return self.tv.rows;
}

- (void) setChar:(NSString*)c x:(int)x y:(int)y {
    [self.tv setChar:c x:x y:y];
}

- (void) setForeground:(NSColor*)fg x:(int)x y:(int)y {
    [self.tv setForeground:fg x:x y:y];
}

- (void) setBackground:(NSColor*)bg x:(int)x y:(int)y {
    [self.tv setBackground:bg x:x y:y];
}

- (void) useGridSize:(NSSize)size {
    [self.tv postponeRedraws:^{
        self.ignoreResizesForASecond = YES;
        
        [self.tv useGridSize:size];
        
        // pad content view size
        NSSize newContentViewSize = [self.tv realViewSize];
        newContentViewSize.width += self.padding.width * 2;
        newContentViewSize.height += self.padding.height * 2;
        
        // resize, keeping top-left the same
        NSDisableScreenUpdates();
        NSRect frame = [[self window] frame];
        NSPoint p = NSMakePoint(NSMinX(frame), NSMaxY(frame));
        [[self window] setContentSize:newContentViewSize];
        [[self window] setFrameTopLeftPoint:p];
        NSEnableScreenUpdates();
        
        // center text view in padding
        NSRect tvFrame;
        tvFrame.size.width  = self.tv.cols * self.tv.charWidth;
        tvFrame.size.height = self.tv.rows * self.tv.charHeight;
        tvFrame.origin = NSMakePoint(self.padding.width, self.padding.height);
        [self.tv setFrame: tvFrame];
        
        self.ignoreResizesForASecond = NO;
        
        if (self.windowResizedHandler)
            self.windowResizedHandler();
    }];
}

- (void) clear {
    [self.tv clear];
}

- (void) setForeground:(NSColor*)fg {
    [self.tv setForeground:fg];
}

- (void) setBackground:(NSColor*)bg {
    [[self window] setBackgroundColor:bg];
    [self.tv setBackground:bg];
}

@end


@implementation HDTextGridWindow

- (BOOL) canBecomeKeyWindow {
    return YES;
}

- (BOOL) canBecomeMainWindow {
    return YES;
}

@end