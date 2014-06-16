local util = require("util")

local window = {}

local window_metatable = {__index = window}

function window_metatable.__eq(a, b)
  return __api.window_equals(a.__win, b.__win)
end

function window.rawinit(winuserdata)
  return setmetatable({__win = winuserdata}, window_metatable)
end

function window:isvisible()
  return not self:application():ishidden() and
    not self:isminimized() and
    self:isstandard()
end

function window.focusedwindow()
  return window.rawinit(__api.window_get_focused_window())
end

function window.allwindows()
  local application = require("application")
  return util.mapcat(application.running_applications(), application.windows)
end

function window:title()
  return __api.window_title(self.__win)
end

return window





-- - (CGRect) frame {
--     CGRect r;
--     r.origin = [self topLeft];
--     r.size = [self size];
--     return r;
-- }
--
-- - (void) setFrame:(CGRect)frame {
--     [self setSize: frame.size];
--     [self setTopLeft: frame.origin];
--     [self setSize: frame.size];
-- }





-- + (NSArray*) visibleWindows {
--     return [[self allWindows] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(PHWindow* win, NSDictionary *bindings) {
--         return ![[win app] isHidden]
--         && ![win isWindowMinimized]
--         && [win isNormalWindow];
--     }]];
-- }
--
-- - (NSArray*) otherWindowsOnSameScreen {
--     return [[PHWindow visibleWindows] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(PHWindow* win, NSDictionary *bindings) {
--         return !CFEqual(self.window, win.window) && [[self screen] isEqual: [win screen]];
--     }]];
-- }
--
-- - (NSArray*) otherWindowsOnAllScreens {
--     return [[PHWindow visibleWindows] filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(PHWindow* win, NSDictionary *bindings) {
--         return !CFEqual(self.window, win.window);
--     }]];
-- }



-- - (NSScreen*) screen {
--     CGRect windowFrame = [self frame];
--
--     CGFloat lastVolume = 0;
--     NSScreen* lastScreen = nil;
--
--     for (NSScreen* screen in [NSScreen screens]) {
--         CGRect screenFrame = [screen frameIncludingDockAndMenu];
--         CGRect intersection = CGRectIntersection(windowFrame, screenFrame);
--         CGFloat volume = intersection.size.width * intersection.size.height;
--
--         if (volume > lastVolume) {
--             lastVolume = volume;
--             lastScreen = screen;
--         }
--     }
--
--     return lastScreen;
-- }

















-- + (NSArray*) allWindows;
-- + (NSArray*) visibleWindows;
-- + (PHWindow*) focusedWindow;
-- + (NSArray*) visibleWindowsMostRecentFirst;
-- - (NSArray*) otherWindowsOnSameScreen;
-- - (NSArray*) otherWindowsOnAllScreens;
--
-- - (void) maximize;
--
--
-- - (NSScreen*) screen;
-- - (PHApp*) app;
--
-- - (void) focusWindowLeft;
-- - (void) focusWindowRight;
-- - (void) focusWindowUp;
-- - (void) focusWindowDown;
--
-- - (NSArray*) windowsToWest;
-- - (NSArray*) windowsToEast;
-- - (NSArray*) windowsToNorth;
-- - (NSArray*) windowsToSouth;
--
--
--
--
--
--
--
--
--
--
--
--
--
-- - (void) maximize {
--     CGRect screenRect = [[self screen] frameWithoutDockOrMenu];
--     [self setFrame: screenRect];
-- }
--
--
--
--
--
-- // focus
--
--
-- NSPoint SDMidpoint(NSRect r) {
--     return NSMakePoint(NSMidX(r), NSMidY(r));
-- }
--
-- - (NSArray*) windowsInDirectionFn:(double(^)(double angle))whichDirectionFn
--                 shouldDisregardFn:(BOOL(^)(double deltaX, double deltaY))shouldDisregardFn
-- {
--     PHWindow* thisWindow = [PHWindow focusedWindow];
--     NSPoint startingPoint = SDMidpoint([thisWindow frame]);
--
--     NSArray* otherWindows = [thisWindow otherWindowsOnAllScreens];
--     NSMutableArray* closestOtherWindows = [NSMutableArray arrayWithCapacity:[otherWindows count]];
--
--     for (PHWindow* win in otherWindows) {
--         NSPoint otherPoint = SDMidpoint([win frame]);
--
--         double deltaX = otherPoint.x - startingPoint.x;
--         double deltaY = otherPoint.y - startingPoint.y;
--
--         if (shouldDisregardFn(deltaX, deltaY))
--             continue;
--
--         double angle = atan2(deltaY, deltaX);
--         double distance = hypot(deltaX, deltaY);
--
--         double angleDifference = whichDirectionFn(angle);
--
--         double score = distance / cos(angleDifference / 2.0);
--
--         [closestOtherWindows addObject:@{
--                                          @"score": @(score),
--                                          @"win": win,
--                                          }];
--     }
--
--     NSArray* sortedOtherWindows = [closestOtherWindows sortedArrayUsingComparator:^NSComparisonResult(NSDictionary* pair1, NSDictionary* pair2) {
--         return [[pair1 objectForKey:@"score"] compare: [pair2 objectForKey:@"score"]];
--     }];
--
--     return sortedOtherWindows;
-- }
--
-- - (void) focusFirstValidWindowIn:(NSArray*)closestWindows {
--     for (PHWindow* win in closestWindows) {
--         if ([win focusWindow])
--             break;
--     }
-- }
--
-- - (NSArray*) windowsToWest {
--     return [[self windowsInDirectionFn:^double(double angle) { return M_PI - abs(angle); }
--                      shouldDisregardFn:^BOOL(double deltaX, double deltaY) { return (deltaX >= 0); }] valueForKeyPath:@"win"];
-- }
--
-- - (NSArray*) windowsToEast {
--     return [[self windowsInDirectionFn:^double(double angle) { return 0.0 - angle; }
--                      shouldDisregardFn:^BOOL(double deltaX, double deltaY) { return (deltaX <= 0); }] valueForKeyPath:@"win"];
-- }
--
-- - (NSArray*) windowsToNorth {
--     return [[self windowsInDirectionFn:^double(double angle) { return -M_PI_2 - angle; }
--                      shouldDisregardFn:^BOOL(double deltaX, double deltaY) { return (deltaY >= 0); }] valueForKeyPath:@"win"];
-- }
--
-- - (NSArray*) windowsToSouth {
--     return [[self windowsInDirectionFn:^double(double angle) { return M_PI_2 - angle; }
--                      shouldDisregardFn:^BOOL(double deltaX, double deltaY) { return (deltaY <= 0); }] valueForKeyPath:@"win"];
-- }
--
-- - (void) focusWindowLeft {
--     [self focusFirstValidWindowIn:[self windowsToWest]];
-- }
--
-- - (void) focusWindowRight {
--     [self focusFirstValidWindowIn:[self windowsToEast]];
-- }
--
-- - (void) focusWindowUp {
--     [self focusFirstValidWindowIn:[self windowsToNorth]];
-- }
--
-- - (void) focusWindowDown {
--     [self focusFirstValidWindowIn:[self windowsToSouth]];
-- }
--
-- @end
