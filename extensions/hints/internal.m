#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG "hs.hints.hint"

#define get_screen_arg(L, idx) (__bridge NSScreen*)*((void**)luaL_checkudata(L, idx, "hs.screen"))
#define get_hint_arg(L, idx) (__bridge HintWindow*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))

@interface HintView : NSView {
@private
    NSString *text;
    NSImage *icon;
    NSSize textSize;
}

+ (void)initCache:(NSString*)fontName fontSize:(CGFloat)fontSize iconAlpha:(CGFloat)iconAlpha;
- (id)initWithFrame:(NSRect)frame fontName:(NSString*)fontName fontSize:(CGFloat)fontSize iconAlpha:(CGFloat)iconAlpha;
- (void)setIconFromBundleID:(NSString*)appRef;

@property (strong, nonatomic) NSString *text;
@property (strong, nonatomic) NSImage *icon;

@end

@implementation HintView

@synthesize text,icon;

static const float hintHeight = 75.0;

static NSColor *hintBackgroundColor = nil;
static NSColor *hintFontColor = nil;
static NSFont *hintFont = nil;
static NSRect iconFrame;
static NSDictionary *hintTextAttributes;
static float hintIconAlpha = 0.95;

+ (void)initCache:(NSString*)fontName fontSize:(CGFloat)fontSize iconAlpha:(CGFloat)iconAlpha {
    iconFrame = NSMakeRect(0, 0, hintHeight, hintHeight);
    hintBackgroundColor = [NSColor colorWithSRGBRed:0.0 green:0.0 blue:0.0 alpha:0.65];
    hintFontColor = [NSColor whiteColor];
    if (fontName) {
        hintFont = [NSFont fontWithName:fontName size:fontSize];
    } else {
        hintFont = [NSFont systemFontOfSize:(fontSize > 0.0 ? fontSize : 25.0)];
    }
    hintIconAlpha = iconAlpha;
    hintTextAttributes = [NSDictionary dictionaryWithObjectsAndKeys:hintFont,
                          NSFontAttributeName,
                          hintFontColor,
                          NSForegroundColorAttributeName, nil];
}

- (id)initWithFrame:(NSRect)frame fontName:(NSString*)fontName fontSize:(CGFloat)fontSize iconAlpha:(CGFloat)iconAlpha {
    self = [super initWithFrame:frame];
    if (self) {
        [self setWantsLayer:YES];
        [self setIcon:nil];
        [HintView initCache:fontName fontSize:fontSize iconAlpha:iconAlpha];
    }
    return self;
}

- (void)setIconFromBundleID:(NSString*)appBundle {
    NSString *path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:appBundle];
    NSImage *theIcon = [[NSWorkspace sharedWorkspace] iconForFile:path];
    [self setIcon:theIcon];
}

- (void)drawCenteredText:(NSString *)string bounds:(NSRect)rect attributes:(NSDictionary *)attributes {
    NSPoint origin = NSMakePoint(rect.origin.x + (hintHeight/4) + 10,
                                 rect.origin.y + (hintHeight - textSize.height) / 2);
    [string drawAtPoint:origin withAttributes:attributes];
}

- (void)setText:(NSString *)newText {
    text = newText;
    textSize = [text sizeWithAttributes:hintTextAttributes];
    // Might need to resize if text is long
    CGFloat newWidth = textSize.width + hintHeight/2 + 20;
    if(newWidth > 100) {
      self.frame = NSMakeRect(self.frame.origin.x, self.frame.origin.y, newWidth, hintHeight);
      NSRect newWinFrame = self.window.frame;
      newWinFrame.size.width = newWidth;
      [[self window] setFrame:newWinFrame display:YES];
    }
}

- (void)drawRect:(NSRect __unused)dirtyRect {
    [[NSGraphicsContext currentContext] saveGraphicsState];
    [[NSGraphicsContext currentContext] setShouldAntialias:YES];

    if (icon != nil) {
        [icon drawInRect:iconFrame fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:hintIconAlpha];
    }

    // get label info for sizing

    // draw the rounded rect
    [hintBackgroundColor set];
    float cornerSize = 10;
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:
                          CGRectMake(self.bounds.origin.x + (hintHeight / 4),
                                     self.bounds.origin.y + (hintHeight / 4),
                                     20 + textSize.width, hintHeight / 2)
                                                         xRadius:cornerSize yRadius:cornerSize];
    [path fill];

    // draw hint letter
    [self drawCenteredText:text
                    bounds:self.bounds
                attributes:hintTextAttributes];
    [[NSGraphicsContext currentContext] restoreGraphicsState];
}

@end

@interface HintWindow : NSWindow
- (HintWindow*)initWithPoint:(CGPoint)pt text:(NSString*)txt
                      forApp:(NSString*)bundle onScreen:(NSScreen*)screen fontName:(NSString*)fontName fontSize:(CGFloat)fontSize iconAlpha:(CGFloat)iconAlpha;
@end

@implementation HintWindow

- (HintWindow*)initWithPoint:(CGPoint)pt text:(NSString*)txt
                      forApp:(NSString*)bundle onScreen:(NSScreen*)screen fontName:(NSString*)fontName fontSize:(CGFloat)fontSize iconAlpha:(CGFloat)iconAlpha {
    CGFloat height = 75;
    CGRect frame = NSMakeRect(pt.x - (height/2.0),
                              screen.frame.size.height - pt.y - (height/2.0), 100, 75);
    self = [super initWithContentRect:frame
                            styleMask:NSWindowStyleMaskBorderless
                              backing:NSBackingStoreBuffered
                                defer:NO
                               screen:screen];
    if (self) {
        [self setOpaque:NO];
        [self setBackgroundColor:[NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha:0.0]];
        [self makeKeyAndOrderFront:NSApp];
        [self setLevel:(NSScreenSaverWindowLevel - 1)];
        HintView *label = [[HintView alloc] initWithFrame:frame fontName:fontName fontSize:fontSize iconAlpha:iconAlpha];
        [self setContentView:label];
        [label setIconFromBundleID:bundle];
        [label setText:txt];
    }
    return self;
}

- (BOOL)canBecomeKeyWindow {
    return YES;
}
@end

static int hint_close(lua_State* L) {
    HintWindow* hint = get_hint_arg(L, 1);
    [hint close];
    hint = nil;
    lua_pushnil(L);
    lua_setmetatable(L, -2);
    return 0;
}

static int hint_eq(lua_State* L) {
    HintWindow* screenA = get_hint_arg(L, 1);
    HintWindow* screenB = get_hint_arg(L, 2);
    lua_pushboolean(L, screenA == screenB);
    return 1;
}

void new_hint(lua_State* L, HintWindow* screen) {
    void** hintptr = lua_newuserdata(L, sizeof(HintWindow**));
    *hintptr = (__bridge_retained void*)screen;

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
}

static int hints_test(lua_State* L) {
    HintWindow *win = [[HintWindow alloc] initWithPoint:NSMakePoint(1000, 200) text:@"J" forApp:@"com.kapeli.dash" onScreen:[NSScreen mainScreen] fontName:nil fontSize:0.0 iconAlpha:0.0];
    new_hint(L, win);
    return 1;
}

static int hints_new(lua_State* L) {
    NSString* fontName = nil;
    CGFloat fontSize = 0.0;
    CGFloat x = luaL_checknumber(L, 1);
    CGFloat y = luaL_checknumber(L, 2);
    NSString* msg = [NSString stringWithUTF8String: luaL_checkstring(L, 3)];
    NSString* app = [NSString stringWithUTF8String: luaL_checkstring(L, 4)];
    NSScreen *screen = get_screen_arg(L, 5);
    if (!lua_isnoneornil(L, 6) && lua_isstring(L, 6)) {
        fontName = [NSString stringWithUTF8String:luaL_tolstring(L, 6, NULL)];
    }
    if (!lua_isnoneornil(L, 7) && lua_isnumber(L, 7)) {
        fontSize = (CGFloat)lua_tonumber(L, 7);
    }
    CGFloat iconAlpha = (CGFloat)lua_tonumber(L, 8);

    HintWindow *win = [[HintWindow alloc] initWithPoint:NSMakePoint(x, y) text:msg forApp:app onScreen:screen fontName:fontName fontSize:fontSize iconAlpha:iconAlpha];
    new_hint(L, win);
    return 1;
}

static int userdata_tostring(lua_State* L) {
    lua_pushstring(L, [[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static const luaL_Reg hintslib[] = {
    {"test", hints_test},
    {"new", hints_new},

    {NULL, NULL} // necessary sentinel
};

static const luaL_Reg hints_metalib[] = {
    {"__eq", hint_eq},
    {"__gc", hint_close},
    {"__tostring", userdata_tostring},
    {"close", hint_close},

    {NULL, NULL}
};

int luaopen_hs_hints_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibraryWithObject:USERDATA_TAG functions:hintslib metaFunctions:nil objectFunctions:hints_metalib];

    return 1;
}
