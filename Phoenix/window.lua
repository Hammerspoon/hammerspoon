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

function window:isstandard()
  return __api.window_is_standard(self:subrole())
end

function window:isminimized()
  return __api.window_isminimized(self.__win)
end

function window:minimize()
  return __api.window_minimize(self.__win)
end

function window:unminimize()
  return __api.window_unminimize(self.__win)
end

function window:subrole()
  return __api.window_subrole(self.__win)
end

function window:role()
  return __api.window_role(self.__win)
end

function window.focusedwindow()
  return window.rawinit(__api.window_get_focused_window())
end

function window.allwindows()
  local application = require("application")
  return util.mapcat(application.running_applications(), application.windows)
end

function window:other_windows_on_same_screen()
  return util.filter(window.visiblewindows, function(win) self ~= win and self:screen() == win:screen() end)
end

function window:other_windows_on_all_screens()
  return util.filter(window.visiblewindows, function(win) self ~= win end)
end

function window:pid()
  return __api.window_pid(self.__win)
end

function window:application()
  local application = require("application")
  return application.rawinit(self:pid())
end

function window:becomemain()
  return __api.window_makemain(self.__win)
end

function window:focus()
  return self:becomemain() and self:application():activate()
end

function window.visiblewindows()
  return util.filter(window:allwindows(), window.isvisible)
end

function window:title()
  return __api.window_title(self.__win)
end

function window:size()
  local w, h = __api.window_size(self.__win)
  return {w = w, h = h}
end

function window:topleft()
  local x, y = __api.window_topleft(self.__win)
  return {x = x, y = y}
end

function window:frame()
  local s = self:size()
  local tl = self:topleft()
  return {x = tl.x, y = tl.y, w = s.w, h = s.h}
end

function window:setsize(s)
  __api.window_setsize(self.__win, s.w, s.h)
end

function window:settopleft(tl)
  __api.window_settopleft(self.__win, tl.x, tl.y)
end

function window:maximize()
  local screenrect = self:screen():frame_without_dock_or_menu()
  self:setframe(screenrect)
end

function window.visible_windows_sorted_by_recency()
  return util.map(__api.window_visible_windows_sorted_by_recency(), window.rawinit)
end

function window:screen()
  local screen = require("screen")

  local windowframe = self:frame()

  local lastvolume = 0
  local lastscreen = nil

  local function rectintersection(r1, r2)
    -- TODO: this is almost certainly incorrect; just add "geometry" module and shell out to C
    return {
      x = math.max(r1.x, r2.x),
      y = math.max(r1.y, r2.y),
      w = math.min(r1.w, r2.w),
      h = math.min(r1.h, r2.h),
    }
  end

  for _, screen in pairs(screen.all()) do
    local screenframe = screen:frame_including_dock_and_menu()
    local intersection = rectintersection(windowframe, screenframe)
    local volume = intersection.w * intersection.h

    if volume > lastvolume then
      lastvolume = volume
      lastscreen = screen
    end
  end

  return lastscreen
end

function window:setframe(f)
  self:setsize(f)
  self:settopleft(f)
  self:setsize(f)
end

return window























-- - (void) focusWindowLeft;
-- - (void) focusWindowRight;
-- - (void) focusWindowUp;
-- - (void) focusWindowDown;
--
-- - (NSArray*) windowsToWest;
-- - (NSArray*) windowsToEast;
-- - (NSArray*) windowsToNorth;
-- - (NSArray*) windowsToSouth;


















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
