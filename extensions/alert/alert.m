#import <Cocoa/Cocoa.h>
#import <lauxlib.h>

/// === mjolnir.alert ===
///
/// Simple module for showing alerts on-screen.

static NSMutableArray* visibleAlerts;

@interface MJAlert : NSWindowController <NSWindowDelegate>
@end

@interface MJAlert ()

@property NSWindow* win;
@property NSTextField* textField;
@property NSBox* box;

@end

@implementation MJAlert

void MJShowAlert(NSString* oneLineMsg, CGFloat duration) {
    if (!visibleAlerts)
        visibleAlerts = [[NSMutableArray array] retain];
    
    CGFloat absoluteTop;
    
    NSScreen* currentScreen = [NSScreen mainScreen];
    
    if ([visibleAlerts count] == 0) {
        CGRect screenRect = [currentScreen frame];
        absoluteTop = screenRect.size.height / 1.55; // pretty good spot
    }
    else {
        MJAlert* ctrl = [visibleAlerts lastObject];
        absoluteTop = NSMinY([[ctrl window] frame]) - 3.0;
    }
    
    if (absoluteTop <= 0)
        absoluteTop = NSMaxY([currentScreen visibleFrame]);
    
    MJAlert* alert = [[MJAlert alloc] init];
    [alert loadWindow];
    [alert show:oneLineMsg duration:duration pushDownBy:absoluteTop];
    [visibleAlerts addObject:alert];
}

- (void) dealloc {
    [self.box release];
    [self.textField release];
    [self.win release];
    [super dealloc];
}

- (NSWindow*) window {
    return self.win;
}

- (BOOL) isWindowLoaded {
    return self.win != nil;
}

- (void) loadWindow {
    self.win = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 209, 57)
                                           styleMask:NSBorderlessWindowMask
                                             backing:NSBackingStoreBuffered
                                               defer:YES];
    [self.win setDelegate: self];
    
    self.box = [[NSBox alloc] initWithFrame: [[self.win contentView] bounds]];
    [self.box setBoxType: NSBoxCustom];
    [self.box setBorderType: NSLineBorder];
    [self.box setFillColor: [NSColor colorWithCalibratedWhite:0.0 alpha:0.75]];
    [self.box setBorderColor: [NSColor colorWithCalibratedWhite:1.0 alpha:1.0]];
    [self.box setBorderWidth: 1.0];
    [self.box setCornerRadius: 27.0];
    [self.box setContentViewMargins: NSMakeSize(0, 0)];
    [self.box setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [[self.win contentView] addSubview: self.box];
    
    self.textField = [[NSTextField alloc] initWithFrame: NSMakeRect(12, 11, 183, 33)];
    [self.textField setFont: [NSFont systemFontOfSize: 27]];
    [self.textField setTextColor: [NSColor colorWithCalibratedWhite:1.0 alpha:1.0]];
    [self.textField setDrawsBackground: NO];
    [self.textField setBordered: NO];
    [self.textField setEditable: NO];
    [self.textField setSelectable: NO];
//    [self.textField setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
    [self.box addSubview: self.textField];
    
    self.window.backgroundColor = [NSColor clearColor];
    self.window.opaque = NO;
    self.window.level = NSFloatingWindowLevel;
    self.window.ignoresMouseEvents = YES;
    self.window.animationBehavior = (/* TODO: make me a variable */ YES ? NSWindowAnimationBehaviorAlertPanel : NSWindowAnimationBehaviorNone);
    //    self.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary;
}

- (void) show:(NSString*)oneLineMsg duration:(CGFloat)duration pushDownBy:(CGFloat)adjustment {
    NSDisableScreenUpdates();
    
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.01];
    [[[self window] animator] setAlphaValue:1.0];
    [NSAnimationContext endGrouping];
    
    [self useTitleAndResize:[oneLineMsg description]];
    [self setFrameWithAdjustment:adjustment];
    [self showWindow:self];
    [self performSelector:@selector(fadeWindowOut) withObject:nil afterDelay:duration];
    
    NSEnableScreenUpdates();
}

- (void) setFrameWithAdjustment:(CGFloat)pushDownBy {
    NSScreen* currentScreen = [NSScreen mainScreen];
    CGRect screenRect = [currentScreen frame];
    CGRect winRect = [[self window] frame];
    
    winRect.origin.x = (screenRect.size.width / 2.0) - (winRect.size.width / 2.0);
    winRect.origin.y = pushDownBy - winRect.size.height;
    
    [self.window setFrame:winRect display:NO];
}

- (void) fadeWindowOut {
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.15];
    [[[self window] animator] setAlphaValue:0.0];
    [NSAnimationContext endGrouping];
    
    [self performSelector:@selector(closeAndResetWindow) withObject:nil afterDelay:0.15];
}

- (void) closeAndResetWindow {
    [[self window] orderOut:nil];
    [[self window] setAlphaValue:1.0];
    
    [visibleAlerts removeObject: self];
    [self release];
}

- (void) useTitleAndResize:(NSString*)title {
    [[self window] setTitle:title];
    
    self.textField.stringValue = title;
    [self.textField sizeToFit];
    
	NSRect windowFrame = [[self window] frame];
	windowFrame.size.width = [self.textField frame].size.width + 32.0;
	windowFrame.size.height = [self.textField frame].size.height + 24.0;
	[[self window] setFrame:windowFrame display:YES];
}

- (void) emergencyCancel {
    [[self class] cancelPreviousPerformRequestsWithTarget:self];
    [[self window] orderOut:nil];
    [self release];
}

@end

/// mjolnir.alert.show(str, seconds = 2)
/// Shows a message in large words briefly in the middle of the screen; does tostring() on its argument for convenience.
static int alert_show(lua_State* L) {
    lua_settop(L, 2);
    NSString* str = [NSString stringWithUTF8String: luaL_tolstring(L, 1, NULL)];
    
    double duration = 2.0;
    if (lua_isnumber(L, 2))
        duration = lua_tonumber(L, 2);
    
    MJShowAlert(str, duration);
    
    return 0;
}

static int alert_gc(lua_State* L) {
    for (MJAlert* alert in visibleAlerts)
        [alert emergencyCancel];
    
    [visibleAlerts release];
    visibleAlerts = nil;
    
    return 0;
}

static const luaL_Reg alertlib[] = {
    {"show", alert_show},
    {}
};

static const luaL_Reg metalib[] = {
    {"__gc", alert_gc},
    {}
};

int luaopen_mjolnir_alert(lua_State* L) {
    luaL_newlib(L, alertlib);
    
    luaL_newlib(L, metalib);
    lua_setmetatable(L, -2);
    
    return 1;
}
