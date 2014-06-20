function api.screen:frame_including_dock_and_menu()
  local primary_screen = api.screen.allscreens()[1]
  local f = self:frame()
  f.y = primary_screen:frame().h - f.h - f.y
  return f
end

function api.screen:frame_without_dock_or_menu()
  local primary_screen = api.screen.allscreens()[1]
  local f = self:visibleframe()
  f.y = primary_screen:frame().h - f.h - f.y
  return f
end

function api.screen:next()
  local screens = api.screen.allscreens()
  local i = api.fn.indexof(screens, self) + 1
  if i > # screens then i = 1 end
  return screens[i]
end

function api.screen:previous()
  local screens = api.screen.allscreens()
  local i = api.fn.indexof(screens, self) - 1
  if i < 1 then i = # screens end
  return screens[i]
end
