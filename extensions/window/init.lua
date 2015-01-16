--- === hs.window ===
---
--- Inspect/manipulate windows
---
--- To get windows, see `hs.window.focusedWindow` and `hs.window.visibleWindows`.
---
--- To get window geometrical attributes, see `hs.window.{frame,size,topLeft}`.
---
--- To move and resize windows, see `hs.window.set{frame,size,topLeft}`.
---
--- It may be handy to get a window's app or screen via `hs.window.application` and `hs.window.screen`.
---
--- See the `screen` module for detailed explanation of how Hammerspoon uses window/screen coordinates.

local uielement = hs.uielement  -- Make sure parent module loads
local window = require "hs.window.internal"
local application = require "hs.application.internal"
local fnutils = require "hs.fnutils"
local geometry = require "hs.geometry"
local hs_screen = require "hs.screen"

--- hs.window.animationDuration (boolean)
--- Variable
--- This is the default duration for animations. Set to 0 to disable animations.
window.animationDuration = 0.2

--- hs.window.allWindows() -> win[]
--- Function
--- Returns all windows
function window.allWindows()
  return fnutils.mapCat(application.runningApplications(), application.allWindows)
end

--- hs.window.windowForID() -> win or nil
--- Function
--- Returns the window for the given id, or nil if it's an invalid id.
function window.windowForID(id)
  return fnutils.find(window.allWindows(), function(win) return win:id() == id end)
end

--- hs.window:isVisible() -> bool
--- Method
--- True if the app is not hidden and the window is not minimized.
--- NOTE: some apps (e.g. in Adobe Creative Cloud) have literally-invisible windows and also like to put them very far offscreen; this method may return true for such windows.
function window:isVisible()
  return not self:application():isHidden() and not self:isMinimized()
end

--- hs.window:frame() -> rect
--- Method
--- Get the frame of the window in absolute coordinates.
function window:frame()
  local s = self:size()
  local tl = self:topLeft()
  return {x = tl.x, y = tl.y, w = s.w, h = s.h}
end

--- hs.window:setFrame(rect, duration)
--- Method
--- Set the frame of the window in absolute coordinates.
---
--- The window will be animated to its new position and the animation will run for 'duration' seconds.
---
--- If you don't specify a value for the duration, the default is whatever is in hs.window.animationDuration.
--- If you specify 0 as the value of duration, the window will be immediately snapped to its new location
--- with no animation.
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
--- Get other windows on the same screen as self.
function window:otherWindowsSameScreen()
  return fnutils.filter(window.visibleWindows(), function(win) return self ~= win and self:screen() == win:screen() end)
end

--- hs.window:otherWindowsAllScreens() -> win[]
--- Method
--- Get every window except this one.
function window:otherWindowsAllScreens()
  return fnutils.filter(window.visibleWindows(), function(win) return self ~= win end)
end

--- hs.window:focus() -> bool
--- Method
--- Try to make this window focused.
function window:focus()
  return self:becomeMain() and self:application():_bringtofront()
end

--- hs.window.visibleWindows() -> win[]
--- Function
--- Get all windows on all screens that match window.isVisible.
function window.visibleWindows()
  return fnutils.filter(window:allWindows(), window.isVisible)
end

--- hs.window.orderedWindows() -> win[]
--- Function
--- Returns all visible windows, ordered from front to back.
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

--- hs.window:maximize([duration])
--- Method
--- Make this window fill the whole screen its on, without covering the dock or menu. If the duration argument is present, it will override hs.window.animationDuration
function window:maximize(duration)
  local screenrect = self:screen():frame()
  self:setFrame(screenrect, duration)
end

--- hs.window:toggleFullScreen()
--- Method
--- Toggle the fullscreen state of this window.
function window:toggleFullScreen()
    self:setFullScreen(not self:isFullScreen())
end

--- hs.window:screen()
--- Method
--- Get the screen which most contains this window (by area).
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

local function windowsInDirection(win, numrotations)
  -- assume looking to east

  -- use the score distance/cos(A/2), where A is the angle by which it
  -- differs from the straight line in the direction you're looking
  -- for. (may have to manually prevent division by zero.)

  -- thanks mark!

  local startingpoint = geometry.rectMidPoint(win:frame())

  local otherwindows = fnutils.filter(win:otherWindowsAllScreens(), function(win) return window.isVisible(win) and window.isStandard(win) end)
  local closestwindows = {}

  for _, win in pairs(otherwindows) do
    local otherpoint = geometry.rectMidPoint(win:frame())
    otherpoint = geometry.rotateCCW(otherpoint, startingpoint, numrotations)

    local delta = {
      x = otherpoint.x - startingpoint.x,
      y = otherpoint.y - startingpoint.y,
    }

    if delta.x > 0 then
      local angle = math.atan2(delta.y, delta.x)
      local distance = geometry.hypot(delta)

      local anglediff = -angle

      local score = distance / math.cos(anglediff / 2)

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

--- hs.window:windowsToEast()
--- Method
--- Get all windows east of this one, ordered by closeness.
function window:windowsToEast()  return windowsInDirection(self, 0) end

--- hs.window:windowsToWest()
--- Method
--- Get all windows west of this one, ordered by closeness.
function window:windowsToWest()  return windowsInDirection(self, 2) end

--- hs.window:windowsToNorth()
--- Method
--- Get all windows north of this one, ordered by closeness.
function window:windowsToNorth() return windowsInDirection(self, 1) end

--- hs.window:windowsToSouth()
--- Method
--- Get all windows south of this one, ordered by closeness.
function window:windowsToSouth() return windowsInDirection(self, 3) end

--- hs.window:focusWindowEast()
--- Method
--- Focus the first focus-able window to the east of this one.
function window:focusWindowEast()  return focus_first_valid_window(self:windowsToEast()) end

--- hs.window:focusWindowWest()
--- Method
--- Focus the first focus-able window to the west of this one.
function window:focusWindowWest()  return focus_first_valid_window(self:windowsToWest()) end

--- hs.window:focusWindowNorth()
--- Method
--- Focus the first focus-able window to the north of this one.
function window:focusWindowNorth() return focus_first_valid_window(self:windowsToNorth()) end

--- hs.window:focusWindowSouth()
--- Method
--- Focus the first focus-able window to the south of this one.
function window:focusWindowSouth() return focus_first_valid_window(self:windowsToSouth()) end

--- hs.window:moveToUnit(rect[, duration])
--- Method
--- Moves and resizes the window to fit on the given portion of the screen.
--- The first argument is a rect with each key being between 0.0 and 1.0. The second is an optional animation duration, which will override hs.window.animationDuration
--- Example: win:moveToUnit(x=0, y=0, w=0.5, h=0.5) -- window now fills top-left quarter of screen
function window:moveToUnit(unit, duration)
  local screenrect = self:screen():frame()
  self:setFrame({
      x = screenrect.x + (unit.x * screenrect.w),
      y = screenrect.y + (unit.y * screenrect.h),
      w = unit.w * screenrect.w,
      h = unit.h * screenrect.h,
  }, duration)
end

--- hs.window:moveToScreen(screen[, duration])
--- Method
--- move window to the the given screen, keeping the relative proportion and position window to the original screen.
--- duration is an optional animation duration that will override hs.window.animationDuration
--- Example: win:moveToScreen(win:screen():next()) -- move window to next screen
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
end

--- hs.window:ensureIsInScreenBounds([duration])
--- Method
--- Moves and resizes the window to fit into the screen it is currently on. If the window is partially out of the
--- screen it is moved and resized to be completely visible on the window's current screen.
--- duration is an optional animation duration that overrides hs.window.animationDuration
--- Example: win:ensureIsInScreenBounds() -- ensure window is in the boundaries of the screen
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
end

return window
