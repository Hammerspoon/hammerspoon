--- screen:frame_including_dock_and_menu() -> rect
--- Returns the screen's rect in absolute coordinates, including the dock and menu.
function screen:frame_including_dock_and_menu()
  local primary_screen = screen.allscreens()[1]
  local f = self:frame()
  f.y = primary_screen:frame().h - f.h - f.y
  return f
end

--- screen:frame_without_dock_or_menu() -> rect
--- Returns the screen's rect in absolute coordinates, without the dock or menu.
function screen:frame_without_dock_or_menu()
  local primary_screen = screen.allscreens()[1]
  local f = self:visibleframe()
  f.y = primary_screen:frame().h - f.h - f.y
  return f
end

--- screen:next() -> screen
--- Returns the screen 'after' this one (I have no idea how they're ordered though); this method wraps around to the first screen.
function screen:next()
  local screens = screen.allscreens()
  local i = fnutils.indexof(screens, self) + 1
  if i > # screens then i = 1 end
  return screens[i]
end

--- screen:previous() -> screen
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
  local startingpoint = geometry.rectmidpoint(screen:frame_including_dock_and_menu())
  local closestscreens = {}

  for _, s in pairs(otherscreens) do
    local otherpoint = geometry.rectmidpoint(s:frame_including_dock_and_menu())
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

--- screen:toeast()
--- Get the first screen to the east of this one, ordered by proximity.
function screen:toeast()  return first_screen_in_direction(self, 0) end

--- screen:towest()
--- Get the first screen to the west of this one, ordered by proximity.
function screen:towest()  return first_screen_in_direction(self, 2) end

--- screen:tonorth()
--- Get the first screen to the north of this one, ordered by proximity.
function screen:tonorth() return first_screen_in_direction(self, 1) end

--- screen:tosouth()
--- Get the first screen to the south of this one, ordered by proximity.
function screen:tosouth() return first_screen_in_direction(self, 3) end
