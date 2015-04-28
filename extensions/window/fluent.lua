--- === hs.window.fluent ===
---
--- A module for moving/resizing windows using a fluent interface (see Usage below).
---
--- Usage:
---
---     local window = require "hs.window.fluent"
---
---     local cmdalt  = {"cmd", "alt"}
---     local scmdalt = {"cmd", "alt", "shift"}
---     local ccmdalt = {"ctrl", "cmd", "alt"}
---
---     -- make the focused window a 200px, full-height window and put it at the left screen edge
---     hs.hotkey.bind(cmdalt, 'h', window.focused():wide(200):tallest():leftmost():place())
---
---     -- make a full-height window and put it at the right screen edge
---     hs.hotkey.bind(cmdalt, 'j', window.focused():tallest():rightmost():place())
---
---     -- full-height window, full-width window, and a combination
---     hs.hotkey.bind(scmdalt, '\\', window.focused():tallest():resize())
---     hs.hotkey.bind(scmdalt, '-', window.focused():widest():resize())
---     hs.hotkey.bind(scmdalt, '=', window.focused():widest():tallest():resize())
---
---     -- push to different screen
---     hs.hotkey.bind(cmdalt, '[', window.focused():prevscreen():move())
---     hs.hotkey.bind(cmdalt, ']', window.focused():nextscreen():move())
---
--- *NOTE*: One must start with `window.focused()` or `window.window('title')`
--- and end with a command `move()`, `place()`, `resize()`, or `act()`
--- (they are all synonyms for the same action). This chain of command
--- will return a function that one can pass to `hs.hotkey.bind`.
---
---
--- @author    Nikola Knezevic
--- @copyright 2015
---

-- main module class table
local fluent = {
  _VERSION     = '0.5.0',
  _DESCRIPTION = 'A module for moving/resizing windows using a fluent interface',
}

local appfinder = require "hs.appfinder"
local window = require "hs.window"
-- also requires hs.screen

-- class that deals with coordinate transformations.
-- Default coordinate transformations are regular screen transformations.
-- However, this abstraction allows to easily extend winter.fluent to work with
-- grids, by passing a right CoordTrans object.
local CoordTrans = {}

--- hs.window.CoordTrans:get(win[, scr]) -> table
--- Method
--- Returns coordinates of the window on the screen.
---
--- Parameters:
---  * win - the window whose coordinates are reqired
---  * scr - the screen on which coordinates are required. Defaults to window's screen.
---
--- Returns:
---  * A table containing {x, y, w, h, screenw, screenh}. 'screenh'/'screenw' are
---    screens width and height
---
--- Notes:
---  * One could modify this method to return coordinates on a grid, for example
function CoordTrans:get(win, scr)
  local f = win:frame()
  local screen = scr or win:screen()
  local screenrect = screen:frame()

  return {
    x = f.x - screenrect.x,
    y = f.y - screenrect.y,
    w = f.w,
    h = f.h,
    screenw = screenrect.w,
    screenh = screenrect.h,
  }
end

--- hs.window.CoordTrans:set(win, screen, f) -> nil
--- Method
--- Places a window on the screen, given the coordinates described in parameter f
---
--- Parameters:
---  * win - the window to place
---  * scr - the screen on which the win will be placed
---  * f - table containing the coordinates. It has to have {x, y, w, h} fields.
---
--- Returns:
---  * None
function CoordTrans:set(win, screen, f)
  local screenrect = screen:frame()

  newf = {
    x = f.x + screenrect.x,
    y = f.y + screenrect.y,
    w = f.w,
    h = f.h,
  }
  win:setFrame(newf)
end

-- instantiates a CoordTrans object
local function new_coord_trans()
  local self = {}
  setmetatable(self, { __index = CoordTrans })
  return self
end

--- hs.window.fluent.new([ct]) -> window.fluent object
--- Function
--- Creates an instance of the window.fluent object that could be used to manipulate windows in a given coordinate system.
---
--- Parameters:
---  * ct - CoordTrans object
---
--- Returns:
---  * A string with some important result, or nil if an error occurred
---
--- Notes:
--- * CoordTrans is an object though which one gets coordinates for a window on the
---   screen, and can use these (possibly modified) coordinates to set a window
---   on a screen. See CoordTrans description.
function fluent.new(ct)
  local self = {}
  self.ct = ct or new_coord_trans()
  setmetatable(self, { __index = fluent })
  return self
end

-- class table representing an action on a window
-- this will be the internal object to cary the state around
local WindowFluentAction = {}

local function init_window_fluent_action(title)
  return {
    -- coord transformer
    ct = 0,
    -- title of the window, '' denotes the focused window
    title = title,
    -- location
    x = -1,
    y = -1,
    -- dimensions
    w = 0,
    h = 0,
    -- changes accrued in the methods
    dx = 0,
    dy = 0,
    dw = 0,
    dh = 0,
    -- centering
    _vcenter = false,
    _hcenter = false,
    -- screen
    _mainscreen = false,
    dscreen = 0, -- for prev/next
    screen_compass = {}, -- for east/west/north/south
    -- 'mosts'
    _tallest = false,
    _widest = false,
    _leftmost = false,
    _rightmost = false,
    _topmost = false,
    _bottommost = false,
  }
end

--- hs.window.fluent.focused([ct]) -> window.fluent object
--- Function
--- Creates an instance of the window.fluent object that could be used to manipulate the currently focused window in a given coordinate system.
---
--- Parameters:
---  * ct - CoordTrans object
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
---
--- Notes:
--- * CoordTrans is an object though which one gets coordinates for a window on the
---   screen, and can use these (possibly modified) coordinates to set a window
---   on a screen. See CoordTrans description.
function fluent.focused(ct)
  local self = fluent.new(ct)
  self.wa = init_window_fluent_action('')
  return self
end

--- hs.window.fluent.window(title[, ct]) -> window.fluent object
--- Function
--- Creates an instance of the window.fluent object that could be used to manipulate a window with the title 'title', in a given coordinate system.
---
--- Parameters:
---  * title - title of the window on which one could apply manipulations. Must be non-empty
---  * ct - CoordTrans object
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
---
--- Notes:
--- * CoordTrans is an object though which one gets coordinates for a window on the
---   screen, and can use these (possibly modified) coordinates to set a window
---   on a screen. See CoordTrans description.
function fluent.window(title, ct)
  assert(title and title ~= '', 'Cannot find a window without a title')
  local self = fluent.new(ct)
  self.wa = init_window_fluent_action(title)
  return self
end

--- hs.window.fluent:snap(win)
--- Method
--- Snaps the window into a cell
---
--- Parameters:
---  * win - hs.window object to be snapped
function fluent:snap(win)
  if win:isstandard() then
    self.ct:set(win, self:get(win), win:screen())
  end
end

--- hs.window.fluent:xpos([x]) -> window.fluent object
--- Method
--- Sets windows' x position to x
---
--- Parameters:
---  * x - desired x coordinate, default 0
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
function fluent:xpos(x)
  self.wa.x = x or 0
  self.wa._leftmost = false
  self.wa._rightmost = false
  return self
end

--- hs.window.fluent:ypos([y]) -> window.fluent object
--- Method
--- Sets windows' y position to y
---
--- Parameters:
---  * y - desired y coordinate, default 0
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
function fluent:ypos(y)
  self.wa.y = y or 0
  self.wa._topmost = false
  self.wa._bottommost = false
  return self
end

--- hs.window.fluent:right([by]) -> window.fluent object
--- Method
--- Moves the window to the right 'by' units
---
--- Parameters:
---  * by - desired number of units to move the window, default 1
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
function fluent:right(by)
  self.wa.dx = self.wa.dx + (by or 1)
  return self
end

--- hs.window.fluent:left([by]) -> window.fluent object
--- Method
--- Moves the window to the left 'by' units.
---
--- Parameters:
---  * by - desired number of units to move the window, default 1
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
function fluent:left(by)
  self.wa.dx = self.wa.dx - (by or 1)
  return self
end

--- hs.window.fluent:up([by]) -> window.fluent object
--- Method
--- Moves the window to the up 'by' units.
---
--- Parameters:
---  * by - desired number of units to move the window, default 1
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
function fluent:up(by)
  self.wa.dy = self.wa.dy - (by or 1)
  return self
end

--- hs.window.fluent:down([by]) -> window.fluent object
--- Method
--- Moves the window to the down 'by' units.
---
--- Parameters:
---  * x - desired x coordinate
---  * by - desired number of units to move the window, default 1
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
function fluent:down(by)
  self.wa.dy = self.wa.dy + (by or 1)
  return self
end

--- hs.window.fluent:wide(w) -> window.fluent object
--- Method
--- Set's the window to be w units wide.
---
--- Parameters:
---  * w - desired width of the window
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
---
--- Notes:
---  * Overrides any previous calls to set the window's width
function fluent:wide(w)
  self.wa.w = w
  self.wa._widest = false
  return self
end

--- hs.window.fluent:tall(h) -> window.fluent object
--- Method
--- Set's the window to be h units tall.
---
--- Parameters:
---  * h - desired height of the window
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
---
--- Notes:
---  * Overrides any previous calls to set the window's height
function fluent:tall(h)
  self.wa.h = h
  self.wa._tallest = false
  return self
end

--- hs.window.fluent:thinner(by) -> window.fluent object
--- Method
--- Makes the window thinner by 'by' units.
---
--- Parameters:
---  * by - desired number of units to reduce the width of the window. If negative, increases the width of the window. Default value is 1.
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
---
--- Notes:
---  * Overrides any previous calls to set the window's width
function fluent:thinner(by)
  self.wa.dw = self.wa.dw - (by or 1)
  self.wa._widest = false
  return self
end

--- hs.window.fluent:wider(by) -> window.fluent object
--- Method
--- Makes the window wider by 'by' units.
---
--- Parameters:
---  * by - desired number of units to increase the width of the window. If negative, reduces the width of the window. Default value is 1.
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
---
--- Notes:
---  * Overrides any previous calls to set the window's width
function fluent:wider(by)
  self.wa.dw = self.wa.dw + (by or 1)
  self.wa._widest = false
  return self
end

--- hs.window.fluent:taller(by) -> window.fluent object
--- Method
--- Makes the window taller by 'by' units.
---
--- Parameters:
---  * by - desired number of units to increase the height of the window. If negative, reduces the height of the window. Default value is 1.
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
---
--- Notes:
---  * Overrides any previous calls to set the window's height
function fluent:taller(by)
  self.wa.dh = self.wa.dh + (by or 1)
  self.wa._tallest = false
  return self
end

--- hs.window.fluent:shorter(by) -> window.fluent object
--- Method
--- Makes the window shorter by 'by' units.
---
--- Parameters:
---  * by - desired number of units to reduce the height of the window. If negative, increases the height of the window. Default value is 1.
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
---
--- Notes:
---  * Overrides any previous calls to set the window's height
function fluent:shorter(by)
  self.wa.dh = self.wa.dh - (by or 1)
  self.wa._tallest = false
  return self
end

--- hs.window.fluent:tallest() -> window.fluent object
--- Method
--- Makes windows' height the height of the screen.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
---
--- Notes:
---  * Overrides any previous calls to set the window's height
function fluent:tallest()
  self.wa._tallest = true
  self.wa.dh = 0
  self.wa.h = 0
  self.wa.y = 0
  return self
end

--- hs.window.fluent:widest() -> window.fluent object
--- Method
--- Makes windows' width the width of the screen.
---
--- Parameters:
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
---
--- Notes:
---  * Overrides any previous calls to set the window's width
function fluent:widest()
  self.wa._widest = true
  self.wa.dw = 0
  self.wa.w = 0
  self.wa.x = 0
  return self
end

--- hs.window.fluent:leftmost() -> window.fluent object
--- Method
--- Makes the window align with the left screen border.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
---
--- Notes:
---  * Any preceding commands to change the horizontal position of the window are forgotten.
function fluent:leftmost()
  self.wa.dx = 0
  self.wa._leftmost = true
  return self
end

--- hs.window.fluent:rightmost() -> window.fluent object
--- Method
--- Makes the window align with the right screen border.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
---
--- Notes:
---  * Any preceding commands to change the horizontal position of the window are forgotten.
function fluent:rightmost()
  self.wa.dx = 0
  self.wa._rightmost = true
  return self
end

--- hs.window.fluent:topmost() -> window.fluent object
--- Method
--- Makes the window align with the top screen border.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
---
--- Notes:
---  * Any preceding commands to change the horizontal position of the window are forgotten.
function fluent:topmost()
  self.wa.dy = 0
  self.wa._topmost = true
  return self
end

--- hs.window.fluent:bottommost() -> window.fluent object
--- Method
--- Makes the window align with the bottom screen border.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
---
--- Notes:
---  * Any preceding commands to change the horizontal position of the window are forgotten.
function fluent:bottommost()
  self.wa.dy = 0
  self.wa._bottommost = true
  return self
end

--- hs.window.fluent:nextscreen() -> window.fluent object
--- Method
--- Moves the focused window to the next screen, using its current position on that screen.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
---
--- Notes:
--- * Will reset any of the directional commands (screen() with param 'east'/'west'/'south'/'north').
function fluent:nextscreen()
  -- self._mainscreen = false
  self.wa.screen_compass = {}
  self.wa.dscreen = self.wa.screen + 1
  return self
end

--- hs.window.fluent:prevscreen() -> window.fluent object
--- Method
--- Moves the window to the previous screen, using its current position on that screen.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
---
--- Notes:
--- * Will reset any of the directional commands (screen() with param 'east'/'west'/'south'/'north').
function fluent:prevscreen()
  -- self._mainscreen = false
  self.wa.screen_compass = {}
  self.wa.dscreen = self.wa.dscreen - 1
  return self
end

--- hs.window.fluent:mainscreen() -> window.fluent object
--- Method
--- Moves the window to the main screen, using its current position on that screen.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
---
--- Notes:
--- * Will reset any of the directional commands (screen() with param 'east'/'west'/'south'/'north').
function fluent:mainscreen()
  self.wa._mainscreen = true
  self.wa.screen_compass = {}
  self.wa.dscreen = 0
  return self
end

--- hs.window.fluent:screen(direction) -> window.fluent object
--- Method
--- Moves the window to the screen denoted with direction, using its current position on that screen.
--- Direction must be one of 'east', 'west', 'north', or 'south'. If direction is missing,
--- the function does nothing.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
---
--- Notes:
--- *An invocation of this method with a valid parameter will reset actions of any previous call to previous or next screen, but not mainscreen().
function fluent:screen(direction)
  if not direction then
    return self
  end
  local directions = { east=true, west=true, north=true, south=true }
  if not items[direction] then
    alert("Direction " .. direction .. " not recognized for screen(direction)")
    return self
  end
  self.wa.dscreen = 0
  table.insert(self.wa.screen_compass, direction)
  return self
end

--- hs.window.fluent:vcenter() -> window.fluent object
--- Method
--- Does a vertical centering of the window on the screen. This method
--- might not do anything if it is not sensible for a given setting
--- (for example, on a 2x2 grid, where window is 1 cell wide).
---
--- Parameters:
---  * None
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
function fluent:vcenter()
  self.wa._vcenter = true
  self.wa._dx = 0
  self.wa._x = -1
  return self
end

--- hs.window.fluent:hcenter() -> window.fluent object
--- Method
--- Does a horizontal centering of the window on the screen. This method
--- might not do anything if it is not sensible for a given setting
--- (for example, on a 2x2 grid, where window is 1 cell high).
---
--- Parameters:
---  * None
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
function fluent:hcenter()
  self.wa._hcenter = true
  self.wa._dy = 0
  self.wa._y = -1
  return self
end

--- hs.window.fluent:act() -> window.fluent object
--- Method
--- Finalizes all previous commands for changing windows' size and
--- position. This command will produce an anonymous, parameterless
--- function that can be fed to hotkey.bind method (from hs.hotkey
--- package).
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function fluent:act()
  return function()
    local f = {}
    local win = nil
    if self.wa.title and self.wa.title ~= '' then
      local app = appfinder.appFromName(self.wa.title)
      if not app then
        error(string.format('Could not find application with title "%s"', self.wa.title))
      end
      win = app:mainWindow()
      if not win then
        error(string.format('Application "%s" does not have a main window', self.wa.title))
      end
    else
      win = window.focusedWindow()
    end

    -- first, determine the screen where the window should go
    local screen = win:screen()
    if self.wa._mainscreen then
      screen = hs.screen.mainScreen()
    end
    local dscreen = self.wa.dscreen
    while dscreen < 0 do
      screen = screen:previous()
      dscreen = dscreen + 1
    end
    while dscreen > 0 do
      screen = screen:next()
      dscreen = dscreen - 1
    end
    for _, v in pairs(self.wa.screen_compass) do
      if v == 'east' then screen = screen:toeast()
      elseif v == 'west' then screen = screen:towest()
      elseif v == 'north' then screen = screen:tonorth()
      elseif v == 'south' then screen = screen:tosouth()
      else error("Direction " .. v .. " for screen is not recognized") end
    end

    -- now do the window placement
    local origf = self.ct:get(win, screen)

    -- take defaults
    f.w = (self.wa.w == 0) and origf.w or self.wa.w
    f.h = (self.wa.h == 0) and origf.h or self.wa.h
    f.x = (self.wa.x == -1) and origf.x or self.wa.x
    f.y = (self.wa.y == -1) and origf.y or self.wa.y

    -- widest and tallest

    if self.wa._widest then
      f.w = origf.screenw
    end
    if self.wa._tallest then
      f.h = origf.screenh
    end
    -- adjust width and height
    if self.wa.dw ~= 0 then
      f.w = math.min(origf.screenw, math.max(1, f.w + self.wa.dw))
    end
    if self.wa.dh ~= 0 then
      f.h = math.min(origf.screenh, math.max(1, f.h + self.wa.dh))
    end

    -- centering
    if self.wa._vcenter then
       f.x = math.max(0, (origf.screenw - f.w)/2)
    end

    if self._hcenter then
       f.y = math.max(0, (origf.screenh - f.h)/2)
    end

    -- and positions
    if self.wa._topmost then
       f.y = 0
    end
    if self.wa._leftmost then
       f.x = 0
    end
    if self.wa._rightmost then
       f.x = origf.screenw - f.w
    end
    if self.wa._bottommost then
       f.y = origf.screenh - f.h
    end

    if self.wa.dx ~= 0 then
      f.x = math.min(origf.screenw, math.max(0, f.x + self.wa.dx))
    end
    if self.wa.dy ~= 0 then
      f.y = math.min(origf.screenh, math.max(0, f.y + self.wa.dy))
    end

    self.ct:set(win, screen, f)
  end
end

--- hs.window.fluent:resize() -> window.fluent object
--- Method
--- Alias for act()
fluent.resize = fluent.act
--- hs.window.fluent:move() -> window.fluent object
--- Method
--- Alias for act()
fluent.move = fluent.act
--- hs.window.fluent:place() -> window.fluent object
--- Method
--- Alias for act()
fluent.place = fluent.act

return fluent
