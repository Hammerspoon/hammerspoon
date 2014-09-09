--- === mjolnir.window ===
---
--- Functions for managing any window.
---
--- To get windows, see `mjolnir.window.focusedwindow` and `mjolnir.window.visiblewindows`.
---
--- To get window geometrical attributes, see `mjolnir.window.{frame,size,topleft}`.
---
--- To move and resize windows, see `mjolnir.window.set{frame,size,topleft}`.
---
--- It may be handy to get a window's app or screen via `mjolnir.window.application` and `mjolnir.window.screen`.
---
--- See the `screen` module for detailed explanation of how Mjolnir uses window/screen coordinates.

local window = require "mjolnir.window.internal"
local application = require "mjolnir.application.internal"
local fnutils = require "mjolnir.fnutils"
local geometry = require "mjolnir.geometry"
local mj_screen = require "mjolnir.screen"


--- mjolnir.window.allwindows() -> win[]
--- Function
--- Returns all windows
function window.allwindows()
  return fnutils.mapcat(application.runningapplications(), application.allwindows)
end

--- mjolnir.window.windowforid() -> win or nil
--- Function
--- Returns the window for the given id, or nil if it's an invalid id.
function window.windowforid(id)
  return fnutils.find(window.allwindows(), function(win) return win:id() == id end)
end

--- mjolnir.window:isvisible() -> bool
--- Method
--- True if the app is not hidden and the window is not minimized.
--- NOTE: some apps (e.g. in Adobe Creative Cloud) have literally-invisible windows and also like to put them very far offscreen; this method may return true for such windows.
function window:isvisible()
  return not self:application():ishidden() and not self:isminimized()
end

--- mjolnir.window:frame() -> rect
--- Method
--- Get the frame of the window in absolute coordinates.
function window:frame()
  local s = self:size()
  local tl = self:topleft()
  return {x = tl.x, y = tl.y, w = s.w, h = s.h}
end

--- mjolnir.window:setframe(rect)
--- Method
--- Set the frame of the window in absolute coordinates.
function window:setframe(f)
  self:setsize(f)
  self:settopleft(f)
  self:setsize(f)
end

--- mjolnir.window:otherwindows_samescreen() -> win[]
--- Method
--- Get other windows on the same screen as self.
function window:otherwindows_samescreen()
  return fnutils.filter(window.visiblewindows(), function(win) return self ~= win and self:screen() == win:screen() end)
end

--- mjolnir.window:otherwindows_allscreens() -> win[]
--- Method
--- Get every window except this one.
function window:otherwindows_allscreens()
  return fnutils.filter(window.visiblewindows(), function(win) return self ~= win end)
end

--- mjolnir.window:focus() -> bool
--- Method
--- Try to make this window focused.
function window:focus()
  return self:becomemain() and self:application():_bringtofront()
end

--- mjolnir.window.visiblewindows() -> win[]
--- Function
--- Get all windows on all screens that match window.isvisible.
function window.visiblewindows()
  return fnutils.filter(window:allwindows(), window.isvisible)
end

--- mjolnir.window.orderedwindows() -> win[]
--- Function
--- Returns all visible windows, ordered from front to back.
function window.orderedwindows()
  local orderedwins = {}
  local orderedwinids = window._orderedwinids()
  local windows = window.visiblewindows()

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

--- mjolnir.window:maximize()
--- Method
--- Make this window fill the whole screen its on, without covering the dock or menu.
function window:maximize()
  local screenrect = self:screen():frame()
  self:setframe(screenrect)
end

--- mjolnir.window:screen()
--- Method
--- Get the screen which most contains this window (by area).
function window:screen()
  local windowframe = self:frame()
  local lastvolume = 0
  local lastscreen = nil

  for _, screen in pairs(mj_screen.allscreens()) do
    local screenframe = screen:fullframe()
    local intersection = geometry.intersectionrect(windowframe, screenframe)
    local volume = intersection.w * intersection.h

    if volume > lastvolume then
      lastvolume = volume
      lastscreen = screen
    end
  end

  return lastscreen
end

local function windows_in_direction(win, numrotations)
  -- assume looking to east

  -- use the score distance/cos(A/2), where A is the angle by which it
  -- differs from the straight line in the direction you're looking
  -- for. (may have to manually prevent division by zero.)

  -- thanks mark!

  local startingpoint = geometry.rectmidpoint(win:frame())

  local otherwindows = fnutils.filter(win:otherwindows_allscreens(), function(win) return window.isvisible(win) and window.isstandard(win) end)
  local closestwindows = {}

  for _, win in pairs(otherwindows) do
    local otherpoint = geometry.rectmidpoint(win:frame())
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

--- mjolnir.window:windows_to_east()
--- Method
--- Get all windows east of this one, ordered by closeness.
function window:windows_to_east()  return windows_in_direction(self, 0) end

--- mjolnir.window:windows_to_west()
--- Method
--- Get all windows west of this one, ordered by closeness.
function window:windows_to_west()  return windows_in_direction(self, 2) end

--- mjolnir.window:windows_to_north()
--- Method
--- Get all windows north of this one, ordered by closeness.
function window:windows_to_north() return windows_in_direction(self, 1) end

--- mjolnir.window:windows_to_south()
--- Method
--- Get all windows south of this one, ordered by closeness.
function window:windows_to_south() return windows_in_direction(self, 3) end

--- mjolnir.window:focuswindow_east()
--- Method
--- Focus the first focus-able window to the east of this one.
function window:focuswindow_east()  return focus_first_valid_window(self:windows_to_east()) end

--- mjolnir.window:focuswindow_west()
--- Method
--- Focus the first focus-able window to the west of this one.
function window:focuswindow_west()  return focus_first_valid_window(self:windows_to_west()) end

--- mjolnir.window:focuswindow_north()
--- Method
--- Focus the first focus-able window to the north of this one.
function window:focuswindow_north() return focus_first_valid_window(self:windows_to_north()) end

--- mjolnir.window:focuswindow_south()
--- Method
--- Focus the first focus-able window to the south of this one.
function window:focuswindow_south() return focus_first_valid_window(self:windows_to_south()) end

--- mjolnir.window:movetounit(rect)
--- Method
--- Moves and resizes the window to fit on the given portion of the screen.
--- The argument is a rect with each key being between 0.0 and 1.0.
--- Example: win:movetounit(x=0, y=0, w=0.5, h=0.5) -- window now fills top-left quarter of screen
function window:movetounit(unit)
  local screenrect = self:screen():frame()
  self:setframe({
      x = screenrect.x + (unit.x * screenrect.w),
      y = screenrect.y + (unit.y * screenrect.h),
      w = unit.w * screenrect.w,
      h = unit.h * screenrect.h,
  })
end

return window
