--- === hs.window ===
---
--- Inspect/manipulate windows
---
--- Notes:
---  * See `hs.screen` for detailed explanation of how Hammerspoon uses window/screen coordinates.

local uielement = hs.uielement  -- Make sure parent module loads
local window = require "hs.window.internal"
local application = require "hs.application.internal"
local fnutils = require "hs.fnutils"
local geometry = require "hs.geometry"
local hs_screen = require "hs.screen"

--- hs.window.animationDuration (integer)
--- Variable
--- The default duration for animations, in seconds. Set to 0 to disable animations
window.animationDuration = 0.2

--- hs.window.allWindows() -> win[]
--- Function
--- Returns all windows
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table of `hs.window` objects representing all open windows
function window.allWindows()
  return fnutils.mapCat(application.runningApplications(), application.allWindows)
end

--- hs.window.windowForID(id) -> win or nil
--- Function
--- Returns the window for a given id
---
--- Parameters:
---  * id - A window ID (see `hs.window:id()`)
---
--- Returns:
---  * An `hs.window` object, or nil if the window can't be found
function window.windowForID(id)
  return fnutils.find(window.allWindows(), function(win) return win:id() == id end)
end

--- hs.window:isVisible() -> bool
--- Method
--- Determines if a window is visible (i.e. not hidden and not minimized)
---
--- Parameters:
---  * None
---
--- Returns:
---  * True if the window is visible, otherwise false
---
--- Notes:
---  * This does not mean the user can see the window - it may be obscured by other windows, or it may be off the edge of the screen
function window:isVisible()
  return not self:application():isHidden() and not self:isMinimized()
end

--- hs.window:frame() -> rect
--- Method
--- Gets the frame of the window in absolute coordinates
---
--- Parameters:
---  * None
---
--- Returns:
---  * A rect-table containing the co-ordinates of the top left corner of the window, and it's width and height
function window:frame()
  local s = self:size()
  local tl = self:topLeft()
  return {x = tl.x, y = tl.y, w = s.w, h = s.h}
end

--- hs.window:setFrame(rect[, duration]) -> window
--- Method
--- Sets the frame of the window in absolute coordinates
---
--- Parameters:
---  * rect - A rect-table containing the co-ordinates and size that should be applied to the window
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function window:setFrame(f, duration)
  if duration == nil then
    duration = window.animationDuration
  end
  if duration > 0 then
    self:transform({ x = f.x, y = f.y}, { w = f.w, h = f.h }, duration)
  else
    self:setSize(f)
    self:setTopLeft(f)
    self:setSize(f)
  end
end

--- hs.window:otherWindowsSameScreen() -> win[]
--- Method
--- Gets other windows on the same screen
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table of `hs.window` objects representing the other windows that are on the same screen as this one
function window:otherWindowsSameScreen()
  return fnutils.filter(window.visibleWindows(), function(win) return self ~= win and self:screen() == win:screen() end)
end

--- hs.window:otherWindowsAllScreens() -> win[]
--- Method
--- Gets every window except this one
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table containing `hs.window` objects representing all windows other than this one
function window:otherWindowsAllScreens()
  return fnutils.filter(window.visibleWindows(), function(win) return self ~= win end)
end

--- hs.window:focus() -> window
--- Method
--- Focuses the window
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.window` object
function window:focus()
    self:becomeMain()
    self:application():_bringtofront()
    return self
end

--- hs.window.visibleWindows() -> win[]
--- Function
--- Gets all visible windows
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table containing `hs.window` objects representing all windows that are visible (see `hs.window:isVisible()` for information about what constitutes a visible window)
function window.visibleWindows()
  return fnutils.filter(window:allWindows(), window.isVisible)
end

--- hs.window.orderedWindows() -> win[]
--- Function
--- Returns all visible windows, ordered from front to back
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table of `hs.window` objects representing all visible windows, ordered from front to back
function window.orderedWindows()
  local orderedwins = {}
  local orderedwinids = window._orderedwinids()
  local windows = window.visibleWindows()

  for _, orderedwinid in pairs(orderedwinids) do
    for _, win in pairs(windows) do
      if orderedwinid == win:id() then
        table.insert(orderedwins, win)
        break
      end
    end
  end

  return orderedwins
end

--- hs.window:maximize([duration]) -> window
--- Method
--- Maximizes the window
---
--- Parameters:
---  * duration - An optional number containing the number of seconds to animate the operation. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
---
--- Notes:
---  * The window will be resized as large as possible, without obscuring the dock/menu
function window:maximize(duration)
  local screenrect = self:screen():frame()
  self:setFrame(screenrect, duration)
  return self
end

--- hs.window:toggleFullScreen() -> window
--- Method
--- Toggles the fullscreen state of the window
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.window` object
---
--- Notes:
---  * Not all windows support being full-screened
function window:toggleFullScreen()
    self:setFullScreen(not self:isFullScreen())
    return self
end

--- hs.window:screen()
--- Method
--- Gets the screen which the window is on
---
--- Parameters:
---  * None
---
--- Returns:
---  * An `hs.screen` object representing the screen which most contains the window (by area)
function window:screen()
  local windowframe = self:frame()
  local lastvolume = 0
  local lastscreen = nil

  for _, screen in pairs(hs_screen.allScreens()) do
    local screenframe = screen:fullFrame()
    local intersection = geometry.intersectionRect(windowframe, screenframe)
    local volume = intersection.w * intersection.h

    if volume > lastvolume then
      lastvolume = volume
      lastscreen = screen
    end
  end

  return lastscreen
end

local function windowsInDirection(srcwin, numrotations)
  -- assume looking to east

  -- use the score distance/cos(A/2), where A is the angle by which it
  -- differs from the straight line in the direction you're looking
  -- for. (may have to manually prevent division by zero.)

  -- thanks mark!

  local startingpoint = geometry.rectMidPoint(srcwin:frame())

  local otherwindows = fnutils.filter(window.orderedWindows(), function(candidate)
      return window.isVisible(candidate) and window.isStandard(candidate) and not (candidate == srcwin)
  end)
  local closestwindows = {}

  for zposition, win in ipairs(otherwindows) do
    local otherpoint = geometry.rectMidPoint(win:frame())
    otherpoint = geometry.rotateCCW(otherpoint, startingpoint, numrotations)

    local delta = {
      x = otherpoint.x - startingpoint.x,
      y = otherpoint.y - startingpoint.y,
    }

    if delta.x > 0 then
      local angle = math.atan(delta.y, delta.x)
      local distance = geometry.hypot(delta)

      local anglediff = -angle

      local score = (distance / math.cos(anglediff / 2)) + zposition

      table.insert(closestwindows, {win = win, score = score})
    end
  end

  table.sort(closestwindows, function(a, b) return a.score < b.score end)
  return fnutils.map(closestwindows, function(x) return x.win end)
end

local function focus_first_valid_window(ordered_wins)
  for _, win in pairs(ordered_wins) do
    if win:focus() then return true end
  end
  return false
end

--- hs.window:windowsToEast() -> win[]
--- Method
--- Gets all windows to the east
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table of `hs.window` objects representing all windows positioned east (i.e. right) of the window, in ascending order of distance
function window:windowsToEast()  return windowsInDirection(self, 0) end

--- hs.window:windowsToWest()
--- Method
--- Gets all windows to the west
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table of `hs.window` objects representing all windows positioned west (i.e. left) of the window, in ascending order of distance
function window:windowsToWest()  return windowsInDirection(self, 2) end

--- hs.window:windowsToNorth()
--- Method
--- Gets all windows to the north
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table of `hs.window` objects representing all windows positioned north (i.e. up) of the window, in ascending order of distance
function window:windowsToNorth() return windowsInDirection(self, 1) end

--- hs.window:windowsToSouth()
--- Method
--- Gets all windows to the south
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table of `hs.window` objects representing all windows positioned south (i.e. down) of the window, in ascending order of distance
function window:windowsToSouth() return windowsInDirection(self, 3) end

function window:focusWindowsFromTable(searchWindows, sameApp)
    if sameApp == true then
        local winApplication = self:application()
        searchWindows = fnutils.filter(searchWindows, function(win) return winApplication == win:application() end)
    end
    return focus_first_valid_window(searchWindows)
end

--- hs.window:focusWindowEast([sameApp])
--- Method
--- Focuses the nearest possible window to the east
---
--- Parameters:
---  * sameApp - An optional boolean, true to only consider windows from the same application, false to consider all windows. Defaults to false
---
--- Returns:
---  * None
function window:focusWindowEast(sameApp)
    return self:focusWindowsFromTable(self:windowsToEast(), sameApp)
end

--- hs.window:focusWindowWest([sameApp])
--- Method
--- Focuses the nearest possible window to the west
---
--- Parameters:
---  * sameApp - An optional boolean, true to only consider windows from the same application, false to consider all windows. Defaults to false
---
--- Returns:
---  * None
function window:focusWindowWest(sameApp)
    return self:focusWindowsFromTable(self:windowsToWest(), sameApp)
end

--- hs.window:focusWindowNorth([sameApp])
--- Method
--- Focuses the nearest possible window to the north
---
--- Parameters:
---  * sameApp - An optional boolean, true to consider windows from the same application, false to consider all windows. Defaults to false
---
--- Returns:
---  * None
function window:focusWindowNorth(sameApp)
    return self:focusWindowsFromTable(self:windowsToNorth(), sameApp)
end

--- hs.window:focusWindowSouth([sameApp])
--- Method
--- Focuses the nearest possible window to the south
---
--- Parameters:
---  * sameApp - An optional boolean, true to consider windows from the same application, false to consider all windows. Defaults to false
---
--- Returns:
---  * None
function window:focusWindowSouth(sameApp)
    return self:focusWindowsFromTable(self:windowsToSouth(), sameApp)
end

--- hs.window:moveToUnit(rect[, duration]) -> window
--- Method
--- Moves and resizes the window to occupy a given fraction of the screen
---
--- Parameters:
---  * rect - A unit-rect-table where each value is between 0.0 and 1.0
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
---
--- Notes:
--   * An example, which would make a window fill the top-left quarter of the screen: `win:moveToUnit({x=0, y=0, w=0.5, h=0.5})`
function window:moveToUnit(unit, duration)
  local screenrect = self:screen():frame()
  self:setFrame({
      x = screenrect.x + (unit.x * screenrect.w),
      y = screenrect.y + (unit.y * screenrect.h),
      w = unit.w * screenrect.w,
      h = unit.h * screenrect.h,
  }, duration)
  return self
end

--- hs.window:moveToScreen(screen[, duration]) -> window
--- Method
--- Moves the window to a given screen, retaining its relative position and size
---
--- Parameters:
---  * screen - An `hs.screen` object representing the screen to move the window to
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function window:moveToScreen(nextScreen, duration)
  local currentFrame = self:frame()
  local screenFrame = self:screen():frame()
  local nextScreenFrame = nextScreen:frame()
  self:setFrame({
    x = ((((currentFrame.x - screenFrame.x) / screenFrame.w) * nextScreenFrame.w) + nextScreenFrame.x),
    y = ((((currentFrame.y - screenFrame.y) / screenFrame.h) * nextScreenFrame.h) + nextScreenFrame.y),
    h = ((currentFrame.h / screenFrame.h) * nextScreenFrame.h),
    w = ((currentFrame.w / screenFrame.w) * nextScreenFrame.w)
  }, duration)
  return self
end

--- hs.window:moveOneScreenWest([duration]) -> window
--- Method
--- Moves the window one screen west (i.e. left)
---
--- Parameters:
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function window:moveOneScreenWest(duration)
    local dst = self:screen():toWest()
    if dst ~= nil then
        self:moveToScreen(dst, duration)
    end
    return self
end

--- hs.window:moveOneScreenEast([duration]) -> window
--- Method
--- Moves the window one screen east (i.e. right)
---
--- Parameters:
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function window:moveOneScreenEast(duration)
    local dst = self:screen():toEast()
    if dst ~= nil then
        self:moveToScreen(dst, duration)
    end
    return self
end

--- hs.window:moveOneScreenNorth([duration]) -> window
--- Method
--- Moves the window one screen north (i.e. up)
---
--- Parameters:
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function window:moveOneScreenNorth(duration)
    local dst = self:screen():toNorth()
    if dst ~= nil then
        self:moveToScreen(dst, duration)
    end
    return self
end

--- hs.window:moveOneScreenSouth([duration]) -> window
--- Method
--- Moves the window one screen south (i.e. down)
---
--- Parameters:
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function window:moveOneScreenSouth(duration)
    local dst = self:screen():toSouth()
    if dst ~= nil then
        self:moveToScreen(dst, duration)
    end
    return self
end

--- hs.window:ensureIsInScreenBounds([duration]) -> window
--- Method
--- Movies and resizes the window to ensure it is inside the screen
---
--- Parameters:
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function window:ensureIsInScreenBounds(duration)
  local frame = self:frame()
  local screenFrame = self:screen():frame()
  if frame.x < screenFrame.x then frame.x = screenFrame.x end
  if frame.y < screenFrame.y then frame.y = screenFrame.y end
  if frame.w > screenFrame.w then frame.w = screenFrame.w end
  if frame.h > screenFrame.h then frame.h = screenFrame.h end
  if frame.x + frame.w > screenFrame.x + screenFrame.w then
    frame.x = (screenFrame.x + screenFrame.w) - frame.w
  end
  if frame.y + frame.h > screenFrame.y + screenFrame.h then
    frame.y = (screenFrame.y + screenFrame.h) - frame.h
  end
  if frame ~= self:frame() then self:setFrame(frame, duration) end
  return self
end

return window
