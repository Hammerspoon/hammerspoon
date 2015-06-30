--- === hs.screen ===
---
--- Manipulate screens (i.e. monitors)
---
--- You usually get a screen through a window (see `hs.window.screen`). But you can get screens by themselves through this module, albeit not in any defined/useful order.
---
--- Hammerspoon's coordinate system assumes a grid that is the union of every screen's rect (see `hs.screen.fullFrame`).
---
--- Every window's position (i.e. `topleft`) and size are relative to this grid, and they're usually within the grid. A window that's semi-offscreen only intersects the grid.

local screen = require "hs.screen.internal"
local fnutils = require "hs.fnutils"
local geometry = require "hs.geometry"

screen.watcher = require "hs.screen.watcher"

--- hs.screen:fullFrame() -> rect
--- Method
--- Returns the screen's rect in absolute coordinates, including the dock and menu.
function screen:fullFrame()
  local primary_screen = screen.allScreens()[1]
  local f = self:_frame()
  f.y = primary_screen:_frame().h - f.h - f.y
  return f
end

--- hs.screen:frame() -> rect
--- Method
--- Returns the screen's rect in absolute coordinates, without the dock or menu.
function screen:frame()
  local primary_screen = screen.allScreens()[1]
  local f = self:_visibleframe()
  f.y = primary_screen:_frame().h - f.h - f.y
  return f
end

--- hs.screen:next() -> screen
--- Method
--- Returns the screen 'after' this one (I have no idea how they're ordered though); this method wraps around to the first screen.
function screen:next()
  local screens = screen.allScreens()
  local i = fnutils.indexOf(screens, self) + 1
  if i > # screens then i = 1 end
  return screens[i]
end

--- hs.screen:previous() -> screen
--- Method
--- Returns the screen 'before' this one (I have no idea how they're ordered though); this method wraps around to the last screen.
function screen:previous()
  local screens = screen.allScreens()
  local i = fnutils.indexOf(screens, self) - 1
  if i < 1 then i = # screens end
  return screens[i]
end

local function first_screen_in_direction(screen, numrotations)
  if #screen.allScreens() == 1 then
    return nil
  end

  -- assume looking to east

  -- use the score distance/cos(A/2), where A is the angle by which it
  -- differs from the straight line in the direction you're looking
  -- for. (may have to manually prevent division by zero.)

  -- thanks mark!

  local otherscreens = fnutils.filter(screen.allScreens(), function(s) return s ~= screen end)
  local startingpoint = geometry.rectMidPoint(screen:fullFrame())
  local closestscreens = {}

  for _, s in pairs(otherscreens) do
    local otherpoint = geometry.rectMidPoint(s:fullFrame())
    otherpoint = geometry.rotateCCW(otherpoint, startingpoint, numrotations)

    local delta = {
      x = otherpoint.x - startingpoint.x,
      y = otherpoint.y - startingpoint.y,
    }

    if delta.x > 0 then
      local angle = math.atan(delta.y, delta.x)
      local distance = geometry.hypot(delta)
      local anglediff = -angle
      local score = distance / math.cos(anglediff / 2)
      table.insert(closestscreens, {s = s, score = score})
    end
  end

 -- exclude screens without any horizontal/vertical overlap
  local myf=screen:fullFrame()
  for i=#closestscreens,1,-1 do
    local of=closestscreens[i].s:fullFrame()
    if numrotations==1 or numrotations==3 then
      if of.x+of.w-1<myf.x or myf.x+myf.w-1<of.x then table.remove(closestscreens,i) end
    else
      if of.y+of.h-1<myf.y or myf.y+myf.h-1<of.y then table.remove(closestscreens,i) end
    end
  end

  table.sort(closestscreens, function(a, b) return a.score < b.score end)

  if #closestscreens > 0 then
    return closestscreens[1].s
  else
    return nil
  end
end

--- hs.screen:toEast()
--- Method
--- Get the first screen to the east of this one, ordered by proximity.
function screen:toEast()  return first_screen_in_direction(self, 0) end

--- hs.screen:toWest()
--- Method
--- Get the first screen to the west of this one, ordered by proximity.
function screen:toWest()  return first_screen_in_direction(self, 2) end

--- hs.screen:toNorth()
--- Method
--- Get the first screen to the north of this one, ordered by proximity.
function screen:toNorth() return first_screen_in_direction(self, 1) end

--- hs.screen:toSouth()
--- Method
--- Get the first screen to the south of this one, ordered by proximity.
function screen:toSouth() return first_screen_in_direction(self, 3) end

return screen
