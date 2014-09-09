--- === mjolnir.screen ===
---
--- Manipulate screens (i.e. monitors).
---
--- You usually get a screen through a window (see `mjolnir.window.screen`). But you can get screens by themselves through this module, albeit not in any defined/useful order.
---
--- Mjolnir's coordinate system assumes a grid that is the union of every screen's rect (see `mjolnir.screen.fullframe`).
---
--- Every window's position (i.e. `topleft`) and size are relative to this grid, and they're usually within the grid. A window that's semi-offscreen only intersects the grid.

local screen = require "mjolnir.screen.internal"
local fnutils = require "mjolnir.fnutils"
local geometry = require "mjolnir.geometry"

--- mjolnir.screen:fullframe() -> rect
--- Method
--- Returns the screen's rect in absolute coordinates, including the dock and menu.
function screen:fullframe()
  local primary_screen = screen.allscreens()[1]
  local f = self:_frame()
  f.y = primary_screen:_frame().h - f.h - f.y
  return f
end

--- mjolnir.screen:frame() -> rect
--- Method
--- Returns the screen's rect in absolute coordinates, without the dock or menu.
function screen:frame()
  local primary_screen = screen.allscreens()[1]
  local f = self:_visibleframe()
  f.y = primary_screen:_frame().h - f.h - f.y
  return f
end

--- mjolnir.screen:next() -> screen
--- Method
--- Returns the screen 'after' this one (I have no idea how they're ordered though); this method wraps around to the first screen.
function screen:next()
  local screens = screen.allscreens()
  local i = fnutils.indexof(screens, self) + 1
  if i > # screens then i = 1 end
  return screens[i]
end

--- mjolnir.screen:previous() -> screen
--- Method
--- Returns the screen 'before' this one (I have no idea how they're ordered though); this method wraps around to the last screen.
function screen:previous()
  local screens = screen.allscreens()
  local i = fnutils.indexof(screens, self) - 1
  if i < 1 then i = # screens end
  return screens[i]
end

local function first_screen_in_direction(screen, numrotations)
  if #screen.allscreens() == 1 then
    return nil
  end

  -- assume looking to east

  -- use the score distance/cos(A/2), where A is the angle by which it
  -- differs from the straight line in the direction you're looking
  -- for. (may have to manually prevent division by zero.)

  -- thanks mark!

  local otherscreens = fnutils.filter(screen.allscreens(), function(s) return s ~= screen end)
  local startingpoint = geometry.rectmidpoint(screen:fullframe())
  local closestscreens = {}

  for _, s in pairs(otherscreens) do
    local otherpoint = geometry.rectmidpoint(s:fullframe())
    otherpoint = geometry.rotateccw(otherpoint, startingpoint, numrotations)

    local delta = {
      x = otherpoint.x - startingpoint.x,
      y = otherpoint.y - startingpoint.y,
    }

    if delta.x > 0 then
      local angle = math.atan2(delta.y, delta.x)
      local distance = geometry.hypot(delta)
      local anglediff = -angle
      local score = distance / math.cos(anglediff / 2)
      table.insert(closestscreens, {s = s, score = score})
    end
  end

  table.sort(closestscreens, function(a, b) return a.score < b.score end)

  if #closestscreens > 0 then
    return closestscreens[1].s
  else
    return nil
  end
end

--- mjolnir.screen:toeast()
--- Method
--- Get the first screen to the east of this one, ordered by proximity.
function screen:toeast()  return first_screen_in_direction(self, 0) end

--- mjolnir.screen:towest()
--- Method
--- Get the first screen to the west of this one, ordered by proximity.
function screen:towest()  return first_screen_in_direction(self, 2) end

--- mjolnir.screen:tonorth()
--- Method
--- Get the first screen to the north of this one, ordered by proximity.
function screen:tonorth() return first_screen_in_direction(self, 1) end

--- mjolnir.screen:tosouth()
--- Method
--- Get the first screen to the south of this one, ordered by proximity.
function screen:tosouth() return first_screen_in_direction(self, 3) end

return screen
