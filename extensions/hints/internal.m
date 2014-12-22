#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>

#define get_screen_arg(L, idx) (__bridge NSScreen*)*((void**)luaL_checkudata(L, idx, "hs.screen"))
#define get_hint_arg(L, idx) (__bridge HintWindow*)*((void**)luaL_checkudata(L, idx, "hs.hints.hint"))

@interface HintView : NSView {
@private
    NSString *text;
    NSImage *icon;
    NSSize textSize;
}

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
static float hintIconAlpha = -1.0;
static NSRect iconFrame;
static NSDictionary *hintTextAttributes;

+ (void)initCache {
    iconFrame = NSMakeRect(0, 0, hintHeight, hintHeight);
    hintBackgroundColor = [NSColor colorWithWhite:0.0 alpha:0.65];
    hintFontColor = [NSColor whiteColor];
    hintFont = [NSFont systemFontOfSize:25.0];
    hintIconAlpha = 0.95;
    hintTextAttributes = [NSDictionary dictionaryWithObjectsAndKeys:hintFont,
                          NSFontAttributeName,
                          hintFontColor,
                          NSForegroundColorAttributeName, nil];
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setWantsLayer:YES];
        [self setIcon:nil];
        [HintView initCache];
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
    //self.frame = NSMakeRect(self.frame.origin.x, self.frame.origin.y, textSize.width + 100, hintHeight);
}

- (void)drawRect:(NSRect __unused)dirtyRect {
    [[NSGraphicsContext currentContext] saveGraphicsState];
    [[NSGraphicsContext currentContext] setShouldAntialias:YES];

    if (icon != nil) {
        [icon drawInRect:iconFrame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:hintIconAlpha];
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
                 forApp:(NSString*)bundle onScreen:(NSScreen*)screen;
@end

@implementation HintWindow

- (HintWindow*)initWithPoint:(CGPoint)pt text:(NSString*)txt
                 forApp:(NSString*)bundle onScreen:(NSScreen*)screen {
    CGFloat height = 75;
    CGRect frame = NSMakeRect(pt.x - (height/2.0),
                              screen.frame.size.height - pt.y - (height/2.0), 100, 75);
    self = [super initWithContentRect:frame
                            styleMask:NSBorderlessWindowMask
                              backing:NSBackingStoreBuffered
                                defer:NO
                               screen:screen];
    if (self) {
        [self setOpaque:NO];
        [self setBackgroundColor:[NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha:0.0]];
        [self makeKeyAndOrderFront:NSApp];
        [self setLevel:(NSScreenSaverWindowLevel - 1)];
        HintView *label = [[HintView alloc] initWithFrame:frame];
        [label setText:txt];
        [label setIconFromBundleID:bundle];
        [self setContentView:label];
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

    luaL_getmetatable(L, "hs.hints.hint");
    lua_setmetatable(L, -2);
}

static int hints_test(lua_State* L) {
    HintWindow *win = [[HintWindow alloc] initWithPoint:NSMakePoint(1000, 200) text:@"J" forApp:@"com.kapeli.dash" onScreen:[NSScreen mainScreen]];
    new_hint(L, win);
    return 1;
}

static int hints_new(lua_State* L) {
    CGFloat x = luaL_checknumber(L, 1);
    CGFloat y = luaL_checknumber(L, 2);
    NSString* msg = [NSString stringWithUTF8String: luaL_tolstring(L, 3, NULL)];
    NSString* app = [NSString stringWithUTF8String: luaL_tolstring(L, 4, NULL)];
    NSScreen *screen = get_screen_arg(L, 5);

    HintWindow *win = [[HintWindow alloc] initWithPoint:NSMakePoint(x, y) text:msg forApp:app onScreen:screen];
    new_hint(L, win);
    return 1;
}

static const luaL_Reg hintslib[] = {
    {"test", hints_test},
    {"new", hints_new},
    {"close", hint_close},

    {} // necessary sentinel
};

int luaopen_hs_hints_internal(lua_State* L) {
    luaL_newlib(L, hintslib);

    if (luaL_newmetatable(L, "hs.hints.hint")) {
        lua_pushvalue(L, -2);
        lua_setfield(L, -2, "__index");

        lua_pushcfunction(L, hint_eq);
        lua_setfield(L, -2, "__eq");
    }
    lua_pop(L, 1);
    return 1;
}
