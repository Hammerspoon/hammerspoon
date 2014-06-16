local util = require("util")

local screen = {}
local screen_metatable = {__index = screen}

function screen:frame()
  local x, y, w, h = __api.screen_frame(self.__screen)
  return {x = x, y = y, w = w, h = h}
end

function screen:visible_frame()
  local x, y, w, h = __api.screen_visible_frame(self.__screen)
  return {x = x, y = y, w = w, h = h}
end

function screen:frame_including_dock_and_menu()
  local primary_screen = screen.all()[1]
  local f = self:frame()
  f.y = primary_screen:frame().h - f.h - f.y
  return f
end

function screen:frame_without_dock_or_menu()
  local primary_screen = screen.all()[1]
  local f = self:visible_frame()
  f.y = primary_screen:frame().h - f.h - f.y
  return f
end

function screen:next()
  local screens = screen.all()
  local i = util.indexof(screens, self) + 1
  if i > # screens then i = 1 end
  return screens[i]
end

function screen:previous()
  local screens = screen.all()
  local i = util.indexof(screens, self) - 1
  if i < 1 then i = # screens end
  return screens[i]
end

function screen_metatable.__eq(a, b)
  return __api.screen_equals(a.__screen, b.__screen)
end

local function rawinit(s)
  return setmetatable({__screen = s}, screen_metatable)
end

function screen.all()
  return util.map(__api.screen_get_screens(), rawinit)
end

function screen.main()
  return rawinit(__api.screen_get_main_screen())
end

return screen
