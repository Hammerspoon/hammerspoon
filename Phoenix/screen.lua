local fp = require("fp")

local screen = {}

local screen_instance = {}

function screen_instance:frame()
  local x, y, w, h = __api.screen_frame(self.__screen)
  return {x = x, y = y, w = w, h = h}
end

function screen_instance:visible_frame()
  local x, y, w, h = __api.screen_visible_frame(self.__screen)
  return {x = x, y = y, w = w, h = h}
end

function screen_instance:frame_including_dock_and_menu()
  local primary_screen = screen.all()[1]
  local f = self:frame()
  f.y = primary_screen:frame().h - f.h - f.y
  return f
end

function screen_instance:frame_without_dock_or_menu()
  local primary_screen = screen.all()[1]
  local f = self:visible_frame()
  f.y = primary_screen:frame().h - f.h - f.y
  return f
end

function screen_instance:next()
  local screens = screen.all()
  local i = fp.indexof(screens, self) + 1
  if i > # screens then i = 1 end
  return screens[i]
end

function screen_instance:previous()
  local screens = screen.all()
  local i = fp.indexof(screens, self) - 1
  if i < 1 then i = # screens end
  return screens[i]
end

local screen_instance_metadata = {__index = screen_instance}

function screen_instance_metadata.__eq(a, b)
  return __api.screen_equals(a.__screen, b.__screen)
end

local function rawinit(s)
  return setmetatable({__screen = s}, screen_instance_metadata)
end

function screen.all()
  return fp.map(__api.screen_get_screens(), rawinit)
end

function screen.main()
  return rawinit(__api.screen_get_main_screen())
end

return screen
