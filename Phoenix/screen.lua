-- - (CGRect) frameIncludingDockAndMenu {
--     NSScreen* primaryScreen = [[NSScreen screens] objectAtIndex:0];
--     CGRect f = [self frame];
--     f.origin.y = NSHeight([primaryScreen frame]) - NSHeight(f) - f.origin.y;
--     return f;
-- }
--
-- - (CGRect) frameWithoutDockOrMenu {
--     NSScreen* primaryScreen = [[NSScreen screens] objectAtIndex:0];
--     CGRect f = [self visibleFrame];
--     f.origin.y = NSHeight([primaryScreen frame]) - NSHeight(f) - f.origin.y;
--     return f;
-- }
--
-- - (NSScreen*) nextScreen {
--     NSArray* screens = [NSScreen screens];
--     NSUInteger idx = [screens indexOfObject:self];
--
--     idx += 1;
--     if (idx == [screens count])
--         idx = 0;
--
--         return [screens objectAtIndex:idx];
-- }
--
-- - (NSScreen*) previousScreen {
--     NSArray* screens = [NSScreen screens];
--     NSUInteger idx = [screens indexOfObject:self];
--
--     idx -= 1;
--     if (idx == -1)
--         idx = [screens count] - 1;
--
--         return [screens objectAtIndex:idx];
-- }

local screen = {}

local fp = require("fp")

local screen_instance = {}

function screen_instance:frame()
  local x, y, w, h = __api.screen_frame(self.__screen)
  return {x = x, y = y, w = w, h = h}
end

function screen_instance:visibleframe()
  local x, y, w, h = __api.screen_visible_frame(self.__screen)
  return {x = x, y = y, w = w, h = h}
end

local function rawinit(s)
  return setmetatable({__screen = s}, {__index = screen_instance})
end

function screen.all()
  return fp.map(__api.screen_get_screens(), rawinit)
end

function screen.main()
  return rawinit(__api.screen_get_main_screen())
end

return screen
