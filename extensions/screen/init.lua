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

--- hs.screen.findByName(name) -> screen or nil
--- Function
--- Finds a screen by its name
---
--- Parameters:
---  * name - A string containing the name to search for
---
--- Returns:
---  * An `hs.screen` object, or nil if none could be found
function screen.findByName(name)
    return fnutils.find(screen.allScreens(), function(display) return (display:name() == name) end)
end

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

local min,max=math.min,math.max
local function projection(base, rect) -- like hs.geometry,intersectionRect, but better
  local basex,basey,basex2,basey2=base.x,base.y,base.x+base.w,base.y+base.h
  local rectx,recty,rectx2,recty2=rect.x,rect.y,rect.x+(rect.w or 0),rect.y+(rect.h or 0)
  if basex<rectx then rectx=min(basex2,rectx) rectx2=min(basex2,rectx2)
  else rectx=max(basex,rectx) rectx2=max(basex,rectx2) end
  if basey<recty then recty=min(basey2,recty) recty2=min(basey2,recty2)
  else recty=max(basey,recty) recty2=max(basey,recty2) end
  return {x=rectx,y=recty,w=rectx2-rectx,h=recty2-recty}
end

local function first_screen_in_direction(screen, numrotations, from, strict)
  if #screen.allScreens() == 1 then
    return nil
  end

  -- assume looking to east

  -- use the score distance/cos(A/2), where A is the angle by which it
  -- differs from the straight line in the direction you're looking
  -- for. (may have to manually prevent division by zero.)

  -- thanks mark!

  local otherscreens = fnutils.filter(screen.allScreens(), function(s) return s ~= screen end)
  local myf=screen:fullFrame()
  local startingpoint = geometry.rectMidPoint(from and projection(myf,from) or myf)
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

  if strict or (screen.strictScreenInDirection and strict~=false) then
    -- exclude screens without any horizontal/vertical overlap
    for i=#closestscreens,1,-1 do
      local of=closestscreens[i].s:fullFrame()
      if numrotations==1 or numrotations==3 then
        if of.x+of.w-1<myf.x or myf.x+myf.w-1<of.x then table.remove(closestscreens,i) end
      else
        if of.y+of.h-1<myf.y or myf.y+myf.h-1<of.y then table.remove(closestscreens,i) end
      end
    end
  end
  table.sort(closestscreens, function(a, b) return a.score < b.score end)

  if #closestscreens > 0 then
    return closestscreens[1].s
  else
    return nil
  end
end

--- hs.screen.strictScreenInDirection
--- Variable
--- If set to `true`, the methods `hs.screen:toEast()`, `:toNorth()` etc. will disregard screens that lie perpendicularly to the desired axis
screen.strictScreenInDirection = false

--- hs.screen:toEast()
--- Method
--- Get the first screen to the east of this one, ordered by proximity to its center or a specified point.
---
--- Parameters:
---   * from - An `hs.geometry.rect` or `hs.geometry.point` object; if omitted, the geometric center of this screen will be used
---   * strict - If `true`, disregard screens that lie completely above or below this one (alternatively, set `hs.screen.strictScreenInDirection`)
function screen:toEast(...)  return first_screen_in_direction(self, 0, ...) end

--- hs.screen:toWest()
--- Method
--- Get the first screen to the west of this one, ordered by proximity to its center or a specified point.
--- Parameters:
---   * from - An `hs.geometry.rect` or `hs.geometry.point` object; if omitted, the geometric center of this screen will be used
---   * strict - If `true`, disregard screens that lie completely above or below this one (alternatively, set `hs.screen.strictScreenInDirection`)
function screen:toWest(...)  return first_screen_in_direction(self, 2, ...) end

--- hs.screen:toNorth()
--- Method
--- Get the first screen to the north of this one, ordered by proximity to its center or a specified point.
--- Parameters:
---   * from - An `hs.geometry.rect` or `hs.geometry.point` object; if omitted, the geometric center of this screen will be used
---   * strict - If `true`, disregard screens that lie completely to the left or to the right of this one (alternatively, set `hs.screen.strictScreenInDirection`)
function screen:toNorth(...) return first_screen_in_direction(self, 1, ...) end

--- hs.screen:toSouth()
--- Method
--- Get the first screen to the south of this one, ordered by proximity to its center or a specified point.
--- Parameters:
---   * from - An `hs.geometry.rect` or `hs.geometry.point` object; if omitted, the geometric center of this screen will be used
---   * strict - If `true`, disregard screens that lie completely to the left or to the right of this one (alternatively, set `hs.screen.strictScreenInDirection`)
function screen:toSouth(...) return first_screen_in_direction(self, 3, ...) end

return screen
