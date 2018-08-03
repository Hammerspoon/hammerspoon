#import "drawing.h"

/// === hs.drawing ===
///
/// Primitives for drawing on the screen in various ways

// Useful definitions
#define USERDATA_TAG "hs.drawing"
#define get_item_arg(L, idx) ((drawing_t *)luaL_checkudata(L, idx, USERDATA_TAG))

static int refTable;

NSMutableArray *drawingWindows;

// Objective-C class interface implementations
@implementation HSDrawingWindow
- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask __unused)windowStyle backing:(NSBackingStoreType __unused)bufferingType defer:(BOOL __unused)deferCreation {
    //NSLog(@"HSDrawingWindow::initWithContentRect contentRect:(%.1f,%.1f) %.1fx%.1f", contentRect.origin.x, contentRect.origin.y, contentRect.size.width, contentRect.size.height);

    if (!isfinite(contentRect.origin.x) || !isfinite(contentRect.origin.y) || !isfinite(contentRect.size.height) || !isfinite(contentRect.size.width) || !CGRectContainsRect(CGRectMake((CGFloat)INT_MIN, (CGFloat)INT_MIN, (CGFloat)INT_MAX - (CGFloat)INT_MIN, (CGFloat)INT_MAX - (CGFloat)INT_MIN), contentRect)) {
        LuaSkin *skin = [LuaSkin shared];
        [skin logError:@"hs.drawing object created with invalid sizeRect"];
        return nil;
    }

    self = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask
                                                    backing:NSBackingStoreBuffered defer:YES];
    if (self) {
        [self setDelegate:self];
        contentRect.origin.y=[[NSScreen screens][0] frame].size.height - contentRect.origin.y - contentRect.size.height;
        //NSLog(@"HSDrawingWindow::initWithContentRect corrected for bottom-left origin.y to %.1f", contentRect.origin.y);

        [self setFrameOrigin:contentRect.origin];

        // Configure the window
        self.releasedWhenClosed = NO;
        self.backgroundColor = [NSColor clearColor];
        self.opaque = NO;
        self.hasShadow = NO;
        self.ignoresMouseEvents = YES;
        self.restorable = NO;
        self.hidesOnDeactivate  = NO;
        self.animationBehavior = NSWindowAnimationBehaviorNone;
        self.level = NSScreenSaverWindowLevel;
        self.accessibilitySubrole = @"hammerspoonDrawing" ;
    }
    return self;
}

- (void)setLevelScreenSaver {
    self.level = NSScreenSaverWindowLevel;
}

- (void)setLevelTop {
    self.level = NSFloatingWindowLevel;
}

- (void)setLevelBottom {
    self.level = CGWindowLevelForKey(kCGDesktopIconWindowLevelKey) - 1;
}

// NSWindowDelegate method. We decline to close the window because we don't want external things interfering with the user's decisions to display these objects.
- (BOOL)windowShouldClose:(id __unused)sender {
    //NSLog(@"HSDrawingWindow::windowShouldClose");
    return NO;
}

- (void)fadeInAndMakeKeyAndOrderFront:(NSTimeInterval)fadeTime {
    [self setAlphaValue:0.f];
    [self makeKeyAndOrderFront:nil];
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:fadeTime];
    [[self animator] setAlphaValue:1.f];
    [NSAnimationContext endGrouping];
}

- (void)fadeOutAndOrderOut:(NSTimeInterval)fadeTime {
    [NSAnimationContext beginGrouping];
    __block HSDrawingWindow *bself = self;
    [[NSAnimationContext currentContext] setDuration:fadeTime];
    [[NSAnimationContext currentContext] setCompletionHandler:^{
        if (bself) {
            [bself orderOut:nil];
            [bself setAlphaValue:1.f];
        }
    }];
    [[self animator] setAlphaValue:0.f];
    [NSAnimationContext endGrouping];
}

@end

@implementation HSDrawingView
- (id)initWithFrame:(NSRect)frameRect {
    //NSLog(@"HSDrawingView::initWithFrame frameRect:(%.1f,%.1f) %.1fx%.1f", frameRect.origin.x, frameRect.origin.y, frameRect.size.width, frameRect.size.height);
    self = [super initWithFrame:frameRect];
    if (self) {
        // Set up our defaults
        L = NULL;
        self.mouseUpCallbackRef = LUA_NOREF;
        self.mouseDownCallbackRef = LUA_NOREF;
        self.HSFill = YES;
        self.HSStroke = YES;
        self.HSLineWidth = [NSBezierPath defaultLineWidth];
        self.HSFillColor = [NSColor redColor];
        self.HSStrokeColor = [NSColor blackColor];
        self.HSGradientStartColor = nil;
        self.HSGradientEndColor = nil;
        self.HSGradientAngle = 0;
        self.HSRoundedRectXRadius = 0.0;
        self.HSRoundedRectYRadius = 0.0;
        self.clipToRect = NO ;
        self.rectClippingBoundry = NSZeroRect ;
    }
    return self;
}

- (void)setLuaState:(lua_State *)luaState {
    L = luaState;
}

- (BOOL)isFlipped {
    return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent * __unused)theEvent {
    if (self.window == nil) return NO;
    return !self.window.ignoresMouseEvents;
}

- (void)setMouseUpCallback:(int)ref {
    self.mouseUpCallbackRef = ref;

    if (self.window) {
        [self.window setIgnoresMouseEvents:((ref == LUA_NOREF) && (self.mouseDownCallbackRef == LUA_NOREF))];
    }
}

- (void)setMouseDownCallback:(int)ref {
    self.mouseDownCallbackRef = ref;

    if (self.window) {
        [self.window setIgnoresMouseEvents:((ref == LUA_NOREF) && (self.mouseUpCallbackRef == LUA_NOREF))];
    }
}

- (void)mouseUp:(NSEvent * __unused)theEvent {
    if (self.mouseUpCallbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared];
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:self.mouseUpCallbackRef];
        [skin protectedCallAndError:@"hs.drawing mouseUp click callback" nargs:0 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

- (void)rightMouseUp:(NSEvent *)theEvent {
    [self mouseUp:theEvent] ;
}

- (void)otherMouseUp:(NSEvent *)theEvent {
    [self mouseUp:theEvent] ;
}

- (void)mouseDown:(NSEvent * __unused)theEvent {
    [NSApp preventWindowOrdering];
    if (self.mouseDownCallbackRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared];
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:self.mouseDownCallbackRef];
        [skin protectedCallAndError:@"hs.drawing mouseDown click callback" nargs:0 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

- (void)rightMouseDown:(NSEvent *)theEvent {
    [self mouseDown:theEvent] ;
}

- (void)otherMouseDown:(NSEvent *)theEvent {
    [self mouseDown:theEvent] ;
}

@end

@implementation HSDrawingViewCircle
- (void)drawRect:(NSRect)rect {
    //NSLog(@"HSDrawingViewCircle::drawRect");
    // Get the graphics context that we are currently executing under
    NSGraphicsContext* gc = [NSGraphicsContext currentContext];

    // Save the current graphics context settings
    [gc saveGraphicsState];

    // Set the color in the current graphics context for future draw operations
    [[self HSStrokeColor] setStroke];
    [[self HSFillColor] setFill];

    // Create our circle path
    NSBezierPath* circlePath = [NSBezierPath bezierPath];
    [circlePath appendBezierPathWithOvalInRect:rect];

    // Draw our shape (fill) and outline (stroke)
    if (self.HSFill) {
        [circlePath setClip];
        if (self.clipToRect) {
            NSRect windowFrame = [self.window frame] ;
            NSRect myRect      = self.rectClippingBoundry ;
            myRect.origin.x    = myRect.origin.x - windowFrame.origin.x ;
            myRect.origin.y    = myRect.origin.y - ([[NSScreen screens][0] frame].size.height - windowFrame.origin.y - windowFrame.size.height);
            NSRectClip(myRect) ;
        }
         if (!self.HSGradientStartColor) {
            [circlePath fill];
        } else {
            NSGradient* aGradient = [[NSGradient alloc] initWithStartingColor:self.HSGradientStartColor
                                                                  endingColor:self.HSGradientEndColor];
            [aGradient drawInRect:[self bounds] angle:self.HSGradientAngle];
        }
    }
    if (self.HSStroke) {
        circlePath.lineWidth = self.HSLineWidth * 2.0; // We have to double this because the stroking line is centered around the path, but we want to clip it to not stray outside the path
        [circlePath setClip];
        if (self.clipToRect) {
            NSRect windowFrame = [self.window frame] ;
            NSRect myRect      = self.rectClippingBoundry ;
            myRect.origin.x    = myRect.origin.x - windowFrame.origin.x ;
            myRect.origin.y    = myRect.origin.y - ([[NSScreen screens][0] frame].size.height - windowFrame.origin.y - windowFrame.size.height);
            NSRectClip(myRect) ;
        }
        [circlePath stroke];
    }

    // Restore the context to what it was before we messed with it
    [gc restoreGraphicsState];
}
@end

@implementation HSDrawingViewEllipticalArc
- (void)drawRect:(NSRect)rect {

    // Get the graphics context that we are currently executing under
    NSGraphicsContext* gc = [NSGraphicsContext currentContext];

    // Save the current graphics context settings
    [gc saveGraphicsState];

    // Set the color in the current graphics context for future draw operations
    [[self HSStrokeColor] setStroke];
    [[self HSFillColor] setFill];

    // Create our arc path
    CGFloat cx = rect.origin.x + rect.size.width / 2 ;
    CGFloat cy = rect.origin.y + rect.size.height / 2 ;
    CGFloat r  = rect.size.width / 2 ;

    NSAffineTransform *moveTransform = [NSAffineTransform transform] ;
    [moveTransform translateXBy:cx yBy:cy] ;
    NSAffineTransform *scaleTransform = [NSAffineTransform transform] ;
    [scaleTransform scaleXBy:1.0 yBy:(rect.size.height / rect.size.width)] ;
    NSAffineTransform *finalTransform = [[NSAffineTransform alloc] initWithTransform:scaleTransform] ;
    [finalTransform appendTransform:moveTransform] ;


    NSBezierPath* arcPath = [NSBezierPath bezierPath];
    if (self.HSFill) [arcPath moveToPoint:NSZeroPoint] ;
    [arcPath appendBezierPathWithArcWithCenter:NSZeroPoint
                                        radius:r
                                    startAngle:self.startAngle
                                      endAngle:self.endAngle
//                                      clockwise:YES
    ] ;
    if (self.HSFill) [arcPath lineToPoint:NSZeroPoint] ;

    arcPath = [finalTransform transformBezierPath:arcPath] ;

    // Draw our shape (fill) and outline (stroke)
    if (self.HSFill) {
        [arcPath setClip];
        if (self.clipToRect) {
            NSRect windowFrame = [self.window frame] ;
            NSRect myRect      = self.rectClippingBoundry ;
            myRect.origin.x    = myRect.origin.x - windowFrame.origin.x ;
            myRect.origin.y    = myRect.origin.y - ([[NSScreen screens][0] frame].size.height - windowFrame.origin.y - windowFrame.size.height);
            NSRectClip(myRect) ;
        }
        if (!self.HSGradientStartColor) {
            [arcPath fill];
        } else {
            NSGradient* aGradient = [[NSGradient alloc] initWithStartingColor:self.HSGradientStartColor
                                                                  endingColor:self.HSGradientEndColor];
            [aGradient drawInRect:[self bounds] angle:self.HSGradientAngle];
        }
    }
    if (self.HSStroke) {
        arcPath.lineWidth = self.HSLineWidth * 2.0; // We have to double this because the stroking line is centered around the path, but we want to clip it to not stray outside the path
        [arcPath setClip];
        if (self.clipToRect) {
            NSRect windowFrame = [self.window frame] ;
            NSRect myRect      = self.rectClippingBoundry ;
            myRect.origin.x    = myRect.origin.x - windowFrame.origin.x ;
            myRect.origin.y    = myRect.origin.y - ([[NSScreen screens][0] frame].size.height - windowFrame.origin.y - windowFrame.size.height);
            NSRectClip(myRect) ;
        }
        [arcPath stroke];
    }

    // Restore the context to what it was before we messed with it
    [gc restoreGraphicsState];
}
@end

@implementation HSDrawingViewRect
- (void)drawRect:(NSRect)rect {
    //NSLog(@"HSDrawingViewRect::drawRect");
    // Get the graphics context that we are currently executing under
    NSGraphicsContext* gc = [NSGraphicsContext currentContext];

    // Save the current graphics context settings
    [gc saveGraphicsState];

    // Set the color in the current graphics context for future draw operations
    [[self HSStrokeColor] setStroke];
    [[self HSFillColor] setFill];

    // Create our rectangle path
    NSBezierPath* rectPath = [NSBezierPath bezierPath];
    [rectPath appendBezierPathWithRoundedRect:rect xRadius:self.HSRoundedRectXRadius yRadius:self.HSRoundedRectYRadius];

    // Draw our shape (fill) and outline (stroke)
    if (self.HSFill) {
        [rectPath setClip];
        if (self.clipToRect) {
            NSRect windowFrame = [self.window frame] ;
            NSRect myRect      = self.rectClippingBoundry ;
            myRect.origin.x    = myRect.origin.x - windowFrame.origin.x ;
            myRect.origin.y    = myRect.origin.y - ([[NSScreen screens][0] frame].size.height - windowFrame.origin.y - windowFrame.size.height);
            NSRectClip(myRect) ;
        }
        if (!self.HSGradientStartColor) {
            [rectPath fill];
        } else {
            NSGradient* aGradient = [[NSGradient alloc] initWithStartingColor:self.HSGradientStartColor
                                                                  endingColor:self.HSGradientEndColor];
            [aGradient drawInRect:[self bounds] angle:self.HSGradientAngle];
        }
    }
    if (self.HSStroke) {
        rectPath.lineWidth = self.HSLineWidth;
        [rectPath setClip];
        if (self.clipToRect) {
            NSRect windowFrame = [self.window frame] ;
            NSRect myRect      = self.rectClippingBoundry ;
            myRect.origin.x    = myRect.origin.x - windowFrame.origin.x ;
            myRect.origin.y    = myRect.origin.y - ([[NSScreen screens][0] frame].size.height - windowFrame.origin.y - windowFrame.size.height);
            NSRectClip(myRect) ;
        }
        [rectPath stroke];
    }

    // Restore the context to what it was before we messed with it
    [gc restoreGraphicsState];
}
@end

@implementation HSDrawingViewLine
- (id)initWithFrame:(NSRect)frameRect {
    //NSLog(@"HSDrawingViewLine::initWithFrame");
    self = [super initWithFrame:frameRect];
    if (self) {
        self.origin = CGPointZero;
        self.end = CGPointZero;
    }
    return self;
}

- (void)drawRect:(NSRect __unused)rect {
    //NSLog(@"HSDrawingViewLine::drawRect");
    // Get the graphics context that we are currently executing under
    NSGraphicsContext* gc = [NSGraphicsContext currentContext];

    // Save the current graphics context settings
    [gc saveGraphicsState];
    if (self.clipToRect) {
        NSRect windowFrame = [self.window frame] ;
        NSRect myRect      = self.rectClippingBoundry ;
        myRect.origin.x    = myRect.origin.x - windowFrame.origin.x ;
        myRect.origin.y    = myRect.origin.y - ([[NSScreen screens][0] frame].size.height - windowFrame.origin.y - windowFrame.size.height);
        NSRectClip(myRect) ;
    }

    // Set the color in the current graphics context for future draw operations
    [[self HSStrokeColor] setStroke];

    // Create our line path. We do this by placing the line from the origin point to the end point
    NSBezierPath* linePath = [NSBezierPath bezierPath];
    linePath.lineWidth = self.HSLineWidth;

    //NSLog(@"HSDrawingViewLine::drawRect: Rendering line from (%.1f,%.1f) to (%.1f,%.1f)", self.origin.x, self.origin.y, self.end.x, self.end.y);
    [linePath moveToPoint:self.origin];
    [linePath lineToPoint:self.end];

    // Draw our shape (stroke)
    [linePath stroke];

    // Restore the context to what it was before we messed with it
    [gc restoreGraphicsState];
}
@end

@implementation HSDrawingViewText
- (id)initWithFrame:(NSRect)frameRect {
    //NSLog(@"HSDrawingViewText::initWithFrame");
    self = [super initWithFrame:frameRect];
    if (self) {
// NOTE: Change default_textAttributes(...) and drawing_getTextDrawingSize(...) if you change these
        HSDrawingTextField *theTextField = [[HSDrawingTextField alloc] initWithFrame:frameRect];
        [theTextField setFont: [NSFont systemFontOfSize: 27]];
        [theTextField setTextColor: [NSColor colorWithCalibratedWhite:1.0 alpha:1.0]];
        [theTextField setDrawsBackground: NO];
        [theTextField setBordered: NO];
        [theTextField setEditable: NO];
        [theTextField setSelectable: NO];
        [self addSubview:(NSTextField *)theTextField];
        self.textField = (NSTextField *)theTextField;
    }
    return self;
}
@end

@implementation HSDrawingViewImage
- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.HSImageView = [[HSDrawingNSImageView alloc] initWithFrame:frameRect];
        self.HSImageView.animates = YES;
        self.HSImageView.imageScaling = NSImageScaleProportionallyUpOrDown;
        [self addSubview:self.HSImageView];
    }
    return self;
}

- (void)setImage:(NSImage *)newImage {
    NSImage *imageCopy = [newImage copy];
    self.HSImageView.image = imageCopy;
    self.HSImage = imageCopy;

    self.needsDisplay = true;

    return;
}
@end

@implementation HSDrawingNSImageView
- (void)drawRect:(NSRect)rect {
    NSGraphicsContext* gc = [NSGraphicsContext currentContext];

    // Save the current graphics context settings
    [gc saveGraphicsState];

    if (((HSDrawingViewText *)self.superview).clipToRect) {
        NSRect windowFrame = [self.window frame] ;
        NSRect myRect      = ((HSDrawingViewText *)self.superview).rectClippingBoundry ;
        myRect.origin.x    = myRect.origin.x - windowFrame.origin.x ;
        myRect.origin.y    = myRect.origin.y - ([[NSScreen screens][0] frame].size.height - windowFrame.origin.y - windowFrame.size.height);
        NSRectClip(myRect) ;
    }
    [super drawRect:rect];

    // Restore the context to what it was before we messed with it
    [gc restoreGraphicsState];
}
@end

@implementation HSDrawingTextField
- (void)drawRect:(NSRect)rect {
    NSGraphicsContext* gc = [NSGraphicsContext currentContext];

    // Save the current graphics context settings
    [gc saveGraphicsState];

    if (((HSDrawingViewText *)self.superview).clipToRect) {
        NSRect windowFrame = [self.window frame] ;
        NSRect myRect      = ((HSDrawingViewText *)self.superview).rectClippingBoundry ;
        myRect.origin.x    = myRect.origin.x - windowFrame.origin.x ;
        myRect.origin.y    = myRect.origin.y - ([[NSScreen screens][0] frame].size.height - windowFrame.origin.y - windowFrame.size.height);
        NSRectClip(myRect) ;
    }
    [super drawRect:rect];

    // Restore the context to what it was before we messed with it
    [gc restoreGraphicsState];
}
@end

// Lua API implementation

/// hs.drawing.disableScreenUpdates() -> None
/// Function
/// Tells the OS X window server to pause updating the physical displays for a short while.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * This method can be used to allow multiple changes which are being made to the users display appear as if they all occur simultaneously by holding off on updating the screen on the regular schedule.
///  * This method should always be balanced with a call to [hs.drawing.enableScreenUpdates](#enableScreenUpdates) when your updates have been completed.  Failure to do so will be logged in the system logs.
///
///  * The window server will only allow you to pause updates for up to 1 second.  This prevents a rogue or hung process from locking the systems display completely.  Updates will be resumed when [hs.drawing.enableScreenUpdates](#enableScreenUpdates) is encountered or after 1 second, whichever comes first.
static int disableUpdates(__unused lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;
    NSDisableScreenUpdates() ;
    return 0 ;
}

/// hs.drawing.enableScreenUpdates() -> None
/// Function
/// Tells the OS X window server to resume updating the physical displays after a previous pause.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * In conjunction with [hs.drawing.disableScreenUpdates](#disableScreenUpdates), this method can be used to allow multiple changes which are being made to the users display appear as if they all occur simultaneously by holding off on updating the screen on the regular schedule.
///
///  * The window server will only allow you to pause updates for up to 1 second.  This prevents a rogue or hung process from locking the systems display completely.  Updates will be resumed when this function is encountered  or after 1 second, whichever comes first.
static int enableUpdates(__unused lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;
    NSEnableScreenUpdates() ;
    return 0 ;
}


/// hs.drawing.circle(sizeRect) -> drawingObject or nil
/// Constructor
/// Creates a new circle object
///
/// Parameters:
///  * sizeRect - A rect-table containing the location/size of the circle
///
/// Returns:
///  * An `hs.drawing` object, or nil if an error occurs
static int drawing_newCircle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TTABLE, LS_TBREAK];

    NSRect windowRect = [skin tableToRectAtIndex:1];
    HSDrawingWindow *theWindow = [[HSDrawingWindow alloc] initWithContentRect:windowRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];

    if (theWindow) {
        drawing_t *drawingObject = lua_newuserdata(L, sizeof(drawing_t));
        memset(drawingObject, 0, sizeof(drawing_t));
        drawingObject->window = (__bridge_retained void*)theWindow;
        drawingObject->skipClose = NO ;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);

        HSDrawingViewCircle *theView = [[HSDrawingViewCircle alloc] initWithFrame:((NSView *)theWindow.contentView).bounds];
        [theView setLuaState:L];

        theWindow.contentView = theView;

        if (!drawingWindows) {
            drawingWindows = [[NSMutableArray alloc] init];
        }
        [drawingWindows addObject:theWindow];
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.drawing.ellipticalArc(sizeRect, startAngle, endAngle) -> drawingObject or nil
/// Constructor
/// Creates a new elliptical arc object
///
/// Parameters:
///  * sizeRect    - A rect-table containing the location and size of the ellipse used to define the arc
///  * startAngle  - The starting angle of the arc, measured in degrees clockwise from the y-axis.
///  * endAngle    - The ending angle of the arc, measured in degrees clockwise from the y-axis.
///
/// Returns:
///  * An `hs.drawing` object, or nil if an error occurs
static int drawing_newEllipticalArc(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TTABLE,
                    LS_TNUMBER,
                    LS_TNUMBER,
                    LS_TBREAK];

    NSRect windowRect = [skin tableToRectAtIndex:1];
    CGFloat startAngle = lua_tonumber(L, 2) - 90 ;
    CGFloat endAngle   = lua_tonumber(L, 3) - 90 ;
    if (!isfinite(startAngle)) return luaL_argerror(L, 2, "start angle must be a finite number");
    if (!isfinite(endAngle))   return luaL_argerror(L, 3, "end angle must be a finite number");

    HSDrawingWindow *theWindow = [[HSDrawingWindow alloc] initWithContentRect:windowRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];

    if (theWindow) {
        drawing_t *drawingObject = lua_newuserdata(L, sizeof(drawing_t));
        memset(drawingObject, 0, sizeof(drawing_t));
        drawingObject->window = (__bridge_retained void*)theWindow;
        drawingObject->skipClose = NO ;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);

        HSDrawingViewEllipticalArc *theView = [[HSDrawingViewEllipticalArc alloc] initWithFrame:((NSView *)theWindow.contentView).bounds];
        [theView setLuaState:L];
        theWindow.contentView = theView;

        theView.startAngle = startAngle ;
        theView.endAngle   = endAngle ;

        if (!drawingWindows) {
            drawingWindows = [[NSMutableArray alloc] init];
        }
        [drawingWindows addObject:theWindow];
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.drawing.rectangle(sizeRect) -> drawingObject or nil
/// Constructor
/// Creates a new rectangle object
///
/// Parameters:
///  * sizeRect - A rect-table containing the location/size of the rectangle
///
/// Returns:
///  * An `hs.drawing` object, or nil if an error occurs
static int drawing_newRect(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TTABLE, LS_TBREAK];

    NSRect windowRect = [skin tableToRectAtIndex:1];

    HSDrawingWindow *theWindow = [[HSDrawingWindow alloc] initWithContentRect:windowRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];

    if (theWindow) {
        drawing_t *drawingObject = lua_newuserdata(L, sizeof(drawing_t));
        memset(drawingObject, 0, sizeof(drawing_t));
        drawingObject->window = (__bridge_retained void*)theWindow;
        drawingObject->skipClose = NO ;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);

        HSDrawingViewRect *theView = [[HSDrawingViewRect alloc] initWithFrame:((NSView *)theWindow.contentView).bounds];
        [theView setLuaState:L];

        theWindow.contentView = theView;

        if (!drawingWindows) {
            drawingWindows = [[NSMutableArray alloc] init];
        }
        [drawingWindows addObject:theWindow];
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.drawing.line(originPoint, endPoint) -> drawingObject or nil
/// Constructor
/// Creates a new line object
///
/// Parameters:
///  * originPoint - A point-table containing the co-ordinates of the starting point of the line
///  * endPoint - A point-table containing the co-ordinates of the end point of the line
///
/// Returns:
///  * An `hs.drawing` object, or nil if an error occurs
static int drawing_newLine(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TTABLE, LS_TTABLE, LS_TBREAK];

    NSRect windowRect;
    NSPoint origin = [skin tableToPointAtIndex:1];
    NSPoint end = [skin tableToPointAtIndex:2];

    // Calculate a rect that can contain both NSPoints
    windowRect.origin.x = MIN(origin.x, end.x);
    windowRect.origin.y = MIN(origin.y, end.y);
    windowRect.size.width = windowRect.origin.x + MAX(origin.x, end.x) - MIN(origin.x, end.x);
    windowRect.size.height = windowRect.origin.y + MAX(origin.y, end.y) - MIN(origin.y, end.y);
    //NSLog(@"newLine: Calculated window rect to bound lines: (%.1f,%.1f) %.1fx%.1f", windowRect.origin.x, windowRect.origin.y, windowRect.size.width, windowRect.size.height);

    HSDrawingWindow *theWindow = [[HSDrawingWindow alloc] initWithContentRect:windowRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];

    if (theWindow) {
        drawing_t *drawingObject = lua_newuserdata(L, sizeof(drawing_t));
        memset(drawingObject, 0, sizeof(drawing_t));
        drawingObject->window = (__bridge_retained void*)theWindow;
        drawingObject->skipClose = NO ;
       luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);

        HSDrawingViewLine *theView = [[HSDrawingViewLine alloc] initWithFrame:((NSView *)theWindow.contentView).bounds];
        [theView setLuaState:L];
        theWindow.contentView = theView;

        // Calculate the origin/end points of our line, within the frame of theView (since we were given screen co-ordinates)
        //NSLog(@"newLine: User specified a line as: (%.1f,%.1f) -> (%.1f,%.1f)", origin.x, origin.y, end.x, end.y);
        NSPoint tmpOrigin;
        NSPoint tmpEnd;

        tmpOrigin.x = origin.x - windowRect.origin.x;
        tmpOrigin.y = origin.y - windowRect.origin.y;

        tmpEnd.x = end.x - windowRect.origin.x;
        tmpEnd.y = end.y - windowRect.origin.y;

        theView.origin = tmpOrigin;
        theView.end = tmpEnd;
        //NSLog(@"newLine: Calculated view co-ordinates for line as: (%.1f,%.1f) -> (%.1f,%.1f)", theView.origin.x, theView.origin.y, theView.end.x, theView.end.y);

        if (!drawingWindows) {
            drawingWindows = [[NSMutableArray alloc] init];
        }
        [drawingWindows addObject:theWindow];
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.drawing.text(sizeRect, message) -> drawingObject or nil
/// Constructor
/// Creates a new text object
///
/// Parameters:
///  * sizeRect - A rect-table containing the location/size of the text
///  * message - A string containing the text to be displayed.   May also be any of the types supported by `hs.styledtext`.  See `hs.styledtext` for more details.
///
/// Returns:
///  * An `hs.drawing` object, or nil if an error occurs
static int drawing_newText(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TTABLE, LS_TANY, LS_TBREAK];

    NSRect windowRect = [skin tableToRectAtIndex:1];

    HSDrawingWindow *theWindow = [[HSDrawingWindow alloc] initWithContentRect:windowRect
                                                                    styleMask:NSBorderlessWindowMask
                                                                      backing:NSBackingStoreBuffered
                                                                        defer:YES];

    if (theWindow) {
        drawing_t *drawingObject = lua_newuserdata(L, sizeof(drawing_t));
        memset(drawingObject, 0, sizeof(drawing_t));
        drawingObject->window = (__bridge_retained void*)theWindow;
        drawingObject->skipClose = NO ;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);

        HSDrawingViewText *theView = [[HSDrawingViewText alloc] initWithFrame:((NSView *)theWindow.contentView).bounds];
        [theView setLuaState:L];

        theWindow.contentView = theView;
        [theView.textField setAttributedStringValue:[[LuaSkin shared] luaObjectAtIndex:2 toClass:"NSAttributedString"]] ;

        if (!drawingWindows) {
            drawingWindows = [[NSMutableArray alloc] init];
        }
        [drawingWindows addObject:theWindow];
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.drawing.image(sizeRect, imageData) -> drawingObject or nil
/// Constructor
/// Creates a new image object
///
/// Parameters:
///  * sizeRect - A rect-table containing the location/size of the image
///  * imageData - This can be either:
///   * An `hs.image` object
///   * A string containing a path to an image file
///   * A string beginning with `ASCII:` which signifies that the rest of the string is interpreted as a special form of ASCII diagram, which will be rendered to an image. See the notes below for information about the special format of ASCII diagram.
///
/// Returns:
///  * An `hs.drawing` object, or nil if an error occurs
///  * Paths relative to the PWD of Hammerspoon (typically ~/.hammerspoon/) will work, but paths relative to the UNIX homedir character, `~` will not
///  * Animated GIFs are supported. They're not super friendly on your CPU, but they work
///
/// Notes:
///  * To use the ASCII diagram image support, see http://cocoamine.net/blog/2015/03/20/replacing-photoshop-with-nsstring/ and be sure to preface your ASCII diagram with the special string `ASCII:`

// NOTE: THIS FUNCTION IS WRAPPED IN init.lua
static int drawing_newImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TTABLE, LS_TUSERDATA|LS_TSTRING, "hs.image", LS_TBREAK];

    NSRect windowRect = [skin tableToRectAtIndex:1];
    NSImage *theImage = [[LuaSkin shared] luaObjectAtIndex:2 toClass:"NSImage"];
    HSDrawingWindow *theWindow = [[HSDrawingWindow alloc] initWithContentRect:windowRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];

    if (theWindow) {
        drawing_t *drawingObject = lua_newuserdata(L, sizeof(drawing_t));
        memset(drawingObject, 0, sizeof(drawing_t));
        drawingObject->window = (__bridge_retained void*)theWindow;
        drawingObject->skipClose = NO ;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);

        HSDrawingViewImage *theView = [[HSDrawingViewImage alloc] initWithFrame:((NSView *)theWindow.contentView).bounds];
        [theView setLuaState:L];

        theWindow.contentView = theView;
        [theView setImage:theImage];

        if (!drawingWindows) {
            drawingWindows = [[NSMutableArray alloc] init];
        }
        [drawingWindows addObject:theWindow];
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.drawing:setText(message) -> drawingObject
/// Method
/// Sets the text of a drawing object
///
/// Parameters:
///  * message - A string containing the text to display
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be used on text drawing objects
///  * If the text of the drawing object is emptied (i.e. "") then style changes may be lost.  Use a placeholder such as a space (" ") or hide the object if style changes need to be saved but the text should disappear for a while.
static int drawing_setText(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingViewText *drawingView = (HSDrawingViewText *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewText class]]) {
        NSDictionary *attributes ;
        @try {
            attributes = [drawingView.textField.attributedStringValue attributesAtIndex:0 effectiveRange:nil] ;
        }
        @catch ( NSException *theException ) {
            attributes = @{NSParagraphStyleAttributeName:[NSParagraphStyle defaultParagraphStyle]} ;
        }

//         luaL_checkstring(L, 2) ;
//         lua_getglobal(L, "hs") ; lua_getfield(L, -1, "cleanUTF8forConsole") ; lua_remove(L, -2) ;
//         lua_pushvalue(L, 2) ;
//         lua_call(L, 1, 1) ;
        luaL_tolstring(L, 2, NULL) ;
//         drawingView.textField.attributedStringValue = [[NSAttributedString alloc] initWithString:[NSString stringWithUTF8String:luaL_checkstring(L, -1)] attributes:attributes];
        drawingView.textField.attributedStringValue = [[NSAttributedString alloc] initWithString:[[LuaSkin shared] toNSObjectAtIndex:-1] attributes:attributes];
        lua_pop(L, 1) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"hs.drawing:setText() can only be called on hs.drawing.text() objects, not: %@", NSStringFromClass([drawingView class])]];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:setStyledText(message) -> drawingObject
/// Method
/// Sets the text of a drawing object from an `hs.styledtext` object
///
/// Parameters:
///  * message - Any of the types supported by `hs.styledtext`.  See `hs.styledtext` for more details.
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be used on text drawing objects
static int drawing_setStyledText(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingViewText *drawingView = (HSDrawingViewText *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewText class]]) {
        [drawingView.textField setAttributedStringValue:[[LuaSkin shared] luaObjectAtIndex:2 toClass:"NSAttributedString"]] ;
    } else {
        return luaL_argerror(L, 1, "not an hs.drawing text object");
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:getStyledText() -> `hs.styledtext` object
/// Method
/// Gets the text of a drawing object as an `hs.styledtext` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * an `hs.styledtext` object
///
/// Notes:
///  * This method should only be used on text drawing objects
static int drawing_getStyledText(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingViewText *drawingView = (HSDrawingViewText *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewText class]]) {
        [[LuaSkin shared] pushNSObject:[drawingView.textField.attributedStringValue copy]] ;
    } else {
        return luaL_argerror(L, 1, "not an hs.drawing text object");
    }

    return 1;
}

NSDictionary *modifyTextStyleFromStack(lua_State *L, int idx, NSDictionary *defaultStuff) {
    NSFont                  *theFont  = [[defaultStuff objectForKey:@"font"] copy] ;
    NSMutableParagraphStyle *theStyle ;
    NSColor                 *theColor = [[defaultStuff objectForKey:@"color"] copy] ;
    NSFont *tmpFont;

    if (lua_istable(L, idx)) {
        if (lua_getfield(L, -1, "font")) {
            if (lua_type(L, -1) == LUA_TTABLE) {
                theFont = [[LuaSkin shared] luaObjectAtIndex:-1 toClass:"NSFont"] ;
            } else {
                CGFloat pointSize = theFont.pointSize;
                NSString *fontName = [NSString stringWithUTF8String:luaL_checkstring(L, -1)];
                tmpFont = [NSFont fontWithName:fontName size:pointSize];
                if (tmpFont) {
                    theFont = tmpFont;
                }
            }
        }
        lua_pop(L, 1);

        if (lua_getfield(L, -1, "size")) {
            CGFloat pointSize = lua_tonumber(L, -1);
            NSString *fontName = theFont.fontName;
            tmpFont = [NSFont fontWithName:fontName size:pointSize];
            if (tmpFont) {
                theFont = tmpFont;
            }
        }
        lua_pop(L, 1);

        if (lua_getfield(L, -1, "color")) {
            theColor = [[LuaSkin shared] luaObjectAtIndex:-1 toClass:"NSColor"] ;
        }
        lua_pop(L, 1);

        if (lua_getfield(L, -1, "paragraphStyle")) {
            theStyle = [[[LuaSkin shared] luaObjectAtIndex:-1 toClass:"NSParagraphStyle"] mutableCopy] ;
            lua_pop(L, 1) ;
        } else {
            lua_pop(L, 1) ;
            theStyle = [[defaultStuff objectForKey:@"style"] mutableCopy] ;
            if (lua_getfield(L, -1, "alignment")) {
                NSString *alignment = [NSString stringWithUTF8String:luaL_checkstring(L, -1)];
                if ([alignment isEqualToString:@"left"]) {
                    theStyle.alignment = NSLeftTextAlignment ;
                } else if ([alignment isEqualToString:@"right"]) {
                    theStyle.alignment = NSRightTextAlignment ;
                } else if ([alignment isEqualToString:@"center"]) {
                    theStyle.alignment = NSCenterTextAlignment ;
                } else if ([alignment isEqualToString:@"justified"]) {
                    theStyle.alignment = NSJustifiedTextAlignment ;
                } else if ([alignment isEqualToString:@"natural"]) {
                    theStyle.alignment = NSNaturalTextAlignment ;
                } else {
                    luaL_error(L, [[NSString stringWithFormat:@"invalid alignment for textStyle specified: %@", alignment] UTF8String]) ;
                    return nil ;
                }
            }
            lua_pop(L, 1);

            if (lua_getfield(L, -1, "lineBreak")) {
                NSString *lineBreak = [NSString stringWithUTF8String:luaL_checkstring(L, -1)];
                if ([lineBreak isEqualToString:@"wordWrap"]) {
                    theStyle.lineBreakMode = NSLineBreakByWordWrapping ;
                } else if ([lineBreak isEqualToString:@"charWrap"]) {
                    theStyle.lineBreakMode = NSLineBreakByCharWrapping ;
                } else if ([lineBreak isEqualToString:@"clip"]) {
                    theStyle.lineBreakMode = NSLineBreakByClipping ;
                } else if ([lineBreak isEqualToString:@"truncateHead"]) {
                    theStyle.lineBreakMode = NSLineBreakByTruncatingHead ;
                } else if ([lineBreak isEqualToString:@"truncateTail"]) {
                    theStyle.lineBreakMode = NSLineBreakByTruncatingTail ;
                } else if ([lineBreak isEqualToString:@"truncateMiddle"]) {
                    theStyle.lineBreakMode = NSLineBreakByTruncatingMiddle ;
                } else {
                    luaL_error(L, [[NSString stringWithFormat:@"invalid lineBreak for textStyle specified: %@", lineBreak] UTF8String]) ;
                    return nil ;
                }
            }
            lua_pop(L, 1);
        }

    } else {
        luaL_error(L, "invalid textStyle type specified: %s", lua_typename(L, -1)) ;
        return nil ;
    }

    return @{@"font":theFont, @"style":theStyle, @"color":theColor} ;
}

/// hs.drawing:setTextStyle([textStyle]) -> drawingObject
/// Method
/// Sets some simple style parameters for the entire text of a drawing object.  For more control over style including having multiple styles within a single text object, use `hs.styledtext` and `hs.drawing:setStyledText` instead.
///
/// Parameters:
///  * textStyle - an optional table containing one or more of the following keys to set for the text of the drawing object (if the table is nil or left out, the style is reset to the `hs.drawing` defaults):
///    * font      - the name of the font to use (default: the system font)
///    * size      - the font point size to use (default: 27.0)
///    * color     - a color table as described in `hs.drawing.color`
///    * alignment - a string of one of the following indicating the texts alignment within the drawing objects frame:
///      * "left"      - the text is visually left aligned.
///      * "right"     - the text is visually right aligned.
///      * "center"    - the text is visually center aligned.
///      * "justified" - the text is justified
///      * "natural"   - (default) the natural alignment of the text’s script
///    * lineBreak - a string of one of the following indicating how to wrap text which exceeds the drawing object's frame:
///      * "wordWrap"       - (default) wrap at word boundaries, unless the word itself doesn’t fit on a single line
///      * "charWrap"       - wrap before the first character that doesn’t fit
///      * "clip"           - do not draw past the edge of the drawing object frame
///      * "truncateHead"   - the line is displayed so that the end fits in the frame and the missing text at the beginning of the line is indicated by an ellipsis
///      * "truncateTail"   - the line is displayed so that the beginning fits in the frame and the missing text at the end of the line is indicated by an ellipsis
///      * "truncateMiddle" - the line is displayed so that the beginning and end fit in the frame and the missing text in the middle is indicated by an ellipsis
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be used on text drawing objects
///  * If the text of the drawing object is currently empty (i.e. "") then style changes may be lost.  Use a placeholder such as a space (" ") or hide the object if style changes need to be saved but the text should disappear for a while.
///  * Only the keys specified are changed.  To reset an object to all of its defaults, call this method with an explicit nil as its only parameter (e.g. `hs.drawing:setTextStyle(nil)`
///  * The font, font size, and font color can also be set by their individual specific methods as well; this method is provided so that style components can be stored and applied collectively, as well as used by `hs.drawing.getTextDrawingSize()` to determine the proper rectangle size for a textual drawing object.
static int drawing_setTextStyle(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingViewText *drawingView = (HSDrawingViewText *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewText class]]) {
        NSTextField             *theTextField = drawingView.textField ;
        NSString                *theText = [[NSString alloc] initWithString:[theTextField.attributedStringValue string]] ;
// if text is empty, throws NSRangeException... where else might it?
        NSMutableDictionary     *attributes ;
        @try {
            attributes = [[theTextField.attributedStringValue attributesAtIndex:0 effectiveRange:nil] mutableCopy] ;
        }
        @catch ( NSException *theException ) {
            attributes = [@{NSParagraphStyleAttributeName:[NSParagraphStyle defaultParagraphStyle]} mutableCopy] ;
//            [[LuaSkin shared] logWarn:@"-- unable to retrieve current style for text; reverting to defaults"] ;
        }

        NSMutableParagraphStyle *style = [[attributes objectForKey:NSParagraphStyleAttributeName] mutableCopy] ;
        if (!style) style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy] ;

        if (lua_isnoneornil(L, 2)) {
            // defaults in the HSDrawingViewText initWithFrame: definition
            [theTextField setFont: [NSFont systemFontOfSize: 27]];
            [theTextField setTextColor: [NSColor colorWithCalibratedWhite:1.0 alpha:1.0]];
            [attributes setValue:[NSParagraphStyle defaultParagraphStyle] forKey:NSParagraphStyleAttributeName] ;
            theTextField.attributedStringValue = [[NSAttributedString alloc] initWithString:theText
                                                                                 attributes:attributes];
        } else {
            NSDictionary *myStuff = modifyTextStyleFromStack(L, 2, @{
                                        @"font" :theTextField.font,
                                        @"style":style,
                                        @"color":theTextField.textColor
                                    }) ;
            [theTextField setFont: [myStuff objectForKey:@"font"]];
            [theTextField setTextColor: [myStuff objectForKey:@"color"]];
            [attributes setValue:[myStuff objectForKey:@"style"] forKey:NSParagraphStyleAttributeName] ;
            theTextField.attributedStringValue = [[NSAttributedString alloc] initWithString:theText
                                                                                 attributes:attributes];
        }

    } else {
        return luaL_argerror(L, 1, "not an hs.drawing text object");
    }

    lua_pushvalue(L, 1);
    return 1;
}


/// hs.drawing:setTopLeft(point) -> drawingObject
/// Method
/// Moves the drawingObject to a given point
///
/// Parameters:
///  * point - A point-table containing the absolute co-ordinates the drawing object should be moved to
///
/// Returns:
///  * The drawing object
static int drawing_setTopLeft(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView   *drawingView   = (HSDrawingView *)drawingWindow.contentView;

    NSPoint windowLoc ;

    switch (lua_type(L, 2)) {
        case LUA_TTABLE:
            lua_getfield(L, 2, "x");
            windowLoc.x = lua_tonumber(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, 2, "y");
            windowLoc.y = lua_tonumber(L, -1);
            lua_pop(L, 1);

            break;
        default:
            [skin logBreadcrumb:[NSString stringWithFormat:@"ERROR: Unexpected type passed to hs.drawing:setTopLeft(): %d", lua_type(L, 2)]];
            lua_pushnil(L);
            return 1;
    }

    windowLoc.y=[[NSScreen screens][0] frame].size.height - windowLoc.y ;
    [drawingWindow setFrameTopLeftPoint:windowLoc] ;
    drawingView.needsDisplay = YES;

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:setSize(size) -> drawingObject
/// Method
/// Resizes a drawing object
///
/// Parameters:
///  * size - A size-table containing the width and height the drawing object should be resized to
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * If this is called on an `hs.drawing.text` object, only its window will be resized. If you also want to change the font size, use `:setTextSize()`
static int drawing_setSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView   *drawingView   = (HSDrawingView *)drawingWindow.contentView;

    NSSize windowSize;
    switch (lua_type(L, 2)) {
        case LUA_TTABLE:
            lua_getfield(L, 2, "h");
            windowSize.height = lua_tonumber(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, 2, "w");
            windowSize.width = lua_tonumber(L, -1);
            lua_pop(L, 1);

            break;
        default:
            [skin logBreadcrumb:[NSString stringWithFormat:@"ERROR: Unexpected type passed to hs.drawing:setSize(): %d", lua_type(L, 2)]];
            lua_pushnil(L);
            return 1;
    }

    NSRect oldFrame = drawingWindow.frame;
    NSRect newFrame = NSMakeRect(oldFrame.origin.x, oldFrame.origin.y + oldFrame.size.height - windowSize.height, windowSize.width, windowSize.height);

    if (!CGRectContainsRect(CGRectMake((CGFloat)INT_MIN, (CGFloat)INT_MIN, (CGFloat)INT_MAX - (CGFloat)INT_MIN, (CGFloat)INT_MAX - (CGFloat)INT_MIN), newFrame)) {
        [skin logError:@"hs.drawing:setSize() called with invalid size"];
        lua_pushvalue(L, 1);
        return 1;
    }

    [drawingWindow setFrame:newFrame display:YES animate:NO];

    if ([drawingView isKindOfClass:[HSDrawingViewText class]]) {
        [((HSDrawingViewText *) drawingView).textField setFrameSize:windowSize];
    } else if ([drawingView isKindOfClass:[HSDrawingViewImage class]]) {
        [((HSDrawingViewImage *) drawingView).HSImageView setFrameSize:windowSize];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:clippingRectangle([rect | nil]) -> drawingObject or current value
/// Method
/// Set the screen area in which the drawing contents are visible.
///
/// Parameters:
///  * rect - an optional rectangle specifying the visible area of the screen where the drawing's contents are visible.  If an explicit `nil` is specified, no clipping rectangle is set.  Defaults to nil
///
/// Returns:
///  * if an argument is provided, returns the drawing object; otherwise the current value is returned.
///
/// Notes:
///  * This method can be used to specify the area of the display where this drawing should be visible.  If any portion of the drawing extends beyond this rectangle, the image is clipped so that only the portion within this rectangle is visible.
///  * The rectangle defined by this method is independant of the drawing's actual frame -- if you move the drawing with [hs.drawing:setFrame](#setFrame) or [hs.drawing:setTopLeft](#setTopLeft), this rectangle retains its current value.
///
///  * This method does not work for image objects at present.
static int drawing_clippingRectangle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;

    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if (lua_gettop(L) == 1) {
        if (drawingView.clipToRect) {
            [skin pushNSRect:drawingView.rectClippingBoundry] ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        if (lua_type(L, 2) == LUA_TNIL) {
            drawingView.clipToRect = NO ;
        } else {
            NSRect clippingRect = [skin tableToRectAtIndex:2] ;
            drawingView.rectClippingBoundry = clippingRect ;
            drawingView.clipToRect = YES ;
        }
        drawingView.needsDisplay = YES;
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

/// hs.drawing:setFrame(rect) -> drawingObject
/// Method
/// Sets the frame of the drawingObject in absolute coordinates
///
/// Parameters:
///  * rect - A rect-table containing the co-ordinates and size that should be applied to the drawingObject
///
/// Returns:
///  * The drawing object
static int drawing_setFrame(lua_State *L) {
    drawing_setSize(L)    ; lua_pop(L, 1);
    drawing_setTopLeft(L) ; lua_pop(L, 1);
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:frame() -> hs.geometry object
/// Method
/// Gets the frame of a drawingObject in absolute coordinates
///
/// Parameters:
///  * None
///
/// Returns:
///  * An `hs.geometry` object containing the frame of the drawing object
static int drawing_getFrame(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    NSRect windowFrame = drawingWindow.frame;

    windowFrame.origin.y = [[NSScreen screens][0] frame].size.height - windowFrame.origin.y - windowFrame.size.height;

    [skin pushNSRect:windowFrame];
    return 1;
}

/// hs.drawing:setTextFont(fontname) -> drawingObject
/// Method
/// Sets the default font for a drawing object
///
/// Parameters:
///  * fontname - A string containing the name of the font to use
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be used on text drawing objects
///  * This method changes the font for portions of an `hs.drawing` text object which do not have a specific font set in their attributes list (see `hs.styledtext` for more details).
static int drawing_setTextFont(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingViewText *drawingView = (HSDrawingViewText *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewText class]]) {
        CGFloat pointSize = drawingView.textField.font.pointSize;
        NSString *fontName = [NSString stringWithUTF8String:luaL_checkstring(L, 2)];
        [drawingView.textField setFont:[NSFont fontWithName:fontName size:pointSize]];
    } else {
        return luaL_argerror(L, 1, "not an hs.drawing text object");
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:setTextSize(size) -> drawingObject
/// Method
/// Sets the default text size for a drawing object
///
/// Parameters:
///  * size - A number containing the font size to use
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be used on text drawing objects
///  * This method changes the font size for portions of an `hs.drawing` text object which do not have a specific font set in their attributes list (see `hs.styledtext` for more details).
static int drawing_setTextSize(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingViewText *drawingView = (HSDrawingViewText *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewText class]]) {
        CGFloat pointSize = lua_tonumber(L, 2);
        NSString *fontName = drawingView.textField.font.fontName;
        [drawingView.textField setFont:[NSFont fontWithName:fontName size:pointSize]];
    } else {
        return luaL_argerror(L, 1, "not an hs.drawing text object");
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:setTextColor(color) -> drawingObject
/// Method
/// Sets the default text color for a drawing object
///
/// Parameters:
///  * color - a color table as described in `hs.drawing.color`
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be called on text drawing objects
///  * This method changes the font color for portions of an `hs.drawing` text object which do not have a specific font set in their attributes list (see `hs.styledtext` for more details).
static int drawing_setTextColor(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    NSColor *textColor = [[LuaSkin shared] luaObjectAtIndex:2 toClass:"NSColor"] ;

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingViewText *drawingView = (HSDrawingViewText *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewText class]]) {
        [drawingView.textField setTextColor:textColor];
    } else {
        return luaL_argerror(L, 1, "not an hs.drawing text object");
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:setFillColor(color) -> drawingObject
/// Method
/// Sets the fill color of a drawing object
///
/// Parameters:
///  * color - a color table as described in `hs.drawing.color`
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be used on rectangle, circle, or arc drawing objects
///  * Calling this method will remove any gradient fill colors previously set with `hs.drawing:setFillGradient()`
static int drawing_setFillColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    drawing_t *drawingObject = get_item_arg(L, 1);
    NSColor *fillColor = [[LuaSkin shared] luaObjectAtIndex:2 toClass:"NSColor"] ;

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewRect class]] ||
        [drawingView isKindOfClass:[HSDrawingViewCircle class]] ||
        [drawingView isKindOfClass:[HSDrawingViewEllipticalArc class]]) {
        drawingView.HSFillColor = fillColor;
        drawingView.HSGradientStartColor = nil;
        drawingView.HSGradientEndColor = nil;
        drawingView.HSGradientAngle = 0;

        drawingView.needsDisplay = YES;
    } else {
        [skin logError:[NSString stringWithFormat:@"hs.drawing:setFillColor() can only be called on hs.drawing.rectangle(), hs.drawing.circle() or hs.drawing.arc() objects, not: %@", NSStringFromClass([drawingView class])]];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:setArcAngles(startAngle, endAngle) -> drawingObject
/// Method
/// Changes the starting and ending angles for an arc drawing object
///
/// Parameters:
///  * startAngle  - The starting angle of the arc, measured in degrees clockwise from the y-axis.
///  * endAngle    - The ending angle of the arc, measured in degrees clockwise from the y-axis.
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be used on arc drawing objects
static int drawing_setArcAngles(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TNUMBER, LS_TBREAK] ;
    drawing_t *drawingObject = get_item_arg(L, 1);

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewEllipticalArc class]]) {
        ((HSDrawingViewEllipticalArc *)drawingView).startAngle = lua_tonumber(L, 2) - 90 ;
        ((HSDrawingViewEllipticalArc *)drawingView).endAngle   = lua_tonumber(L, 3) - 90 ;

        drawingView.needsDisplay = YES;
    } else {
        [skin logError:[NSString stringWithFormat:@"hs.drawing:setArcAngles() can only be called on hs.drawing.arc() objects, not: %@", NSStringFromClass([drawingView class])]];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:setFillGradient(startColor, endColor, angle) -> drawingObject
/// Method
/// Sets the fill gradient of a drawing object
///
/// Parameters:
///  * startColor - A table containing color component values between 0.0 and 1.0 for each of the keys:
///    * red (default 0.0)
///    * green (default 0.0)
///    * blue (default 0.0)
///    * alpha (default 1.0)
///  * endColor - A table containing color component values between 0.0 and 1.0 for each of the keys:
///    * red (default 0.0)
///    * green (default 0.0)
///    * blue (default 0.0)
///    * alpha (default 1.0)
///  * angle - A number representing the angle of the gradient, measured in degrees, counter-clockwise, from the left of the drawing object
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be used on rectangle, circle, or arc drawing objects
///  * Calling this method will remove any fill color previously set with `hs.drawing:setFillColor()`
static int drawing_setFillGradient(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    drawing_t *drawingObject = get_item_arg(L, 1);
    NSColor *startColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;
    NSColor *endColor = [skin luaObjectAtIndex:3 toClass:"NSColor"] ;
    int angle = (int)lua_tointeger(L, 4);

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewRect class]] ||
        [drawingView isKindOfClass:[HSDrawingViewCircle class]] ||
        [drawingView isKindOfClass:[HSDrawingViewEllipticalArc class]]) {
        drawingView.HSFillColor = nil;
        drawingView.HSGradientStartColor = startColor;
        drawingView.HSGradientEndColor = endColor;
        drawingView.HSGradientAngle = angle;

        drawingView.needsDisplay = YES;
    } else {
        [skin logError:[NSString stringWithFormat:@"hs.drawing:setFillGradient() can only be called on hs.drawing.rectangle(), hs.drawing.circle() or hs.drawing.arc() objects, not: %@", NSStringFromClass([drawingView class])]];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:setStrokeColor(color) -> drawingObject
/// Method
/// Sets the stroke color of a drawing object
///
/// Parameters:
///  * color - a color table as described in `hs.drawing.color`
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be used on line, rectangle, circle, or arc drawing objects
static int drawing_setStrokeColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    drawing_t *drawingObject = get_item_arg(L, 1);
    NSColor *strokeColor = [skin luaObjectAtIndex:2 toClass:"NSColor"] ;

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewRect class]] ||
        [drawingView isKindOfClass:[HSDrawingViewCircle class]] ||
        [drawingView isKindOfClass:[HSDrawingViewLine class]] ||
        [drawingView isKindOfClass:[HSDrawingViewEllipticalArc class]]) {
        drawingView.HSStrokeColor = strokeColor;
        drawingView.needsDisplay = YES;
    } else {
        [skin logError:[NSString stringWithFormat:@"hs.drawing:setStrokeColor() can only be called on hs.drawing.rectangle(), hs.drawing.circle(), hs.drawing.line() or hs.drawing.arc() objects, not: %@", NSStringFromClass([drawingView class])]];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:setRoundedRectRadii(xradius, yradius) -> drawingObject
/// Method
/// Sets the radii of the corners of a rectangle drawing object
///
/// Parameters:
///  * xradius - A number containing the radius of each corner along the x-axis
///  * yradius - A number containing the radius of each corner along the y-axis
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be used on rectangle drawing objects
///  * If either radius value is greater than half the width/height (as appropriate) of the rectangle, the value will be clamped at half the width/height
///  * If either (or both) radius values are 0, the rectangle will be drawn without rounded corners
static int drawing_setRoundedRectRadii(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    drawing_t *drawingObject = get_item_arg(L, 1);
    CGFloat xradius = lua_tonumber(L, 2);
    CGFloat yradius = lua_tonumber(L, 3);

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewRect class]]) {
        drawingView.HSRoundedRectXRadius = xradius;
        drawingView.HSRoundedRectYRadius = yradius;

        drawingView.needsDisplay = YES;
    } else {
        [skin logError:[NSString stringWithFormat:@"hs.drawing:setRoundedRectRadii() can only be called on hs.drawing.rectangle() objects, not: %@", NSStringFromClass([drawingView class])]];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:setFill(doFill) -> drawingObject
/// Method
/// Sets whether or not to fill a drawing object
///
/// Parameters:
///  * doFill - A boolean, true to fill the drawing object, false to not fill
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be used on line, rectangle, circle, or arc drawing objects
static int drawing_setFill(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    drawing_t *drawingObject = get_item_arg(L, 1);

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewRect class]] ||
        [drawingView isKindOfClass:[HSDrawingViewCircle class]] ||
        [drawingView isKindOfClass:[HSDrawingViewLine class]] ||
        [drawingView isKindOfClass:[HSDrawingViewEllipticalArc class]]) {
        drawingView.HSFill = (BOOL)lua_toboolean(L, 2);
        drawingView.needsDisplay = YES;
    } else {
        [skin logError:[NSString stringWithFormat:@"hs.drawing:setFill() can only be called on hs.drawing.rectangle(), hs.drawing.circle(), hs.drawing.line() or hs.drawing.arc() objects, not: %@", NSStringFromClass([drawingView class])]];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:setStroke(doStroke) -> drawingObject
/// Method
/// Sets whether or not to stroke a drawing object
///
/// Parameters:
///  * doStroke - A boolean, true to stroke the drawing object, false to not stroke
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be used on line, rectangle, circle, or arc drawing objects
static int drawing_setStroke(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    drawing_t *drawingObject = get_item_arg(L, 1);

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewRect class]] ||
        [drawingView isKindOfClass:[HSDrawingViewCircle class]] ||
        [drawingView isKindOfClass:[HSDrawingViewLine class]] ||
        [drawingView isKindOfClass:[HSDrawingViewEllipticalArc class]]) {
        drawingView.HSStroke = (BOOL)lua_toboolean(L, 2);
        drawingView.needsDisplay = YES;
    } else {
        [skin logError:[NSString stringWithFormat:@"hs.drawing:setStroke() can only be called on hs.drawing.rectangle(), hs.drawing.circle(), hs.drawing.line() or hs.drawing.arc() objects, not: %@", NSStringFromClass([drawingView class])]];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:setStrokeWidth(width) -> drawingObject
/// Method
/// Sets the stroke width of a drawing object
///
/// Parameters:
///  * width - A number containing the width in points to stroke a drawing object
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be used on line, rectangle, circle, or arc drawing objects
static int drawing_setStrokeWidth(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    drawing_t *drawingObject = get_item_arg(L, 1);

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewRect class]] ||
        [drawingView isKindOfClass:[HSDrawingViewCircle class]] ||
        [drawingView isKindOfClass:[HSDrawingViewLine class]] ||
        [drawingView isKindOfClass:[HSDrawingViewEllipticalArc class]]) {
        drawingView.HSLineWidth = lua_tonumber(L, 2);
        drawingView.needsDisplay = YES;
    } else {
        [skin logError:[NSString stringWithFormat:@"hs.drawing:setStrokeWidth() can only be called on hs.drawing.rectangle(), hs.drawing.circle(), hs.drawing.line() or hs.drawing.arc() objects, not: %@", NSStringFromClass([drawingView class])]];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:setImage(image) -> drawingObject
/// Method
/// Sets the image of a drawing object
///
/// Parameters:
///  * image - An `hs.image` object
///
/// Returns:
///  * The drawing object
static int drawing_setImage(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    drawing_t *drawingObject = get_item_arg(L, 1);
    NSImage *image = [[LuaSkin shared] luaObjectAtIndex:2 toClass:"NSImage"];

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingViewImage *drawingView = (HSDrawingViewImage *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewImage class]]) {
        [drawingView setImage:image];
    } else {
        [skin logError:[NSString stringWithFormat:@"hs.drawing:setImage() can only be called on hs.drawing.image() objects, not: %@", NSStringFromClass([drawingView class])]];
    }

    lua_pushvalue(L, 1);
    return 1;
}


/// hs.drawing:rotateImage(angle) -> drawingObject
/// Method
/// Rotates an image clockwise around its center
///
/// Parameters:
///  * angle - the angle in degrees to rotate the image around its center in a clockwise direction.
///
/// Returns:
///  * The drawing object
///
/// Notes:
/// * This method works by rotating the image view within its drawing window.  This means that an image which completely fills its viewing area will most likely be cropped in some places.  Best results are achieved with images that have clear space around their edges or with `hs.drawing.imageScaling` set to "none".
static int drawing_rotate(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK] ;
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewImage class]]) {
        [drawingView setFrameCenterRotation:(360.0 - lua_tonumber(L, 2))] ;
    } else {
        [skin logError:[NSString stringWithFormat:@"hs.drawing:rotateImage() can only be called on hs.drawing.image() objects, not: %@", NSStringFromClass([drawingView class])]];
    }

    lua_pushvalue(L, 1);
    return 1;

}

/// hs.drawing:imageScaling([type]) -> drawingObject or current value
/// Method
/// Get or set how an image is scaled within the frame of a drawing object containing an image.
///
/// Parameters:
///  * type - an optional string value which should match one of the following (default is scaleProportionally):
///    * shrinkToFit         - shrink the image, preserving the aspect ratio, to fit the drawing frame only if the image is larger than the drawing frame.
///    * scaleToFit          - shrink or expand the image to fully fill the drawing frame.  This does not preserve the aspect ratio.
///    * none                - perform no scaling or resizing of the image.
///    * scalePropertionally - shrink or expand the image to fully fill the drawing frame, preserving the aspect ration.
///
/// Returns:
///  * If a setting value is provided, the drawing object is returned; if no argument is provided, the current setting is returned.
static int drawing_scaleImage(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG,
                                LS_TSTRING | LS_TOPTIONAL,
                                LS_TBREAK] ;
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingViewImage *drawingView = (HSDrawingViewImage *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewImage class]]) {
        if (lua_type(L, 2) != LUA_TNONE) {
            NSString *arg = [[LuaSkin shared] toNSObjectAtIndex:2] ;
            if      ([arg isEqualToString:@"shrinkToFit"])         { drawingView.HSImageView.imageScaling = NSImageScaleProportionallyDown ; }
            else if ([arg isEqualToString:@"scaleToFit"])          { drawingView.HSImageView.imageScaling = NSImageScaleAxesIndependently ; }
            else if ([arg isEqualToString:@"none"])                { drawingView.HSImageView.imageScaling = NSImageScaleNone ; }
            else if ([arg isEqualToString:@"scaleProportionally"]) { drawingView.HSImageView.imageScaling = NSImageScaleProportionallyUpOrDown ; }
            else { return luaL_error(L, ":imageAlignment unrecognized alignment specified") ; }
            lua_settop(L, 1) ;
        } else {
            switch(drawingView.HSImageView.imageScaling) {
                case NSImageScaleProportionallyDown:      lua_pushstring(L, "shrinkToFit") ; break ;
                case NSImageScaleAxesIndependently:       lua_pushstring(L, "scaleToFit") ; break ;
                case NSImageScaleNone:                    lua_pushstring(L, "none") ; break ;
                case NSImageScaleProportionallyUpOrDown:  lua_pushstring(L, "scaleProportionally") ; break ;
                default:                                  lua_pushstring(L, "unknown") ; break ;
            }
        }
    } else {
        return luaL_error(L, ":scaleImage() called on an hs.drawing object that isn't an image object");
    }
    return 1 ;
}

/// hs.drawing:imageAnimates([flag]) -> drawingObject or current value
/// Method
/// Get or set whether or not an animated GIF image should cycle through its animation.
///
/// Parameters:
///  * flag - an optional boolean flag indicating whether or not an animated GIF image should cycle through its animation.  Defaults to true.
///
/// Returns:
///  * If a setting value is provided, the drawing object is returned; if no argument is provided, the current setting is returned.
static int drawing_imageAnimates(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG,
                                LS_TBOOLEAN | LS_TOPTIONAL,
                                LS_TBREAK] ;
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingViewImage *drawingView = (HSDrawingViewImage *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewImage class]]) {
        if (lua_type(L, 2) != LUA_TNONE) {
            drawingView.HSImageView.animates = (BOOL)lua_toboolean(L, 2) ;
            lua_settop(L, 1) ;
        } else {
            lua_pushboolean(L, drawingView.HSImageView.animates) ;
        }
    } else {
        return luaL_error(L, ":imageAnimates() called on an hs.drawing object that isn't an image object");
    }
    return 1 ;
}

/// hs.drawing:imageFrame([type]) -> drawingObject or current value
/// Method
/// Get or set what type of frame should be around the drawing frame of the image.
///
/// Parameters:
///  * type - an optional string value which should match one of the following (default is none):
///    * none   - no frame is drawing around the drawingObject's frameRect
///    * photo  - a thin black outline with a white background and a dropped shadow.
///    * bezel  - a gray, concave bezel with no background that makes the image look sunken.
///    * groove - a thin groove with a gray background that looks etched around the image.
///    * button - a convex bezel with a gray background that makes the image stand out in relief, like a button.
///
/// Returns:
///  * If a setting value is provided, the drawing object is returned; if no argument is provided, the current setting is returned.
///
/// Notes:
///  * Apple considers the photo, groove, and button style frames "stylistically obsolete" and if a frame is required, recommend that you use the bezel style or draw your own to more closely match the OS look and feel.
static int drawing_frameStyle(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG,
                                LS_TSTRING | LS_TOPTIONAL,
                                LS_TBREAK] ;
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingViewImage *drawingView = (HSDrawingViewImage *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewImage class]]) {
        if (lua_type(L, 2) != LUA_TNONE) {
            NSString *arg = [[LuaSkin shared] toNSObjectAtIndex:2] ;
            if      ([arg isEqualToString:@"none"])   { drawingView.HSImageView.imageFrameStyle = NSImageFrameNone ; }
            else if ([arg isEqualToString:@"photo"])  { drawingView.HSImageView.imageFrameStyle = NSImageFramePhoto ; }
            else if ([arg isEqualToString:@"bezel"])  { drawingView.HSImageView.imageFrameStyle = NSImageFrameGrayBezel ; }
            else if ([arg isEqualToString:@"groove"]) { drawingView.HSImageView.imageFrameStyle = NSImageFrameGroove ; }
            else if ([arg isEqualToString:@"button"]) { drawingView.HSImageView.imageFrameStyle = NSImageFrameButton ; }
            else { return luaL_error(L, ":frameStyle unrecognized frame specified") ; }
            lua_settop(L, 1) ;
        } else {
            switch(drawingView.HSImageView.imageFrameStyle) {
                case NSImageFrameNone:      lua_pushstring(L, "none") ; break ;
                case NSImageFramePhoto:     lua_pushstring(L, "photo") ; break ;
                case NSImageFrameGrayBezel: lua_pushstring(L, "bezel") ; break ;
                case NSImageFrameGroove:    lua_pushstring(L, "groove") ; break ;
                case NSImageFrameButton:    lua_pushstring(L, "button") ; break ;
                default:                    lua_pushstring(L, "unknown") ; break ;
            }
        }
    } else {
        return luaL_error(L, ":frameStyle() called on an hs.drawing object that isn't an image object");
    }
    return 1 ;
}

/// hs.drawing:imageAlignment([type]) -> drawingObject or current value
/// Method
/// Get or set the alignment of an image that doesn't fully fill the drawing objects frame.
///
/// Parameters:
///  * type - an optional string value which should match one of the following (default is center):
///    * topLeft      - the image's top left corner will match the drawing frame's top left corner
///    * top          - the image's top match the drawing frame's top and will be centered horizontally
///    * topRight     - the image's top right corner will match the drawing frame's top right corner
///    * left         - the image's left side will match the drawing frame's left side and will be centered vertically
///    * center       - the image will be centered vertically and horizontally within the drawing frame
///    * right        - the image's right side will match the drawing frame's right side and will be centered vertically
///    * bottomLeft   - the image's bottom left corner will match the drawing frame's bottom left corner
///    * bottom       - the image's bottom match the drawing frame's bottom and will be centered horizontally
///    * bottomRight  - the image's bottom right corner will match the drawing frame's bottom right corner
///
/// Returns:
///  * If a setting value is provided, the drawing object is returned; if no argument is provided, the current setting is returned.
static int drawing_imageAlignment(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG,
                                LS_TSTRING | LS_TOPTIONAL,
                                LS_TBREAK] ;
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingViewImage *drawingView = (HSDrawingViewImage *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewImage class]]) {
        if (lua_type(L, 2) != LUA_TNONE) {
            NSString *arg = [[LuaSkin shared] toNSObjectAtIndex:2] ;
            if      ([arg isEqualToString:@"center"])      { drawingView.HSImageView.imageAlignment = NSImageAlignCenter ; }
            else if ([arg isEqualToString:@"top"])         { drawingView.HSImageView.imageAlignment = NSImageAlignTop ; }
            else if ([arg isEqualToString:@"topLeft"])     { drawingView.HSImageView.imageAlignment = NSImageAlignTopLeft ; }
            else if ([arg isEqualToString:@"topRight"])    { drawingView.HSImageView.imageAlignment = NSImageAlignTopRight ; }
            else if ([arg isEqualToString:@"left"])        { drawingView.HSImageView.imageAlignment = NSImageAlignLeft ; }
            else if ([arg isEqualToString:@"bottom"])      { drawingView.HSImageView.imageAlignment = NSImageAlignBottom ; }
            else if ([arg isEqualToString:@"bottomLeft"])  { drawingView.HSImageView.imageAlignment = NSImageAlignBottomLeft ; }
            else if ([arg isEqualToString:@"bottomRight"]) { drawingView.HSImageView.imageAlignment = NSImageAlignBottomRight ; }
            else if ([arg isEqualToString:@"right"])       { drawingView.HSImageView.imageAlignment = NSImageAlignRight ; }
            else { return luaL_error(L, ":imageAlignment unrecognized alignment specified") ; }
            lua_settop(L, 1) ;
        } else {
            switch(drawingView.HSImageView.imageAlignment) {
                case NSImageAlignCenter:      lua_pushstring(L, "center") ; break ;
                case NSImageAlignTop:         lua_pushstring(L, "top") ; break ;
                case NSImageAlignTopLeft:     lua_pushstring(L, "topLeft") ; break ;
                case NSImageAlignTopRight:    lua_pushstring(L, "topRight") ; break ;
                case NSImageAlignLeft:        lua_pushstring(L, "left") ; break ;
                case NSImageAlignBottom:      lua_pushstring(L, "bottom") ; break ;
                case NSImageAlignBottomLeft:  lua_pushstring(L, "bottomLeft") ; break ;
                case NSImageAlignBottomRight: lua_pushstring(L, "bottomRight") ; break ;
                case NSImageAlignRight:       lua_pushstring(L, "right") ; break ;
                default:                      lua_pushstring(L, "unknown") ; break ;
            }
        }
    } else {
        return luaL_error(L, ":imageAlignment() called on an hs.drawing object that isn't an image object");
    }
    return 1 ;
}

/// hs.drawing:clickCallbackActivating([false]) -> drawingObject or current value
/// Method
/// Get or set whether or not clicking on a drawing with a click callback defined should bring all of Hammerspoon's open windows to the front.
///
/// Parameters:
///  * flag - an optional boolean indicating whether or not clicking on a drawing with a click callback function defined should activate Hammerspoon and bring its windows forward.  Defaults to true.
///
/// Returns:
///  * If a setting value is provided, the drawing object is returned; if no argument is provided, the current setting is returned.
///
/// Notes:
///  * Setting this to false changes a drawing object's AXsubrole value and may affect the results of filters defined for hs.window.filter, depending upon how they are defined.
static int drawing_clickCallbackActivating(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG,
                                LS_TBOOLEAN | LS_TOPTIONAL,
                                LS_TBREAK] ;
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;

    if (lua_type(L, 2) != LUA_TNONE) {
        if (lua_toboolean(L, 2))
            drawingWindow.styleMask &= (unsigned long)~NSNonactivatingPanelMask ;
        else
            drawingWindow.styleMask |= NSNonactivatingPanelMask ;
        lua_settop(L, 1) ;
    } else {
        lua_pushboolean(L, ((drawingWindow.styleMask & NSNonactivatingPanelMask) != NSNonactivatingPanelMask)) ;
    }

    return 1;
}



/// hs.drawing:setClickCallback(mouseUpFn, mouseDownFn) -> drawingObject
/// Method
/// Sets a callback for mouseUp and mouseDown click events
///
/// Parameters:
///  * mouseUpFn - A function, can be nil, that will be called when the drawing object is clicked on and the mouse button is released. If this argument is nil, any existing callback is removed.
///  * mouseDownFn - A function, can be nil, that will be called when the drawing object is clicked on and the mouse button is first pressed down. If this argument is nil, any existing callback is removed.
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * No distinction is made between the left, right, or other mouse buttons -- they all invoke the same up or down function.  If you need to determine which specific button was pressed, use `hs.eventtap.checkMouseButtons()` within your callback to check.
static int drawing_setClickCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];

    drawing_t *drawingObject = get_item_arg(L, 1);

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if (lua_type(L, 2) == LUA_TNIL || lua_type(L, 2) == LUA_TFUNCTION) {
        // We're either removing a callback, or setting a new one. Either way, we want to make clear out any callback that exists
        [drawingView setMouseUpCallback:[skin luaUnref:refTable ref:drawingView.mouseUpCallbackRef]];

        // Set a new callback if we have a function
        if (lua_type(L, 2) == LUA_TFUNCTION) {
            lua_pushvalue(L, 2);
            [drawingView setMouseUpCallback:[skin luaRef:refTable]];
        }
    } else {
        [skin logError:@"hs.drawing:setClickCallback() mouseUp argument must be a function or nil"];
    }

    if (lua_type(L, 3) == LUA_TNONE || lua_type(L, 3) == LUA_TNIL || lua_type(L, 3) == LUA_TFUNCTION) {
        // We're either removing a callback, or setting a new one. Either way, we want to make clear out any callback that exists
        [drawingView setMouseDownCallback:[skin luaUnref:refTable ref:drawingView.mouseDownCallbackRef]];

        // Set a new callback if we have a function
        if (lua_type(L, 3) == LUA_TFUNCTION) {
            lua_pushvalue(L, 3);
            [drawingView setMouseDownCallback:[skin luaRef:refTable]];
        }
    } else {
        [skin logError:@"hs.drawing:setClickCallback() mouseDown argument must be a function or nil, or entirely absent"];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:show([fadeInTime]) -> drawingObject
/// Method
/// Displays the drawing object
///
/// Parameters:
///  * fadeInTime - An optional number of seconds over which to fade in the drawing object. Defaults to zero
///
/// Returns:
///  * The drawing object
static int drawing_show(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    NSTimeInterval fadeTime = 0.f;

    if (lua_type(L, 2) == LUA_TNUMBER) {
        fadeTime = lua_tonumber(L, 2);
    }
    if (fadeTime > 0) {
        [(__bridge HSDrawingWindow *)drawingObject->window fadeInAndMakeKeyAndOrderFront:fadeTime];
    } else {
        [(__bridge HSDrawingWindow *)drawingObject->window makeKeyAndOrderFront:nil];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:hide([fadeOutTime]) -> drawingObject
/// Method
/// Hides the drawing object
///
/// Parameters:
///  * fadeOut - An optional number of seconds over which to fade out the drawing object. Defaults to zero
///
/// Returns:
///  * The drawing object
static int drawing_hide(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    NSTimeInterval fadeTime = 0.f;

    if (lua_type(L, 2) == LUA_TNUMBER) {
        fadeTime = lua_tonumber(L, 2);
    }

    if (fadeTime > 0) {
        [(__bridge HSDrawingWindow *)drawingObject->window fadeOutAndOrderOut:fadeTime];
    } else {
        [(__bridge HSDrawingWindow *)drawingObject->window orderOut:nil];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:delete()
/// Method
/// Destroys the drawing object
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * This method immediately destroys the drawing object. If you want it to fade out, use `:hide()` first, with some suitable time, and `hs.timer.doAfter()` to schedule the `:delete()` call
static int drawing_delete(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge_transfer HSDrawingWindow *)drawingObject->window;
    HSDrawingView *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if (drawingView.mouseUpCallbackRef != LUA_NOREF) {
        [drawingView setMouseUpCallback:[skin luaUnref:refTable ref:drawingView.mouseUpCallbackRef]];
    }
    if (drawingView.mouseDownCallbackRef != LUA_NOREF) {
        [drawingView setMouseDownCallback:[skin luaUnref:refTable ref:drawingView.mouseDownCallbackRef]];
    }

    [drawingWindows removeObject:drawingWindow];

    if (!drawingObject->skipClose) [drawingWindow close];
    drawingWindow = nil;
    drawingObject->window = nil;
    drawingObject = nil;

    return 0;
}

/// hs.drawing:bringToFront([aboveEverything]) -> drawingObject
/// Method
/// Places the drawing object on top of normal windows
///
/// Parameters:
///  * aboveEverything - An optional boolean value that controls how far to the front the drawing should be placed. `true` to place the drawing on top of all windows (including the dock and menubar), `false` to place the drawing above normal windows, but below the dock and menubar. Defaults to `false`.
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * As of macOS Sierra and later, if you want a `hs.drawing` object to appear above full-screen windows you must hide the Hammerspoon Dock icon first using: `hs.dockicon.hide()`
static int drawing_bringToFront(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    if (!lua_isnoneornil(L, 2) && lua_toboolean(L, 2) == 1) {
        [drawingWindow setLevelScreenSaver];
    } else {
        [drawingWindow setLevelTop];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:sendToBack() -> drawingObject
/// Method
/// Places the drawing object behind normal windows, between the desktop wallpaper and desktop icons
///
/// Parameters:
///  * None
///
/// Returns:
///  * The drawing object
static int drawing_sendToBack(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    [drawingWindow setLevelBottom];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:alpha() -> number
/// Method
/// Get the alpha level of the window containing the hs.drawing object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The current alpha level for the hs.drawing object
static int getAlpha(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;

    lua_pushnumber(L, [drawingWindow alphaValue]) ;
    return 1 ;
}

/// hs.drawing:setAlpha(level) -> object
/// Method
/// Sets the alpha level of the window containing the hs.drawing object.
///
/// Parameters:
///  * level - the alpha level (0.0 - 1.0) to set the object to
///
/// Returns:
///  * The `hs.drawing` object
static int setAlpha(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    drawing_t *drawingObject = get_item_arg(L, 1);
    CGFloat newLevel = luaL_checknumber(L, 2);
    if ((newLevel < 0.0) || (newLevel > 1.0)) {
        [skin logError:@"hs.drawing:setAlpha() level must be between 0.0 and 1.0"];
    } else {
        HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
        [drawingWindow setAlphaValue:newLevel] ;
    }

    lua_settop(L, 1);
    return 1 ;
}

/// hs.drawing:orderAbove([object2]) -> object
/// Method
/// Moves drawing object above drawing object2, or all drawing objects in the same presentation level, if object2 is not provided.
///
/// Parameters:
///  * Optional drawing object to place the drawing object above.
///
/// Returns:
///  * The `hs.drawing` object
static int orderAbove(lua_State *L) {
    drawing_t *object1 = get_item_arg(L, 1);
    HSDrawingWindow *window1 = (__bridge HSDrawingWindow *)object1->window;
    NSInteger window2 ;

    if lua_isnone(L,2) {
        window2 = 0 ;
    } else {
        drawing_t *object2 = get_item_arg(L, 2);
        window2 = [(__bridge HSDrawingWindow *)object2->window windowNumber];
    }

    [window1 orderWindow:NSWindowAbove relativeTo:window2] ;

    lua_settop(L, 1);
    return 1 ;
}

/// hs.drawing:orderBelow([object2]) -> object1
/// Method
/// Moves drawing object below drawing object2, or all drawing objects in the same presentation level, if object2 is not provided.
///
/// Parameters:
///  * Optional drawing object to place the drawing object below.
///
/// Returns:
///  * The `hs.drawing` object
static int orderBelow(lua_State *L) {
    drawing_t *object1 = get_item_arg(L, 1);
    HSDrawingWindow *window1 = (__bridge HSDrawingWindow *)object1->window;
    NSInteger window2 ;

    if lua_isnone(L,2) {
        window2 = 0 ;
    } else {
        drawing_t *object2 = get_item_arg(L, 2);
        window2 = [(__bridge HSDrawingWindow *)object2->window windowNumber];
    }

    [window1 orderWindow:NSWindowBelow relativeTo:window2] ;

    lua_settop(L, 1);
    return 1 ;
}

/// hs.drawing.windowBehaviors[]
/// Constant
/// Array of window behavior labels for determining how an hs.drawing object is handled in Spaces and Exposé
///
/// * default           -- The window can be associated to one space at a time.
/// * canJoinAllSpaces  -- The window appears in all spaces. The menu bar behaves this way.
/// * moveToActiveSpace -- Making the window active does not cause a space switch; the window switches to the active space.
///
/// Only one of these may be active at a time:
///
/// * managed           -- The window participates in Spaces and Exposé. This is the default behavior if windowLevel is equal to NSNormalWindowLevel.
/// * transient         -- The window floats in Spaces and is hidden by Exposé. This is the default behavior if windowLevel is not equal to NSNormalWindowLevel.
/// * stationary        -- The window is unaffected by Exposé; it stays visible and stationary, like the desktop window.
///
/// Notes:
///  * This table has a __tostring() metamethod which allows listing it's contents in the Hammerspoon console by typing `hs.drawing.windowBehaviors`.

// the following don't apply to hs.drawing objects, but may become useful if we decide to add support for more traditional window creation in HS.
//
// /// Only one of these may be active at a time:
// ///
// /// * participatesInCycle -- The window participates in the window cycle for use with the Cycle Through Windows Window menu item.
// /// * ignoresCycle        -- The window is not part of the window cycle for use with the Cycle Through Windows Window menu item.
// ///
// /// Only one of these may be active at a time:
// ///
// /// * fullScreenPrimary   -- A window with this collection behavior has a fullscreen button in the upper right of its titlebar.
// /// * fullScreenAuxiliary -- Windows with this collection behavior can be shown on the same space as the fullscreen window.

static int pushCollectionTypeTable(lua_State *L) {
    lua_newtable(L) ;
        lua_pushinteger(L, NSWindowCollectionBehaviorDefault) ;             lua_setfield(L, -2, "default") ;
        lua_pushinteger(L, NSWindowCollectionBehaviorCanJoinAllSpaces) ;    lua_setfield(L, -2, "canJoinAllSpaces") ;
        lua_pushinteger(L, NSWindowCollectionBehaviorMoveToActiveSpace) ;   lua_setfield(L, -2, "moveToActiveSpace") ;
        lua_pushinteger(L, NSWindowCollectionBehaviorManaged) ;             lua_setfield(L, -2, "managed") ;
        lua_pushinteger(L, NSWindowCollectionBehaviorTransient) ;           lua_setfield(L, -2, "transient") ;
        lua_pushinteger(L, NSWindowCollectionBehaviorStationary) ;          lua_setfield(L, -2, "stationary") ;
//         lua_pushinteger(L, NSWindowCollectionBehaviorParticipatesInCycle) ; lua_setfield(L, -2, "participatesInCycle") ;
//         lua_pushinteger(L, NSWindowCollectionBehaviorIgnoresCycle) ;        lua_setfield(L, -2, "ignoresCycle") ;
//         lua_pushinteger(L, NSWindowCollectionBehaviorFullScreenPrimary) ;   lua_setfield(L, -2, "fullScreenPrimary") ;
//         lua_pushinteger(L, NSWindowCollectionBehaviorFullScreenAuxiliary) ; lua_setfield(L, -2, "fullScreenAuxiliary") ;
    return 1 ;
}

/// hs.drawing.windowLevels
/// Constant
/// A table of predefined window levels usable with `hs.drawing:setLevel(...)`
///
/// Predefined levels are:
///  * _MinimumWindowLevelKey - lowest allowed window level
///  * desktop
///  * desktopIcon            - `hs.drawing:sendToBack()` is equivalent to this - 1
///  * normal                 - normal application windows
///  * tornOffMenu
///  * floating               - equivalent to `hs.drawing:bringToFront(false)`, where "Always Keep On Top" windows are usually set
///  * modalPanel             - modal alert dialog
///  * utility
///  * dock                   - level of the Dock
///  * mainMenu               - level of the Menubar
///  * status
///  * popUpMenu              - level of a menu when displayed (open)
///  * overlay
///  * help
///  * dragging
///  * screenSaver            - equivalent to `hs.drawing:bringToFront(true)`
///  * assistiveTechHigh
///  * cursor
///  * _MaximumWindowLevelKey - highest allowed window level
///
/// Notes:
///  * This table has a __tostring() metamethod which allows listing it's contents in the Hammerspoon console by typing `hs.drawing.windowLevels`.
///  * These key names map to the constants used in CoreGraphics to specify window levels and may not actually be used for what the name might suggest. For example, tests suggest that an active screen saver actually runs at a level of 2002, rather than at 1000, which is the window level corresponding to kCGScreenSaverWindowLevelKey.
///  * Each drawing level is sorted separately and `hs.drawing:orderAbove(...)` and hs.drawing:orderBelow(...)` only arrange windows within the same level.
///  * If you use Dock hiding (or in 10.11, Menubar hiding) please note that when the Dock (or Menubar) is popped up, it is done so with an implicit orderAbove, which will place it above any items you may also draw at the Dock (or MainMenu) level.
///
///  * A drawing object with a [hs.drawing:setClickCallback](#setClickCallback) function can only reliably receive mouse click events when its window level is at `hs.drawing.windowLevels.desktopIcon` + 1 or higher.
static int cg_windowLevels(lua_State *L) {
    lua_newtable(L) ;
//       lua_pushinteger(L, CGWindowLevelForKey(kCGBaseWindowLevelKey)) ;              lua_setfield(L, -2, "kCGBaseWindowLevelKey") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGMinimumWindowLevelKey)) ;           lua_setfield(L, -2, "_MinimumWindowLevelKey") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDesktopWindowLevelKey)) ;           lua_setfield(L, -2, "desktop") ;
//       lua_pushinteger(L, CGWindowLevelForKey(kCGBackstopMenuLevelKey)) ;            lua_setfield(L, -2, "kCGBackstopMenuLevelKey") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGNormalWindowLevelKey)) ;            lua_setfield(L, -2, "normal") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGFloatingWindowLevelKey)) ;          lua_setfield(L, -2, "floating") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGTornOffMenuWindowLevelKey)) ;       lua_setfield(L, -2, "tornOffMenu") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDockWindowLevelKey)) ;              lua_setfield(L, -2, "dock") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGMainMenuWindowLevelKey)) ;          lua_setfield(L, -2, "mainMenu") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGStatusWindowLevelKey)) ;            lua_setfield(L, -2, "status") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGModalPanelWindowLevelKey)) ;        lua_setfield(L, -2, "modalPanel") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGPopUpMenuWindowLevelKey)) ;         lua_setfield(L, -2, "popUpMenu") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDraggingWindowLevelKey)) ;          lua_setfield(L, -2, "dragging") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGScreenSaverWindowLevelKey)) ;       lua_setfield(L, -2, "screenSaver") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGMaximumWindowLevelKey)) ;           lua_setfield(L, -2, "_MaximumWindowLevelKey") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGOverlayWindowLevelKey)) ;           lua_setfield(L, -2, "overlay") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGHelpWindowLevelKey)) ;              lua_setfield(L, -2, "help") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGUtilityWindowLevelKey)) ;           lua_setfield(L, -2, "utility") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGDesktopIconWindowLevelKey)) ;       lua_setfield(L, -2, "desktopIcon") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGCursorWindowLevelKey)) ;            lua_setfield(L, -2, "cursor") ;
      lua_pushinteger(L, CGWindowLevelForKey(kCGAssistiveTechHighWindowLevelKey)) ; lua_setfield(L, -2, "assistiveTechHigh") ;
//       lua_pushinteger(L, CGWindowLevelForKey(kCGNumberOfWindowLevelKeys)) ;         lua_setfield(L, -2, "kCGNumberOfWindowLevelKeys") ;
    return 1 ;
}

/// hs.drawing:setLevel(theLevel) -> drawingObject
/// Method
/// Sets the window level more precisely than sendToBack and bringToFront.
///
/// Parameters:
///  * theLevel - the level specified as a number or as a string where this object should be drawn.  If it is a string, it must match one of the keys in `hs.drawing.windowLevels`.
///
/// Returns:
///  * the drawing object
///
/// Notes:
///  * see the notes for `hs.drawing.windowLevels`
///  * These levels may be unable to explicitly place drawing objects around full-screen macOS windows
static int drawing_setLevel(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    lua_Integer targetLevel ;

    if (lua_type(L, 2) == LUA_TNUMBER) {
        targetLevel = lua_tointeger(L, 2) ;
    } else if (lua_type(L, 2) == LUA_TSTRING) {
        cg_windowLevels(L) ;
        if (lua_getfield(L, -1, lua_tostring(L, 2)) != LUA_TNIL) {
            targetLevel = lua_tointeger(L, -1) ;
        } else {
            return luaL_error(L, [[NSString stringWithFormat:@"unrecognized window level: %s", lua_tostring(L, 2)] UTF8String]) ;
        }
        lua_pop(L, 2) ; // the result and the table
    } else {
        return luaL_error(L, "string or integer window level expected") ;
    }

    if (targetLevel >= CGWindowLevelForKey(kCGMinimumWindowLevelKey) && targetLevel <= CGWindowLevelForKey(kCGMaximumWindowLevelKey)) {
        [drawingWindow setLevel:targetLevel] ;
    } else {
        return luaL_error(L, [[NSString stringWithFormat:@"window level must be between %d and %d inclusive",
                                        CGWindowLevelForKey(kCGMinimumWindowLevelKey),
                                        CGWindowLevelForKey(kCGMaximumWindowLevelKey)] UTF8String]) ;
    }

    lua_settop(L, 1) ;
    return 1 ;
}


/// hs.drawing:behavior() -> number
/// Method
/// Returns the current behavior of the hs.drawing object with respect to Spaces and Exposé for the object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The numeric representation of the current behaviors for the hs.drawing object
static int getBehavior(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;

    lua_pushinteger(L, [drawingWindow collectionBehavior]) ;

    return 1 ;
}

/// hs.drawing:setBehavior(behavior) -> object
/// Method
/// Sets the window behaviors represented by the number provided for the window containing the hs.drawing object.
///
/// Parameters:
///  * behavior - the numeric representation of the behaviors to set for the window of the object
///
/// Returns:
///  * The `hs.drawing` object
static int setBehavior(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    NSInteger newLevel = luaL_checkinteger(L, 2);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    @try {
        [drawingWindow setCollectionBehavior:(NSWindowCollectionBehavior)newLevel] ;
    }
    @catch ( NSException *theException ) {
        return luaL_error(L, "%s, %s", [[theException name] UTF8String], [[theException reason] UTF8String]) ;
    }

    lua_settop(L, 1);
    return 1 ;
}

/// hs.drawing.defaultTextStyle() -> `hs.styledtext` attributes table
/// Function
/// Returns a table containing the default font, size, color, and paragraphStyle used by `hs.drawing` for text drawing objects.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing the default style attributes `hs.drawing` uses for text drawing objects in the `hs.styledtext` attributes table format.
///
/// Notes:
///  * This method returns the default font, size, color, and paragraphStyle used by `hs.drawing` for text objects.  If you modify a drawing object's defaults with `hs.drawing:setColor`, `hs.drawing:setTextFont`, or `hs.drawing:setTextSize`, the changes will not be reflected by this function.
static int default_textAttributes(lua_State *L) {
    lua_newtable(L) ;
// NOTE: Change this if you change the defaults in [HSDrawingViewText initWithFrame:]
      [[LuaSkin shared] pushNSObject:[NSFont systemFontOfSize: 27]] ;                    lua_setfield(L, -2, "font") ;
      [[LuaSkin shared] pushNSObject:[NSColor colorWithCalibratedWhite:1.0 alpha:1.0]] ; lua_setfield(L, -2, "color") ;
      [[LuaSkin shared] pushNSObject:[NSParagraphStyle defaultParagraphStyle]] ;         lua_setfield(L, -2, "paragraphStyle") ;
    return 1 ;
}

/// hs.drawing.getTextDrawingSize(styledTextObject or theText, [textStyle]) -> sizeTable | nil
/// Function
/// Get the size of the rectangle necessary to fully render the text with the specified style so that is will be completely visible.
///
/// Parameters:
///  * styledTextObject - an object created with the hs.styledtext module or its table representation (see `hs.styledtext`).
///
///  The following simplified style format is supported for use with `hs.drawing:setText` and `hs.drawing.setTextStyle`.
///
///  * theText   - the text which is to be displayed.
///  * textStyle - a table containing one or more of the following keys to set for the text of the drawing object (if textStyle is nil or missing, the `hs.drawing` defaults are used):
///    * font      - the name of the font to use (default: the system font)
///    * size      - the font point size to use (default: 27.0)
///    * color     - ignored, but accepted for compatibility with `hs.drawing:setTextStyle()`
///    * alignment - a string of one of the following indicating the texts alignment within the drawing objects frame:
///      * "left"      - the text is visually left aligned.
///      * "right"     - the text is visually right aligned.
///      * "center"    - the text is visually center aligned.
///      * "justified" - the text is justified
///      * "natural"   - (default) the natural alignment of the text’s script
///    * lineBreak - a string of one of the following indicating how to wrap text which exceeds the drawing object's frame:
///      * "wordWrap"       - (default) wrap at word boundaries, unless the word itself doesn’t fit on a single line
///      * "charWrap"       - wrap before the first character that doesn’t fit
///      * "clip"           - do not draw past the edge of the drawing object frame
///      * "truncateHead"   - the line is displayed so that the end fits in the frame and the missing text at the beginning of the line is indicated by an ellipsis
///      * "truncateTail"   - the line is displayed so that the beginning fits in the frame and the missing text at the end of the line is indicated by an ellipsis
///      * "truncateMiddle" - the line is displayed so that the beginning and end fit in the frame and the missing text in the middle is indicated by an ellipsis
///
/// Returns:
///  * sizeTable - a table containing the Height and Width necessary to fully display the text drawing object, or nil if an error occurred
///
/// Notes:
///  * This function assumes the default values specified for any key which is not included in the provided textStyle.
///  * The size returned is an approximation and may return a width that is off by about 4 points.  Use the returned size as a minimum starting point. Sometimes using the "clip" or "truncateMiddle" lineBreak modes or "justified" alignment will fit, but its safest to add in your own buffer if you have the space in your layout.
///  * Multi-line text (separated by a newline or return) is supported.  The height will be for the multiple lines and the width returned will be for the longest line.
static int drawing_getTextDrawingSize(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TANY, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;

    NSSize theSize ;
    switch(lua_type(L, 1)) {
        case LUA_TSTRING:
        case LUA_TNUMBER: {
                NSString *theText  = [NSString stringWithUTF8String:lua_tostring(L, 1)];

                if (lua_isnoneornil(L, 2)) {
                    if (lua_isnil(L, 2)) lua_remove(L, 2) ;
                    lua_pushcfunction(L, default_textAttributes) ; lua_call(L, 0, 1) ;
                }

                NSDictionary *myStuff = modifyTextStyleFromStack(L, 2, @{
                                            @"style":[NSParagraphStyle defaultParagraphStyle],
                                            @"font" :[NSFont systemFontOfSize: 27],
                                            @"color":[NSColor colorWithCalibratedWhite:1.0 alpha:1.0]
                                        });
                if (!myStuff) {
                    lua_pushnil(L);
                    return 1;
                }

                theSize = [theText sizeWithAttributes:@{
                              NSFontAttributeName:[myStuff objectForKey:@"font"],
                    NSParagraphStyleAttributeName:[myStuff objectForKey:@"style"]
                }] ;
            } break ;
        case LUA_TUSERDATA:
        case LUA_TTABLE:  {
                NSAttributedString *theText = [[LuaSkin shared] luaObjectAtIndex:1 toClass:"NSAttributedString"] ;
                theSize = [theText size] ;
            } break ;
        default:
            return luaL_argerror(L, 1, "string or hs.styledtext object expected") ;
    }

    lua_newtable(L) ;
        lua_pushnumber(L, ceil(theSize.height)) ; lua_setfield(L, -2, "h") ;
        lua_pushnumber(L, ceil(theSize.width)) ; lua_setfield(L, -2, "w") ;

    return 1 ;
}

/// hs.drawing:wantsLayer([flag]) -> object or boolean
/// Method
/// Gets or sets whether or not the drawing object should be rendered by the view or by Core Animation.
///
/// Parameters:
///  * flag - optional boolean (default false) which indicates whether the drawing object should be rendered by the containing view (false) or by the Core Animation interface (true).
///
/// Returns:
///  * if `flag` is provided, then returns the drawing object; otherwise returns the current value
///
/// Notes:
///  * This method can help smooth the display or small text objects on non-Retina monitors.
static int drawing_wantsLayer(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, "hs.drawing",
                                LS_TBOOLEAN | LS_TOPTIONAL,
                                LS_TBREAK] ;

    drawing_t       *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView   *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if (lua_type(L, 2) != LUA_TNONE) {
        [drawingView setWantsLayer:(BOOL)lua_toboolean(L, 2)];
        lua_pushvalue(L, 1) ;
    } else
        lua_pushboolean(L, (BOOL)[drawingView wantsLayer]) ;

    return 1;
}

// Trying to make this as close to paste and apply as possible, so not all aspects may apply
// to each module... you may still need to tweak for your specific module.

static int userdata_tostring(lua_State* L) {

// For older modules that don't use this macro, Change this:
#ifndef USERDATA_TAG
#define USERDATA_TAG "hs.drawing"
#endif

// can't assume, since some older modules and userdata share __index
    void *self = lua_touserdata(L, 1) ;
    if (self) {
// Change these to get the desired title, if available, for your module:
        drawing_t *drawingObject = get_item_arg(L, 1);
        HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
        HSDrawingView   *drawingView   = (HSDrawingView *)drawingWindow.contentView;

        NSString* title = @"unknown type";
        if ([drawingView isKindOfClass:[HSDrawingViewRect class]])          title = @"rectangle" ;
        if ([drawingView isKindOfClass:[HSDrawingViewCircle class]])        title = @"circle" ;
        if ([drawingView isKindOfClass:[HSDrawingViewEllipticalArc class]]) title = @"arc" ;
        if ([drawingView isKindOfClass:[HSDrawingViewLine class]])          title = @"line" ;
        if ([drawingView isKindOfClass:[HSDrawingViewText class]])          title = @"text" ;
        if ([drawingView isKindOfClass:[HSDrawingViewImage class]])         title = @"image" ;

// Use this instead, if you always want the title portion empty for your module
//        NSString* title = @"" ;

// Common code begins here:

       lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)] UTF8String]) ;
    } else {
// For modules which share the same __index for the module table and the userdata objects, this replicates
// current default, which treats the module as a table when checking for __tostring.  You could also put a fancier
// string here for your module and set userdata_tostring as the module's __tostring as well...
//
// See lauxlib.c -- luaL_tolstring would invoke __tostring and loop, so let's
// use its output for tables (the "default:" case in luaL_tolstring's switch)
        lua_pushfstring(L, "%s: %p", luaL_typename(L, 1), lua_topointer(L, 1));
    }
    return 1 ;
}

// Lua metadata

static const luaL_Reg drawinglib[] = {
    {"circle",             drawing_newCircle},
    {"ellipticalArc",      drawing_newEllipticalArc},
    {"rectangle",          drawing_newRect},
    {"line",               drawing_newLine},
    {"text",               drawing_newText},
    {"_image",             drawing_newImage},
    {"getTextDrawingSize", drawing_getTextDrawingSize},
    {"defaultTextStyle",   default_textAttributes},
    {"disableScreenUpdates", disableUpdates},
    {"enableScreenUpdates", enableUpdates},

    {NULL,                 NULL}
};

static const luaL_Reg drawing_metalib[] = {
    {"wantsLayer",          drawing_wantsLayer},
    {"setStroke", drawing_setStroke},
    {"setStrokeWidth", drawing_setStrokeWidth},
    {"setStrokeColor", drawing_setStrokeColor},
    {"setRoundedRectRadii", drawing_setRoundedRectRadii},
    {"setFill", drawing_setFill},
    {"setFillColor", drawing_setFillColor},
    {"setFillGradient", drawing_setFillGradient},
    {"setTextColor", drawing_setTextColor},
    {"setTextSize", drawing_setTextSize},
    {"setTextFont", drawing_setTextFont},
    {"setText", drawing_setText},
    {"setImage", drawing_setImage},
    {"setClickCallback", drawing_setClickCallback},
    {"bringToFront", drawing_bringToFront},
    {"sendToBack", drawing_sendToBack},
    {"show", drawing_show},
    {"hide", drawing_hide},
    {"delete", drawing_delete},
    {"setTopLeft", drawing_setTopLeft},
    {"setSize", drawing_setSize},
    {"setFrame", drawing_setFrame},
    {"frame", drawing_getFrame},
    {"setAlpha", setAlpha},
    {"setLevel", drawing_setLevel},
    {"alpha", getAlpha},
    {"orderAbove", orderAbove},
    {"orderBelow", orderBelow},
    {"setBehavior", setBehavior},
    {"behavior", getBehavior},
    {"setTextStyle", drawing_setTextStyle},
    {"imageScaling", drawing_scaleImage},
    {"imageAnimates", drawing_imageAnimates},
    {"imageFrame", drawing_frameStyle},
    {"imageAlignment", drawing_imageAlignment},
    {"rotateImage", drawing_rotate},
    {"clickCallbackActivating", drawing_clickCallbackActivating},
    {"setStyledText", drawing_setStyledText},
    {"getStyledText", drawing_getStyledText},
    {"setArcAngles", drawing_setArcAngles},
    {"clippingRectangle", drawing_clippingRectangle},

    {"__tostring", userdata_tostring},
    {"__gc", drawing_delete},
    {NULL, NULL}
};

int luaopen_hs_drawing_internal(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:drawinglib metaFunctions:nil objectFunctions:drawing_metalib];

    pushCollectionTypeTable(L);
    lua_setfield(L, -2, "windowBehaviors") ;

    cg_windowLevels(L) ;
    lua_setfield(L, -2, "windowLevels") ;

    return 1;
}
