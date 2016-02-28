#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

/// === hs.alert ===
///
/// Simple on-screen alerts

static NSMutableArray* visibleAlerts;

@interface HSAlert : NSWindowController <NSWindowDelegate>
@end

@interface HSAlert ()

@property (nonatomic, strong) NSWindow* win;
@property (nonatomic, strong) NSTextField* textField;
@property (nonatomic, strong) NSBox* box;

@end

@implementation HSAlert

void HSShowAlert(NSString* oneLineMsg, CGFloat duration) {
    if (!visibleAlerts)
        visibleAlerts = [NSMutableArray array];

    CGFloat absoluteTop;

    NSScreen* currentScreen = [NSScreen mainScreen];

    if (visibleAlerts.count == 0) {
        CGRect screenRect = currentScreen.frame;
        absoluteTop = screenRect.size.height / 1.55; // pretty good spot
    }
    else {
        HSAlert* ctrl = visibleAlerts.lastObject;
        absoluteTop = NSMinY(ctrl.window.frame) - 3.0;
    }

    if (absoluteTop <= 0)
        absoluteTop = NSMaxY(currentScreen.visibleFrame);

    HSAlert* alert = [[HSAlert alloc] init];
    [alert createWindow];
    [alert show:oneLineMsg duration:duration pushDownBy:absoluteTop];
    [visibleAlerts addObject:alert];
}

- (void) dealloc {
    self.win.delegate = nil;
}

- (NSWindow*) window {
    return self.win;
}

- (BOOL) isWindowLoaded {
    return self.win != nil;
}

- (void) createWindow {
    self.win = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 209, 57)
                                           styleMask:NSBorderlessWindowMask
                                             backing:NSBackingStoreBuffered
                                               defer:YES];
    self.win.delegate = self;

    self.box = [[NSBox alloc] initWithFrame: self.win.contentView.bounds];
    self.box.boxType = NSBoxCustom;
    self.box.borderType = NSLineBorder;
    self.box.fillColor = [NSColor colorWithCalibratedWhite:0.0 alpha:0.75];
    self.box.borderColor = [NSColor colorWithCalibratedWhite:1.0 alpha:1.0];
    self.box.borderWidth = 1.0;
    self.box.cornerRadius = 27.0;
    self.box.contentViewMargins = NSMakeSize(0, 0);
    self.box.autoresizingMask = (NSAutoresizingMaskOptions)(NSViewWidthSizable | NSViewHeightSizable);

    [self.win.contentView addSubview: self.box];

    self.textField = [[NSTextField alloc] initWithFrame: NSMakeRect(12, 11, 183, 33)];
    self.textField.font = [NSFont systemFontOfSize: 27];
    self.textField.textColor = [NSColor colorWithCalibratedWhite:1.0 alpha:1.0];
    self.textField.drawsBackground = NO;
    self.textField.bordered = NO;
    self.textField.editable = NO;
    self.textField.selectable = NO;

    [self.box addSubview: self.textField];

    self.window.backgroundColor = [NSColor clearColor];
    self.window.opaque = NO;
    self.window.level = kCGMaximumWindowLevelKey;
    self.window.ignoresMouseEvents = YES;
    self.window.animationBehavior = NSWindowAnimationBehaviorAlertPanel;
}

- (void) show:(NSString*)oneLineMsg duration:(CGFloat)duration pushDownBy:(CGFloat)adjustment {
    NSDisableScreenUpdates();

    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:0.01];
    [self.window animator].alphaValue = 1.0;
    [NSAnimationContext endGrouping];

    [self useTitleAndResize:oneLineMsg.description];
    [self setFrameWithAdjustment:adjustment];
    [self showWindow:self];
    [self performSelector:@selector(fadeWindowOut) withObject:nil afterDelay:duration];

    NSEnableScreenUpdates();
}

- (void) setFrameWithAdjustment:(CGFloat)pushDownBy {
    NSScreen* currentScreen = [NSScreen mainScreen];
    CGRect screenRect = currentScreen.frame;
    CGRect winRect = self.window.frame;

    winRect.origin.x = screenRect.origin.x + (screenRect.size.width / 2.0) - (winRect.size.width / 2.0);
    winRect.origin.y = screenRect.origin.y + pushDownBy - winRect.size.height;

    [self.window setFrame:winRect display:NO];
}

- (void) fadeWindowOut {
    [self fadeWindowOut:0.15];
}

- (void) fadeWindowOut:(CGFloat)fadeDuration {
    if ((int)fadeDuration == 0) {
        [self closeAndResetWindow];
        return;
    }
    [NSAnimationContext beginGrouping];
    [[NSAnimationContext currentContext] setDuration:fadeDuration];
    [self.window animator].alphaValue = 0.0;
    [NSAnimationContext endGrouping];

    [self performSelector:@selector(closeAndResetWindow) withObject:nil afterDelay:fadeDuration];
}

- (void) closeAndResetWindow {
    [self.window orderOut:nil];
    self.window.alphaValue = 1.0;

    [visibleAlerts removeObject: self];
}

- (void) useTitleAndResize:(NSString*)title {
    NSString *realTitle = title;

    if (realTitle == nil) {
        realTitle = @"error, please file a bug";
    }

    self.window.title = realTitle;
    self.textField.stringValue = realTitle;
    [self.textField sizeToFit];

    NSRect windowFrame = self.window.frame;
    windowFrame.size.width = self.textField.frame.size.width + 32.0;
    windowFrame.size.height = self.textField.frame.size.height + 24.0;
    [self.window setFrame:windowFrame display:YES];
}

- (void) emergencyCancel {
    [[self class] cancelPreviousPerformRequestsWithTarget:self];
    [self.window orderOut:nil];
}

@end

/// hs.alert.show(str[, seconds])
/// Function
/// Shows a message in large words briefly in the middle of the screen; does tostring() on its argument for convenience.
///
/// NOTE: For convenience, you can call this function as `hs.alert(...)`
///
/// Parameters:
///  * str - The string to display in the alert
///  * seconds - The number of seconds to display the alert. Defaults to 2
///
/// Returns:
///  * None
static int alert_show(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TNUMBER|LS_TOPTIONAL, LS_TBREAK];

    lua_settop(L, 2);
    NSString* str = @(lua_tostring(L, 1));

    double duration = 2.0;
    if (lua_isnumber(L, 2))
        duration = lua_tonumber(L, 2);

    if (duration > 0.0)
        HSShowAlert(str, duration);

    return 0;
}

/// hs.alert.closeAll([seconds])
/// Function
/// Closes all alerts currently open on the screen
///
/// Parameters:
///  * seconds - The fade out duration. Defaults to 0.15
///
/// Returns:
///  * None
static int alert_closeAll(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TNUMBER|LS_TOPTIONAL, LS_TBREAK];

    lua_settop(L, 1);

    double duration = 0.15;
    if (lua_isnumber(L, 1))
        duration = lua_tonumber(L, 1);

    if(duration < 0.0)
        duration = 0.0;

    NSMutableArray *alerts = [visibleAlerts copy];
    for (id alert in alerts) {
        [alert fadeWindowOut:duration];
    }
    return 0;
}

static int alert_gc(lua_State* L __unused) {
    for (HSAlert* alert in visibleAlerts)
        [alert emergencyCancel];

    visibleAlerts = nil;

    return 0;
}

static const luaL_Reg alertlib[] = {
    {"show", alert_show},
    {"closeAll", alert_closeAll},
    {NULL, NULL}
};

static const luaL_Reg metalib[] = {
    {"__gc", alert_gc},
    {NULL, NULL}
};

int luaopen_hs_alert_internal(lua_State* L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    [skin registerLibrary:alertlib metaFunctions:metalib];

    return 1;
}
