#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lua/lauxlib.h>
#import "../hammerspoon.h"

/// === hs.drawing ===
///
/// Primitives for drawing on the screen in various ways

// Useful definitions
#define USERDATA_TAG "hs.drawing"
#define get_item_arg(L, idx) ((drawing_t *)luaL_checkudata(L, idx, USERDATA_TAG))

// Declare our Lua userdata object and a storage container for them
typedef struct _drawing_t {
    void *window;
} drawing_t;

NSMutableArray *drawingWindows;

// Objective-C class interface definitions
@interface HSDrawingWindow : NSWindow <NSWindowDelegate>
@end

@interface HSDrawingView : NSView
@property BOOL HSFill;
@property BOOL HSStroke;
@property CGFloat HSLineWidth;
@property (nonatomic, strong) NSColor *HSFillColor;
@property (nonatomic, strong) NSColor *HSGradientStartColor;
@property (nonatomic, strong) NSColor *HSGradientEndColor;
@property int HSGradientAngle;
@property (nonatomic, strong) NSColor *HSStrokeColor;
@property CGFloat HSRoundedRectXRadius;
@property CGFloat HSRoundedRectYRadius;
@end

@interface HSDrawingViewCircle : HSDrawingView
@end

@interface HSDrawingViewRect : HSDrawingView
@end

@interface HSDrawingViewLine : HSDrawingView
@property NSPoint origin;
@property NSPoint end;
@end

@interface HSDrawingViewText : HSDrawingView
@property (nonatomic, strong) NSTextField *textField;
@end

@interface HSDrawingViewImage : HSDrawingView
@property (nonatomic, strong) NSImageView *HSImageView;
@property (nonatomic, strong) NSImage *HSImage;
@end

// Objective-C class interface implementations
@implementation HSDrawingWindow
- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSUInteger __unused)windowStyle backing:(NSBackingStoreType __unused)bufferingType defer:(BOOL __unused)deferCreation {
    //CLS_NSLOG(@"HSDrawingWindow::initWithContentRect contentRect:(%.1f,%.1f) %.1fx%.1f", contentRect.origin.x, contentRect.origin.y, contentRect.size.width, contentRect.size.height);
    self = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];
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
        self.animationBehavior = NSWindowAnimationBehaviorNone;
        self.level = NSFloatingWindowLevel;
    }
    return self;
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

- (BOOL)isFlipped {
    return YES;
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
        [self addSubview:self.HSImageView];
    }
    return self;
}

- (void)setImageFromPath:(NSString *)filePath {
    NSImage *newImage = [[NSImage alloc] initByReferencingFile:filePath];
    if (!newImage) {
        CLS_NSLOG(@"HSDrawingViewImage::setImageFromPath: ERROR: unable to load image: %@", filePath);
        return;
    }

    self.HSImageView.image = newImage;

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
    NSRect windowRect;
    switch (lua_type(L, 1)) {
        case LUA_TTABLE:
            lua_getfield(L, 1, "x");
            windowRect.origin.x = lua_tointeger(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, 1, "y");
            windowRect.origin.y = lua_tointeger(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, 1, "w");
            windowRect.size.width = lua_tointeger(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, 1, "h");
            windowRect.size.height = lua_tointeger(L, -1);
            lua_pop(L, 1);

            break;
        default:
            CLS_NSLOG(@"ERROR: Unexpected type passed to hs.drawing.circle(): %d", lua_type(L, 1));
            lua_pushnil(L);
            return 1;
            break;
    }
    HSDrawingWindow *theWindow = [[HSDrawingWindow alloc] initWithContentRect:windowRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];

    if (theWindow) {
        drawing_t *drawingObject = lua_newuserdata(L, sizeof(drawing_t));
        memset(drawingObject, 0, sizeof(drawing_t));
        drawingObject->window = (__bridge_retained void*)theWindow;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);

        HSDrawingViewCircle *theView = [[HSDrawingViewCircle alloc] initWithFrame:((NSView *)theWindow.contentView).bounds];

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
    NSRect windowRect;
    switch (lua_type(L, 1)) {
        case LUA_TTABLE:
            lua_getfield(L, 1, "x");
            windowRect.origin.x = lua_tointeger(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, 1, "y");
            windowRect.origin.y = lua_tointeger(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, 1, "w");
            windowRect.size.width = lua_tointeger(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, 1, "h");
            windowRect.size.height = lua_tointeger(L, -1);
            lua_pop(L, 1);

            break;
        default:
            CLS_NSLOG(@"ERROR: Unexpected type passed to hs.drawing.rectangle(): %d", lua_type(L, 1));
            lua_pushnil(L);
            return 1;
            break;
    }
    HSDrawingWindow *theWindow = [[HSDrawingWindow alloc] initWithContentRect:windowRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];

    if (theWindow) {
        drawing_t *drawingObject = lua_newuserdata(L, sizeof(drawing_t));
        memset(drawingObject, 0, sizeof(drawing_t));
        drawingObject->window = (__bridge_retained void*)theWindow;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);

        HSDrawingViewRect *theView = [[HSDrawingViewRect alloc] initWithFrame:((NSView *)theWindow.contentView).bounds];

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
    NSRect windowRect;
    NSPoint origin;
    NSPoint end;

    switch (lua_type(L, 1)) {
        case LUA_TTABLE:
            lua_getfield(L, 1, "x");
            origin.x = lua_tointeger(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, 1, "y");
            origin.y = lua_tointeger(L, -1);
            lua_pop(L, 1);

            break;
        default:
            CLS_NSLOG(@"ERROR: Unexpected type passed to hs.drawing.line(): %d", lua_type(L, 1));
            lua_pushnil(L);
            return 1;
            break;
    }

    switch (lua_type(L, 2)) {
        case LUA_TTABLE:
            lua_getfield(L, 2, "x");
            end.x = lua_tointeger(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, 2, "y");
            end.y = lua_tointeger(L, -1);
            lua_pop(L, 1);

            break;
        default:
            CLS_NSLOG(@"ERROR: Unexpected type passed to hs.drawing.line(): %d", lua_type(L, 1));
            lua_pushnil(L);
            return 1;
            break;
    }

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
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);

        HSDrawingViewLine *theView = [[HSDrawingViewLine alloc] initWithFrame:((NSView *)theWindow.contentView).bounds];
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

NSColor *getColorFromStack(lua_State *L, int idx) {
    CGFloat red, green, blue, alpha;

    switch (lua_type(L, idx)) {
        case LUA_TTABLE:
            lua_getfield(L, idx, "red");
            red = lua_tonumber(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, idx, "green");
            green = lua_tonumber(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, idx, "blue");
            blue = lua_tonumber(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, idx, "alpha");
            alpha = lua_tonumber(L, -1);
            lua_pop(L, 1);

            break;
        case LUA_TNIL:
            return [NSColor clearColor];
            break;
        default:
            CLS_NSLOG(@"ERROR: Unexpected type passed to an hs.drawing color method: %d", lua_type(L, 1));
            return 0;

            break;
    }

    return [NSColor colorWithSRGBRed:red green:green blue:blue alpha:alpha];
}

/// hs.drawing.text(sizeRect, message) -> drawingObject or nil
/// Constructor
/// Creates a new text object
///
/// Parameters:
///  * sizeRect - A rect-table containing the location/size of the text
///  * message - A string containing the text to be displayed
///
/// Returns:
///  * An `hs.drawing` text object, or nil if an error occurs
static int drawing_newText(lua_State *L) {
    NSRect windowRect;
    switch (lua_type(L, 1)) {
        case LUA_TTABLE:
            lua_getfield(L, 1, "x");
            windowRect.origin.x = lua_tointeger(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, 1, "y");
            windowRect.origin.y = lua_tointeger(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, 1, "w");
            windowRect.size.width = lua_tointeger(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, 1, "h");
            windowRect.size.height = lua_tointeger(L, -1);
            lua_pop(L, 1);

            break;
        default:
            CLS_NSLOG(@"ERROR: Unexpected type passed to hs.drawing.text(): %d", lua_type(L, 1));
            lua_pushnil(L);
            return 1;
            break;
    }
    const char *message = lua_tostring(L, 2);
    NSString *theMessage = [NSString stringWithUTF8String:message ? message : ""];
    HSDrawingWindow *theWindow = [[HSDrawingWindow alloc] initWithContentRect:windowRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];

    if (theWindow) {
        drawing_t *drawingObject = lua_newuserdata(L, sizeof(drawing_t));
        memset(drawingObject, 0, sizeof(drawing_t));
        drawingObject->window = (__bridge_retained void*)theWindow;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);

        HSDrawingViewText *theView = [[HSDrawingViewText alloc] initWithFrame:((NSView *)theWindow.contentView).bounds];

        theWindow.contentView = theView;
        theView.textField.stringValue = theMessage;

        if (!drawingWindows) {
            drawingWindows = [[NSMutableArray alloc] init];
        }
        [drawingWindows addObject:theWindow];
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.drawing.image(sizeRect, imagePath) -> drawingObject or nil
/// Constructor
/// Creates a new image object
///
/// Parameters:
///  * sizeRect - A rect-table containing the location/size of the image
///  * imagePath - A string containing a path to an image file
///
/// Returns:
///  * An `hs.drawing` image object, or nil if an error occurs
///  * Paths relative to the PWD of Hammerspoon (typically ~/.hammerspoon/) will work, but paths relative to the UNIX homedir character, `~` will not
///  * Animated GIFs are supported. They're not super friendly on your CPU, but they work
static int drawing_newImage(lua_State *L) {
    NSRect windowRect;
    switch (lua_type(L, 1)) {
        case LUA_TTABLE:
            lua_getfield(L, 1, "x");
            windowRect.origin.x = lua_tointeger(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, 1, "y");
            windowRect.origin.y = lua_tointeger(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, 1, "w");
            windowRect.size.width = lua_tointeger(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, 1, "h");
            windowRect.size.height = lua_tointeger(L, -1);
            lua_pop(L, 1);

            break;
        default:
            CLS_NSLOG(@"ERROR: Unexpected type passed to hs.drawing.text(): %d", lua_type(L, 1));
            lua_pushnil(L);
            return 1;
            break;
    }
    NSString *imagePath = [NSString stringWithUTF8String:luaL_checkstring(L, 2)];
    HSDrawingWindow *theWindow = [[HSDrawingWindow alloc] initWithContentRect:windowRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES];

    if (theWindow) {
        drawing_t *drawingObject = lua_newuserdata(L, sizeof(drawing_t));
        memset(drawingObject, 0, sizeof(drawing_t));
        drawingObject->window = (__bridge_retained void*)theWindow;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);

        HSDrawingViewImage *theView = [[HSDrawingViewImage alloc] initWithFrame:((NSView *)theWindow.contentView).bounds];

        theWindow.contentView = theView;
        [theView setImageFromPath:imagePath];

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
static int drawing_setText(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingViewText *drawingView = (HSDrawingViewText *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewText class]]) {
        drawingView.textField.stringValue = [NSString stringWithUTF8String:luaL_checkstring(L, 2)];
    } else {
        showError(L, ":setText() called on an hs.drawing object that isn't a text object");
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:setTextFont(fontname) -> drawingObject
/// Method
/// Sets the font of a drawing object
///
/// Parameters:
///  * fontname - A string containing the name of the font to use
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be used on text drawing objects
static int drawing_setTextFont(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingViewText *drawingView = (HSDrawingViewText *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewText class]]) {
        CGFloat pointSize = drawingView.textField.font.pointSize;
        NSString *fontName = [NSString stringWithUTF8String:luaL_checkstring(L, 2)];
        [drawingView.textField setFont:[NSFont fontWithName:fontName size:pointSize]];
    } else {
        showError(L, ":setTextFont() called on an hs.drawing object that isn't a text object");
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:setTextSize(size) -> drawingObject
/// Method
/// Sets the text size of a drawing object
///
/// Parameters:
///  * size - A number containing the font size to use
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be used on text drawing objects
static int drawing_setTextSize(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingViewText *drawingView = (HSDrawingViewText *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewText class]]) {
        CGFloat pointSize = lua_tonumber(L, 2);
        NSString *fontName = drawingView.textField.font.fontName;
        [drawingView.textField setFont:[NSFont fontWithName:fontName size:pointSize]];
    } else {
        showError(L, ":setTextSize() called on an hs.drawing object that isn't a text object");
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:setTextColor(color) -> drawingObject
/// Method
/// Sets the text color of a drawing object
///
/// Parameters:
///  * color - A table containing color component values between 0.0 and 1.0 for each of the keys:
///   * red
///   * green
///   * blue
///   * alpha
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be called on text drawing objects
static int drawing_setTextColor(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    NSColor *textColor = getColorFromStack(L, 2);

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingViewText *drawingView = (HSDrawingViewText *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewText class]]) {
        [drawingView.textField setTextColor:textColor];
    } else {
        showError(L, ":setTextColor() called on an hs.drawing object that isn't a text object");
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.drawing:setFillColor(color) -> drawingObject
/// Method
/// Sets the fill color of a drawing object
///
/// Parameters:
///  * color - A table containing color component values between 0.0 and 1.0 for each of the keys:
///   * red
///   * green
///   * blue
///   * alpha
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be used on rectangle and circle drawing objects
///  * Calling this method will remove any gradient fill colors previously set with `hs.drawing:setFillGradient()`
static int drawing_setFillColor(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    NSColor *fillColor = getColorFromStack(L, 2);

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
///   * red
///   * green
///   * blue
///   * alpha
///  * endColor - A table containing color component values between 0.0 and 1.0 for each of the keys:
///   * red
///   * green
///   * blue
///   * alpha
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
    NSColor *startColor = getColorFromStack(L, 2);
    NSColor *endColor = getColorFromStack(L, 3);
    int angle = lua_tointeger(L, 4);

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
///  * color - A table containing color component values between 0.0 and 1.0 for each of the keys:
///   * red
///   * green
///   * blue
///   * alpha
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be used on line, rectangle and circle drawing objects
static int drawing_setStrokeColor(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    NSColor *strokeColor = getColorFromStack(L, 2);

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
        drawingView.HSFill = lua_toboolean(L, 2);
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
        drawingView.HSStroke = lua_toboolean(L, 2);
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

/// hs.drawing:setImagePath(imagePath) -> drawingObject
/// Method
/// Sets the image path of a drawing object
///
/// Parameters:
///  * imagePath - A string containing the path to an image file
///
/// Returns:
///  * The drawing object
///
/// Notes:
///  * This method should only be used on an image drawing object
///  * Paths relative to the PWD of Hammerspoon (typically ~/.hammerspoon/) will work, but paths relative to the UNIX homedir character, `~` will not
///  * Animated GIFs are supported. They're not super friendly on your CPU, but they work
static int drawing_setImagePath(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    NSString *imagePath = [NSString stringWithUTF8String:luaL_checkstring(L, 2)];

    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    HSDrawingViewImage *drawingView = (HSDrawingViewImage *)drawingWindow.contentView;

    if ([drawingView isKindOfClass:[HSDrawingViewImage class]]) {
        [drawingView setImageFromPath:imagePath];
    } else {
        showError(L, ":setImagePath() called on an hs.drawing object that isn't an image object");
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

    [drawingWindow close];
    drawingWindow = nil;
    drawingObject->window = nil;
    drawingObject = nil;
    return 0;
}

/// hs.drawing:bringToFront() -> drawingObject
/// Method
/// Places the drawing object on top of normal windows
///
/// Parameters:
///  * None
///
/// Returns:
///  * The drawing object
static int drawing_bringToFront(lua_State *L) {
    drawing_t *drawingObject = get_item_arg(L, 1);
    HSDrawingWindow *drawingWindow = (__bridge HSDrawingWindow *)drawingObject->window;
    [drawingWindow setLevelTop];

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

// Lua metadata

static const luaL_Reg drawinglib[] = {
    {"circle", drawing_newCircle},
    {"rectangle", drawing_newRect},
    {"line", drawing_newLine},
    {"text", drawing_newText},
    {"image", drawing_newImage},

    {}
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
    {"setImagePath", drawing_setImagePath},
    {"bringToFront", drawing_bringToFront},
    {"sendToBack", drawing_sendToBack},
    {"show", drawing_show},
    {"hide", drawing_hide},
    {"delete", drawing_delete},

    {"__gc", drawing_delete},
    {}
};

int luaopen_hs_drawing_internal(lua_State *L) {
    // Metatable for creted objects
    luaL_newlib(L, drawing_metalib);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    lua_setfield(L, LUA_REGISTRYINDEX, USERDATA_TAG);

    // Table for luaopen
    luaL_newlib(L, drawinglib);

    return 1;
}
