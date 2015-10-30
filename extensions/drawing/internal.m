#import "drawing.h"

/// === hs.drawing ===
///
/// Primitives for drawing on the screen in various ways

// Useful definitions
#define USERDATA_TAG "hs.drawing"
#define get_item_arg(L, idx) ((drawing_t *)luaL_checkudata(L, idx, USERDATA_TAG))

int refTable;

NSMutableArray *drawingWindows;

// Objective-C class interface implementations
@implementation HSDrawingWindow
- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger __unused)windowStyle backing:(NSBackingStoreType __unused)bufferingType defer:(BOOL __unused)deferCreation {
    //CLS_NSLOG(@"HSDrawingWindow::initWithContentRect contentRect:(%.1f,%.1f) %.1fx%.1f", contentRect.origin.x, contentRect.origin.y, contentRect.size.width, contentRect.size.height);

    if (!isfinite(contentRect.origin.x) || !isfinite(contentRect.origin.y) || !isfinite(contentRect.size.height) || !isfinite(contentRect.size.width)) {
        LuaSkin *skin = [LuaSkin shared];
        showError(skin.L, "ERROR: hs.drawing object created with non-finite co-ordinates/size");
        return nil;
    }

    self = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask
                                                    backing:NSBackingStoreBuffered defer:YES];
    if (self) {
        [self setDelegate:self];
        contentRect.origin.y=[[NSScreen screens][0] frame].size.height - contentRect.origin.y - contentRect.size.height;
        //CLS_NSLOG(@"HSDrawingWindow::initWithContentRect corrected for bottom-left origin.y to %.1f", contentRect.origin.y);

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
    //CLS_NSLOG(@"HSDrawingWindow::windowShouldClose");
    return NO;
}
@end

@implementation HSDrawingView
- (id)initWithFrame:(NSRect)frameRect {
    //CLS_NSLOG(@"HSDrawingView::initWithFrame frameRect:(%.1f,%.1f) %.1fx%.1f", frameRect.origin.x, frameRect.origin.y, frameRect.size.width, frameRect.size.height);
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
        lua_State *_L = skin.L;
        [skin pushLuaRef:refTable ref:self.mouseUpCallbackRef];
        if (![skin protectedCallAndTraceback:0 nresults:0]) {
            const char *errorMsg = lua_tostring(_L, -1);
            CLS_NSLOG(@"%s", errorMsg);
            showError(_L, (char *)errorMsg);
        }
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
        lua_State *_L = skin.L;
        [skin pushLuaRef:refTable ref:self.mouseDownCallbackRef];
        if (![skin protectedCallAndTraceback:0 nresults:0]) {
            const char *errorMsg = lua_tostring(_L, -1);
            CLS_NSLOG(@"%s", errorMsg);
            showError(_L, (char *)errorMsg);
        }
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
    //CLS_NSLOG(@"HSDrawingViewCircle::drawRect");
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
        [circlePath stroke];
    }

    // Restore the context to what it was before we messed with it
    [gc restoreGraphicsState];
}
@end

@implementation HSDrawingViewRect
- (void)drawRect:(NSRect)rect {
    //CLS_NSLOG(@"HSDrawingViewRect::drawRect");
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
        [rectPath stroke];
    }

    // Restore the context to what it was before we messed with it
    [gc restoreGraphicsState];
}
@end

@implementation HSDrawingViewLine
- (id)initWithFrame:(NSRect)frameRect {
    //CLS_NSLOG(@"HSDrawingViewLine::initWithFrame");
    self = [super initWithFrame:frameRect];
    if (self) {
        self.origin = CGPointZero;
        self.end = CGPointZero;
    }
    return self;
}

- (void)drawRect:(NSRect __unused)rect {
    //CLS_NSLOG(@"HSDrawingViewLine::drawRect");
    // Get the graphics context that we are currently executing under
    NSGraphicsContext* gc = [NSGraphicsContext currentContext];

    // Save the current graphics context settings
    [gc saveGraphicsState];

    // Set the color in the current graphics context for future draw operations
    [[self HSStrokeColor] setStroke];

    // Create our line path. We do this by placing the line from the origin point to the end point
    NSBezierPath* linePath = [NSBezierPath bezierPath];
    linePath.lineWidth = self.HSLineWidth;

    //CLS_NSLOG(@"HSDrawingViewLine::drawRect: Rendering line from (%.1f,%.1f) to (%.1f,%.1f)", self.origin.x, self.origin.y, self.end.x, self.end.y);
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
    //CLS_NSLOG(@"HSDrawingViewText::initWithFrame");
    self = [super initWithFrame:frameRect];
    if (self) {
// NOTE: Change default_textAttributes(...) and drawing_getTextDrawingSize(...) if you change these
        NSTextField *theTextField = [[NSTextField alloc] initWithFrame:frameRect];
        [theTextField setFont: [NSFont systemFontOfSize: 27]];
        [theTextField setTextColor: [NSColor colorWithCalibratedWhite:1.0 alpha:1.0]];
        [theTextField setDrawsBackground: NO];
        [theTextField setBordered: NO];
        [theTextField setEditable: NO];
        [theTextField setSelectable: NO];
        [self addSubview:theTextField];
        self.textField = theTextField;
    }
    return self;
}
@end

@implementation HSDrawingViewImage
- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.HSImageView = [[NSImageView alloc] initWithFrame:frameRect];
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

// Lua API implementation

/// hs.drawing.circle(sizeRect) -> drawingObject or nil
/// Constructor
/// Creates a new circle object
///
/// Parameters:
///  * sizeRect - A rect-table containing the location/size of the circle
///
/// Returns:
///  * An `hs.drawing` circle object, or nil if an error occurs
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

/// hs.drawing.rectangle(sizeRect) -> drawingObject or nil
/// Constructor
/// Creates a new rectangle object
///
/// Parameters:
///  * sizeRect - A rect-table containing the location/size of the rectangle
///
/// Returns:
///  * An `hs.drawing` rectangle object, or nil if an error occurs
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
///  * An `hs.drawing` line object, or nil if an error occurs
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
    //CLS_NSLOG(@"newLine: Calculated window rect to bound lines: (%.1f,%.1f) %.1fx%.1f", windowRect.origin.x, windowRect.origin.y, windowRect.size.width, windowRect.size.height);

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
        //CLS_NSLOG(@"newLine: User specified a line as: (%.1f,%.1f) -> (%.1f,%.1f)", origin.x, origin.y, end.x, end.y);
        NSPoint tmpOrigin;
        NSPoint tmpEnd;

        tmpOrigin.x = origin.x - windowRect.origin.x;
        tmpOrigin.y = origin.y - windowRect.origin.y;

        tmpEnd.x = end.x - windowRect.origin.x;
        tmpEnd.y = end.y - windowRect.origin.y;

        theView.origin = tmpOrigin;
        theView.end = tmpEnd;
        //CLS_NSLOG(@"newLine: Calculated view co-ordinates for line as: (%.1f,%.1f) -> (%.1f,%.1f)", theView.origin.x, theView.origin.y, theView.end.x, theView.end.y);

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
///  * An `hs.drawing` text object, or nil if an error occurs
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
///  * An `hs.drawing` image object, or nil if an error occurs
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
///  * message - A string containing the text to display.  May also be any of the types supported by `hs.styledtext`.  See `hs.styledtext` for more details.
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be used on text drawing objects
static int drawing_setText(lua_State *L) {
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

/// hs.drawing:getText() -> `hs.styledtext` object
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
static int drawing_getText(lua_State *L) {
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
/// This method is deprecated.  Use the `hs.styledtext` module to set the text and style and apply it with `hs.drawing:setText` instead.
///
/// Sets the style parameters for the text of a drawing object.
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
// NOTE: if text is empty, throws NSRangeException... where else might it?
        NSMutableDictionary     *attributes ;
        @try {
            attributes = [[theTextField.attributedStringValue attributesAtIndex:0 effectiveRange:nil] mutableCopy] ;
        }
        @catch ( NSException *theException ) {
            attributes = [@{NSParagraphStyleAttributeName:[NSParagraphStyle defaultParagraphStyle]} mutableCopy] ;
//            printToConsole(L, "-- unable to retrieve current style for text; reverting to defaults") ;
        }

        NSMutableParagraphStyle *style = [[attributes objectForKey:NSParagraphStyleAttributeName] mutableCopy] ;

// NOTE: If we ever do deprecate setTextFont, setTextSize, and setTextColor, or if we want to expand to allow
// multiple styles in an attributed string, move font and color into attribute dictionary -- I left them as is
// to minimize changes to existing functions.

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
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
//    HSDrawingView   *drawingView   = (HSDrawingView *)drawingWindow.contentView;

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
            CLS_NSLOG(@"ERROR: Unexpected type passed to hs.drawing:setTopLeft(): %d", lua_type(L, 2));
            lua_pushnil(L);
            return 1;
    }

    windowLoc.y=[[NSScreen screens][0] frame].size.height - windowLoc.y ;
    [drawingWindow setFrameTopLeftPoint:windowLoc] ;

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
            CLS_NSLOG(@"ERROR: Unexpected type passed to hs.drawing:setSize(): %d", lua_type(L, 2));
            lua_pushnil(L);
            return 1;
    }

    NSRect oldFrame = drawingWindow.frame;
    NSRect newFrame = NSMakeRect(oldFrame.origin.x, oldFrame.origin.y + oldFrame.size.height - windowSize.height, windowSize.width, windowSize.height);

    [drawingWindow setFrame:newFrame display:YES animate:NO];

    if ([drawingView isKindOfClass:[HSDrawingViewText class]]) {
        [((HSDrawingViewText *) drawingView).textField setFrameSize:windowSize];
    } else if ([drawingView isKindOfClass:[HSDrawingViewImage class]]) {
        [((HSDrawingViewImage *) drawingView).HSImageView setFrameSize:windowSize];
    }

    lua_pushvalue(L, 1);
    return 1;
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
///  * This method should only be used on rectangle and circle drawing objects
///  * Calling this method will remove any gradient fill colors previously set with `hs.drawing:setFillGradient()`
static int drawing_setFillColor(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    NSColor *fillColor = [[LuaSkin shared] luaObjectAtIndex:2 toClass:"NSColor"] ;

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewRect class]] || [drawingView isKindOfClass:[HSDrawingViewCircle class]]) {
        drawingView.HSFillColor = fillColor;
        drawingView.HSGradientStartColor = nil;
        drawingView.HSGradientEndColor = nil;
        drawingView.HSGradientAngle = 0;

        drawingView.needsDisplay = YES;
    } else {
        showError(L, ":setFillColor() called on an hs.drawing object that isn't a rectangle or circle object");
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
///  * This method should only be used on rectangle and circle drawing objects
///  * Calling this method will remove any fill color previously set with `hs.drawing:setFillColor()`
static int drawing_setFillGradient(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    NSColor *startColor = [[LuaSkin shared] luaObjectAtIndex:2 toClass:"NSColor"] ;
    NSColor *endColor = [[LuaSkin shared] luaObjectAtIndex:3 toClass:"NSColor"] ;
    int angle = (int)lua_tointeger(L, 4);

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewRect class]] || [drawingView isKindOfClass:[HSDrawingViewCircle class]]) {
        drawingView.HSFillColor = nil;
        drawingView.HSGradientStartColor = startColor;
        drawingView.HSGradientEndColor = endColor;
        drawingView.HSGradientAngle = angle;

        drawingView.needsDisplay = YES;
    } else {
        showError(L, ":setFillGradient() called on an hs.drawing object that isn't a rectangle or circle object");
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
///  * This method should only be used on line, rectangle and circle drawing objects
static int drawing_setStrokeColor(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    NSColor *strokeColor = [[LuaSkin shared] luaObjectAtIndex:2 toClass:"NSColor"] ;

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewRect class]] || [drawingView isKindOfClass:[HSDrawingViewCircle class]] || [drawingView isKindOfClass:[HSDrawingViewLine class]]) {
        drawingView.HSStrokeColor = strokeColor;
        drawingView.needsDisplay = YES;
    } else {
        showError(L, ":setStrokeColor() called on an hs.drawing object that isn't a line, rectangle or circle object");
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
        showError(L, ":setRoundedRectRadii() called on an hs.drawing object that isn't a rectangle object");
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
///  * This method should only be used on line, rectangle and circle drawing objects
static int drawing_setFill(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewRect class]] || [drawingView isKindOfClass:[HSDrawingViewCircle class]] || [drawingView isKindOfClass:[HSDrawingViewLine class]]) {
        drawingView.HSFill = (BOOL)lua_toboolean(L, 2);
        drawingView.needsDisplay = YES;
    } else {
        showError(L, ":setFill() called on an hs.drawing object that isn't a rectangle, circle or line object");
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
///  * This method should only be used on line, rectangle and circle drawing objects
static int drawing_setStroke(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewRect class]] || [drawingView isKindOfClass:[HSDrawingViewCircle class]] || [drawingView isKindOfClass:[HSDrawingViewLine class]]) {
        drawingView.HSStroke = (BOOL)lua_toboolean(L, 2);
        drawingView.needsDisplay = YES;
    } else {
        showError(L, ":setStroke() called on an hs.drawing object that isn't a line, rectangle or circle object");
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
///  * This method should only be used on line, rectangle and circle drawing objects
static int drawing_setStrokeWidth(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewRect class]] || [drawingView isKindOfClass:[HSDrawingViewCircle class]] || [drawingView isKindOfClass:[HSDrawingViewLine class]]) {
        drawingView.HSLineWidth = lua_tonumber(L, 2);
        drawingView.needsDisplay = YES;
    } else {
        showError(L, ":setStrokeWidth() called on an hs.drawing object that isn't a line, rectangle or circle object");
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
    drawing_t *drawingObject = get_item_arg(L, 1);
    NSImage *image = [[LuaSkin shared] luaObjectAtIndex:2 toClass:"NSImage"];

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingViewImage *drawingView = (HSDrawingViewImage *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewImage class]]) {
        [drawingView setImage:image];
    } else {
        showError(L, ":setImage() called on an hs.drawing object that isn't an image object");
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
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK] ;
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingView *drawingView = (HSDrawingView *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewImage class]]) {
        [drawingView setFrameCenterRotation:(360.0 - lua_tonumber(L, 2))] ;
    } else {
        showError(L, ":rotateImage() called on an hs.drawing object that isn't an image object");
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
        if (drawingView.mouseUpCallbackRef != LUA_NOREF) {
            [drawingView setMouseUpCallback:[skin luaUnref:refTable ref:drawingView.mouseUpCallbackRef]];
        }

        // Set a new callback if we have a function
        if (lua_type(L, 2) == LUA_TFUNCTION) {
            lua_pushvalue(L, 2);
            [drawingView setMouseUpCallback:[skin luaRef:refTable]];
        }
    } else {
        showError(L, ":setClickCallback() called with invalid mouseUp function");
    }

    if (lua_type(L, 3) == LUA_TNONE || lua_type(L, 3) == LUA_TNIL || lua_type(L, 3) == LUA_TFUNCTION) {
        // We're either removing a callback, or setting a new one. Either way, we want to make clear out any callback that exists
        if (drawingView.mouseDownCallbackRef != LUA_NOREF) {
            [drawingView setMouseDownCallback:[skin luaUnref:refTable ref:drawingView.mouseDownCallbackRef]];
        }

        // Set a new callback if we have a function
        if (lua_type(L, 3) == LUA_TFUNCTION) {
            lua_pushvalue(L, 3);
            [drawingView setMouseDownCallback:[skin luaRef:refTable]];
        }
    } else {
        showError(L, ":setClickCallback() called with invalid mouseDown function");
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:show() -> drawingObject
/// Method
/// Displays the drawing object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The drawing object
static int drawing_show(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    [(__bridge HSDrawingWindow *)drawingObject->window makeKeyAndOrderFront:nil];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:hide() -> drawingObject
/// Method
/// Hides the drawing object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The drawing object
static int drawing_hide(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    [(__bridge HSDrawingWindow *)drawingObject->window orderOut:nil];

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
static int drawing_delete(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge_transfer HSDrawingWindow *)drawingObject->window;

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
///  * aboveEverything - An optional boolean value that controls how far to the front the drawing should be placed. True to place the drawing on top of all windows (including the dock and menubar and fullscreen windows), false to place the drawing above normal windows, but below the dock, menubar and fullscreen windows. Defaults to false.
///
/// Returns:
///  * The drawing object
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
    drawing_t *drawingObject = get_item_arg(L, 1);
    CGFloat newLevel = luaL_checknumber(L, 2);
    if ((newLevel < 0.0) || (newLevel > 1.0)) {
        showError(L, "Level must be between 0.0 and 1.0") ;
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

/// hs.drawing.getTextDrawingSize(styledTextObject or theText, [textStyle]) -> sizeTable
/// Method
/// Get the size of the rectangle necessary to fully render the text with the specified style so that is will be completely visible.
///
/// Parameters:
///  * styledTextObject - an object created with the hs.styledtext module or its table representation (see `hs.styledtext`).
///
///  The following format is supported for backwards compatibility, but is deprecated.  Use the hs.styledtext module instead.
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
///  * sizeTable - a table containing the Height and Width necessary to fully display the text drawing object.
///
/// Notes:
///  * This function assumes the default values specified for any key which is not included in the provided textStyle.
///  * The size returned is an approximation and may return a width that is off by about 4 points.  Use the returned size as a minimum starting point. Sometimes using the "clip" or "truncateMiddle" lineBreak modes or "justified" alignment will fit, but its safest to add in your own buffer if you have the space in your layout.
///  * Multi-line text (separated by a newline or return) is supported.  The height will be for the multiple lines and the width returned will be for the longest line.
static int drawing_getTextDrawingSize(lua_State *L) {
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
            break ;
    }

    lua_newtable(L) ;
        lua_pushnumber(L, ceil(theSize.height)) ; lua_setfield(L, -2, "h") ;
        lua_pushnumber(L, ceil(theSize.width)) ; lua_setfield(L, -2, "w") ;

    return 1 ;
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
        if ([drawingView isKindOfClass:[HSDrawingViewRect class]])   title = @"rectangle" ;
        if ([drawingView isKindOfClass:[HSDrawingViewCircle class]]) title = @"circle" ;
        if ([drawingView isKindOfClass:[HSDrawingViewLine class]])   title = @"line" ;
        if ([drawingView isKindOfClass:[HSDrawingViewText class]])   title = @"text" ;
        if ([drawingView isKindOfClass:[HSDrawingViewImage class]])  title = @"image" ;

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
    {"rectangle",          drawing_newRect},
    {"line",               drawing_newLine},
    {"text",               drawing_newText},
    {"_image",             drawing_newImage},
    {"getTextDrawingSize", drawing_getTextDrawingSize},
    {"defaultTextStyle",   default_textAttributes},

    {NULL,                 NULL}
};

static const luaL_Reg drawing_metalib[] = {
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

    {"getText",    drawing_getText},

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
