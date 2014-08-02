#import "HDTextGridView.h"
#import <QuartzCore/QuartzCore.h>


@interface HDTextGridView ()

@property (readwrite) CGFloat charWidth;
@property (readwrite) CGFloat charHeight;

@property (readwrite) int rows;
@property (readwrite) int cols;

@property NSMutableAttributedString* buffer;
@property NSMutableDictionary* defaultAttrs;

@property BOOL postponeRedraws;

@end

@implementation HDTextGridView

- (id) initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        self.buffer = [[NSMutableAttributedString alloc] init];
        self.defaultAttrs = [NSMutableDictionary dictionary];
        
        NSMutableParagraphStyle* pstyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [pstyle setLineBreakMode:NSLineBreakByCharWrapping];
        
        self.defaultAttrs[NSParagraphStyleAttributeName] = pstyle;
    }
    return self;
}

- (BOOL) acceptsFirstResponder { return YES; }

- (void) keyDown:(NSEvent *)theEvent {
    BOOL ctrl = ([theEvent modifierFlags] & NSControlKeyMask) != 0;
    BOOL cmd = ([theEvent modifierFlags] & NSCommandKeyMask) != 0;
    BOOL alt = ([theEvent modifierFlags] & NSAlternateKeyMask) != 0;
    
    NSString* str = [theEvent charactersIgnoringModifiers];
    
    if ([str characterAtIndex:0] == 127) str = @"delete";
    if ([str characterAtIndex:0] == 13) str = @"return";
    if ([str characterAtIndex:0] == 9) str = @"tab";
    if ([str characterAtIndex:0] == 63232) str = @"up";
    if ([str characterAtIndex:0] == 63233) str = @"down";
    if ([str characterAtIndex:0] == 63234) str = @"left";
    if ([str characterAtIndex:0] == 63235) str = @"right";
    
//    NSLog(@"%d", [str characterAtIndex:0]);
    
    if (self.keyDownHandler)
        self.keyDownHandler(ctrl, alt, cmd, str);
}

- (NSFont*) font {
    return [self.defaultAttrs objectForKey:NSFontAttributeName];
}

- (void) useFont:(NSFont*)font {
    self.defaultAttrs[NSFontAttributeName] = font;
    [self.buffer addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, [self.buffer length])];
    
    NSAttributedString* as = [[NSAttributedString alloc] initWithString:@"x" attributes:self.defaultAttrs];
    CTFramesetterRef frameSetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)as);
    CGSize suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(frameSetter, CFRangeMake(0, 1), NULL, CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX), NULL);
    CFRelease(frameSetter);
    
    self.charWidth = suggestedSize.width;
    self.charHeight = suggestedSize.height;
}

- (NSSize) realViewSize {
    return NSMakeSize(self.charWidth * self.cols,
                      self.charHeight * self.rows);
}

- (NSRect) rectForCharacterIndex:(NSUInteger)i {
    NSRect bounds = [self bounds];
    bounds.size = [self realViewSize]; // awww, duplicated code :/
    
    NSRect r;
    r.origin.x = (i % self.cols) * self.charWidth;
    r.origin.y = NSMaxY(bounds) - (((i / self.cols) + 1) * self.charHeight);
    r.size.width = self.charWidth;
    r.size.height = self.charHeight;
    
    r = NSIntegralRect(r);
    
    return r;
}

- (void) drawRect:(NSRect)dirtyRect {
    if (self.postponeRedraws)
        return;
    
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSetTextMatrix(ctx, CGAffineTransformIdentity);
    
    NSRect bounds = [self bounds];
    bounds.size = [self realViewSize];
    
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)self.buffer);
    
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, bounds);
    
    CTFrameRef textFrame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0,0), path, NULL);
    
    // we have to manually draw backgrounds :/
    
    [self.buffer enumerateAttribute:NSBackgroundColorAttributeName
                            inRange:NSMakeRange(0, [self.buffer length])
                            options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                         usingBlock:^(NSColor* color, NSRange range, BOOL *stop) {
                             if (color && ![color isEqual:[[self window] backgroundColor]]) {
                                 [color setFill];
                                 if (NSEqualRanges(range, NSMakeRange(0, [self.buffer length]))) {
                                     [NSBezierPath fillRect:[self bounds]];
                                 }
                                 else {
                                     for (NSUInteger i = range.location; i < NSMaxRange(range); i++) {
                                         NSRect bgRect = [self rectForCharacterIndex:i];
                                         [NSBezierPath fillRect:bgRect];
                                     }
                                 }
                             }
                         }];
    
    // okay, now draw the actual text (just one line! ha!)
    
    CTFrameDraw(textFrame, ctx);
    
    CFRelease(framesetter);
    CFRelease(textFrame);
    CGPathRelease(path);
}

- (void) useGridSize:(NSSize)size {
    self.cols = size.width;
    self.rows = size.height;
    
    // whenever we resize the grid, (if change > 0) just pad to length with " " and re-font the newly added text
    
    NSUInteger newBufferLen = self.cols * self.rows;
    NSUInteger oldLen = [self.buffer length];
    NSInteger diff = newBufferLen - oldLen;
    
    if (diff > 0) {
        NSString* padding = [@"" stringByPaddingToLength:diff withString:@" " startingAtIndex:0];
        [[self.buffer mutableString] appendString:padding];
        [self.buffer setAttributes:self.defaultAttrs range:NSMakeRange(oldLen, diff)];
    }
}

- (void) redrawCharUnlessPostponed:(NSUInteger)i {
    if (!self.postponeRedraws) {
        NSRect r = [self rectForCharacterIndex:i];
        [self setNeedsDisplayInRect:r];
    }
}

- (void) setChar:(NSString*)c x:(int)x y:(int)y {
    NSUInteger i = x + y * self.cols;
    NSRange r = NSMakeRange(i, [c length]);
    [self.buffer replaceCharactersInRange:r withString:c];
    
    [self redrawCharUnlessPostponed:i];
}

- (void) setForeground:(NSColor*)fg x:(int)x y:(int)y {
    NSUInteger i = x + y * self.cols;
    NSRange r = NSMakeRange(i, 1);
    [self.buffer addAttribute:NSForegroundColorAttributeName value:fg range:r];
    
    [self redrawCharUnlessPostponed:i];
}

- (void) setBackground:(NSColor*)bg x:(int)x y:(int)y {
    NSUInteger i = x + y * self.cols;
    NSRange r = NSMakeRange(i, 1);
    [self.buffer addAttribute:NSBackgroundColorAttributeName value:bg range:r];
    
    [self redrawCharUnlessPostponed:i];
}

- (void) clear {
    NSString* padding = [@"" stringByPaddingToLength:[self.buffer length] withString:@" " startingAtIndex:0];
    NSRange r = NSMakeRange(0, [self.buffer length]);
    [self.buffer replaceCharactersInRange:r withString:padding];
    
    if (!self.postponeRedraws)
        [self setNeedsDisplay:YES];
}

- (void) setForeground:(NSColor*)fg {
    NSRange r = NSMakeRange(0, [self.buffer length]);
    [self.buffer addAttribute:NSForegroundColorAttributeName value:fg range:r];
    
    if (!self.postponeRedraws)
        [self setNeedsDisplay:YES];
}

- (void) setBackground:(NSColor*)bg {
    NSRange r = NSMakeRange(0, [self.buffer length]);
    [self.buffer addAttribute:NSBackgroundColorAttributeName value:bg range:r];
    
    if (!self.postponeRedraws)
        [self setNeedsDisplay:YES];
}

- (void) clear:(NSColor*)bg {
    NSString* padding = [@"" stringByPaddingToLength:[self.buffer length] withString:@" " startingAtIndex:0];
    NSRange r = NSMakeRange(0, [self.buffer length]);
    [self.buffer replaceCharactersInRange:r withString:padding];
    [self.buffer addAttribute:NSBackgroundColorAttributeName value:bg range:r];
    
    if (!self.postponeRedraws)
        [self setNeedsDisplay:YES];
}

- (void) postponeRedraws:(dispatch_block_t)blk {
    self.postponeRedraws = YES;
    blk();
    self.postponeRedraws = NO;
    [self setNeedsDisplay:YES];
}

@end
