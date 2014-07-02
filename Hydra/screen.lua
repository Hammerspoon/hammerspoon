doc.screen.__doc = [[
Manipulate screens (i.e. monitors).

You usually get a screen through a window (see `window.screen`). But you can get screens by themselves through this module, albeit not in any defined/useful order.

Hydra's coordinate system assumes a grid that is the union of every screen's rect (see `screen.frame_including_dock_and_menu`).

Every window's position (i.e. `topleft`) and size are relative to this grid, and they're usually within the grid. A window that's semi-offscreen only intersects the grid.]]


doc.screen.frame_including_dock_and_menu = {"screen:frame_including_dock_and_menu() -> rect", "Returns the screen's rect in absolute coordinates, including the dock and menu."}
function screen:frame_including_dock_and_menu()
  local primary_screen = screen.allscreens()[1]
  local f = self:frame()
  f.y = primary_screen:frame().h - f.h - f.y
  return f
end

doc.screen.frame_without_dock_or_menu = {"screen:frame_without_dock_or_menu() -> rect", "Returns the screen's rect in absolute coordinates, without the dock or menu."}
function screen:frame_without_dock_or_menu()
  local primary_screen = screen.allscreens()[1]
  local f = self:visibleframe()
  f.y = primary_screen:frame().h - f.h - f.y
  return f
end

doc.screen.next = {"screen:next() -> screen", "Returns the screen 'after' this one; I have no idea how they're ordered though."}
function screen:next()
  local screens = screen.allscreens()
  local i = fnutils.indexof(screens, self) + 1
  if i > # screens then i = 1 end
  return screens[i]
end

doc.screen.previous = {"screen:previous() -> screen", "Returns the screen 'before' this one; I have no idea how they're ordered though."}
function screen:previous()
  local screens = screen.allscreens()
  local i = fnutils.indexof(screens, self) - 1
  if i < 1 then i = # screens end
  return screens[i]
end
