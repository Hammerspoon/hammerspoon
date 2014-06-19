function hydra.screen:frame_including_dock_and_menu()
  local primary_screen = hydra.screen.allscreens()[1]
  local f = self:frame()
  f.y = primary_screen:frame().h - f.h - f.y
  return f
end

function hydra.screen:frame_without_dock_or_menu()
  local primary_screen = hydra.screen.allscreens()[1]
  local f = self:visibleframe()
  f.y = primary_screen:frame().h - f.h - f.y
  return f
end

function hydra.screen:next()
  local screens = hydra.screen.allscreens()
  local i = hydra.fn.indexof(screens, self) + 1
  if i > # screens then i = 1 end
  return screens[i]
end

function hydra.screen:previous()
  local screens = hydra.screen.allscreens()
  local i = hydra.fn.indexof(screens, self) - 1
  if i < 1 then i = # screens end
  return screens[i]
end
