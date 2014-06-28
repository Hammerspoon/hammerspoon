doc.api.window.allwindows = {"api.window.allwindows() -> win[]", "Returns all windows"}
function api.window.allwindows()
  return api.fn.mapcat(api.app.runningapps(), api.app.allwindows)
end

doc.api.window.isvisible = {"api.window:isvisible() -> bool", "True if the app is not hidden or minimized."}
function api.window:isvisible()
  return not self:app():ishidden() and not self:isminimized()
end

doc.api.window.frame = {"api.window:frame() -> rect", "Get the frame of the window in absolute coordinates."}
function api.window:frame()
  local s = self:size()
  local tl = self:topleft()
  return {x = tl.x, y = tl.y, w = s.w, h = s.h}
end

doc.api.window.setframe = {"api.window:setframe(rect)", "Set the frame of the window in absolute coordinates."}
function api.window:setframe(f)
  self:setsize(f)
  self:settopleft(f)
  self:setsize(f)
end

doc.api.window.otherwindows_samescreen = {"api.window:otherwindows_samescreen() -> win[]", "Get other windows on the same screen as self."}
function api.window:otherwindows_samescreen()
  return api.fn.filter(api.window.visiblewindows(), function(win) return self ~= win and self:screen() == win:screen() end)
end

doc.api.window.otherwindows_allscreens = {"api.window:otherwindows_allscreens() -> win[]", "Get every window except this one."}
function api.window:otherwindows_allscreens()
  return api.fn.filter(api.window.visiblewindows(), function(win) return self ~= win end)
end

doc.api.window.focus = {"api.window:focus() -> bool", "Try to make this window focused."}
function api.window:focus()
  return self:becomemain() and self:app():activate()
end

doc.api.window.visiblewindows = {"api.window.visiblewindows() -> win[]", "Get all windows on all screens that match api.window.isvisible."}
function api.window.visiblewindows()
  return api.fn.filter(api.window:allwindows(), api.window.isvisible)
end

doc.api.window.maximize = {"api.window:maximize()", "Make this window fill the whole screen its on, without covering the dock or menu."}
function api.window:maximize()
  local screenrect = self:screen():frame_without_dock_or_menu()
  self:setframe(screenrect)
end

doc.api.window.screen = {"api.window:screen()", "Get the screen this window is mostly on."}
function api.window:screen()
  local windowframe = self:frame()
  local lastvolume = 0
  local lastscreen = nil

  for _, screen in pairs(api.screen.allscreens()) do
    local screenframe = screen:frame_including_dock_and_menu()
    local intersection = api.geometry.intersectionrect(windowframe, screenframe)
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

  local thiswindow = api.window.focusedwindow()
  local startingpoint = api.geometry.rectmidpoint(thiswindow:frame())

  local otherwindows = thiswindow:otherwindows_allscreens()
  local closestwindows = {}

  for _, win in pairs(otherwindows) do
    local otherpoint = api.geometry.rectmidpoint(win:frame())
    otherpoint = api.geometry.rotateccw(otherpoint, startingpoint, numrotations)

    local delta = {
      x = otherpoint.x - startingpoint.x,
      y = otherpoint.y - startingpoint.y,
    }

    if delta.x > 0 then
      local angle = math.atan2(delta.y, delta.x)
      local distance = api.geometry.hypot(delta)

      local anglediff = -angle

      local score = distance / math.cos(anglediff / 2)

      table.insert(closestwindows, {win = win, score = score})
    end
  end

  table.sort(closestwindows, function(a, b) return a.score < b.score end)
  return api.fn.map(closestwindows, function(x) return x.win end)
end

local function focus_first_valid_window(ordered_wins)
  for _, win in pairs(ordered_wins) do
    if win:focus() then return true end
  end
  return false
end

doc.api.window.windows_to_east = {"api.window:windows_to_east()", "Get all windows east of this one, ordered by closeness."}
doc.api.window.windows_to_west = {"api.window:windows_to_west()", "Get all windows west of this one, ordered by closeness."}
doc.api.window.windows_to_north = {"api.window:windows_to_north()", "Get all windows north of this one, ordered by closeness."}
doc.api.window.windows_to_south = {"api.window:windows_to_south()", "Get all windows south of this one, ordered by closeness."}

doc.api.window.focuswindow_east = {"api.window:focuswindow_east()", "Focus the first focus-able window to the east of this one."}
doc.api.window.focuswindow_west = {"api.window:focuswindow_west()", "Focus the first focus-able window to the west of this one."}
doc.api.window.focuswindow_north = {"api.window:focuswindow_north()", "Focus the first focus-able window to the north of this one."}
doc.api.window.focuswindow_south = {"api.window:focuswindow_south()", "Focus the first focus-able window to the south of this one."}

function api.window:windows_to_east()  return windows_in_direction(self, 0) end
function api.window:windows_to_west()  return windows_in_direction(self, 2) end
function api.window:windows_to_north() return windows_in_direction(self, 1) end
function api.window:windows_to_south() return windows_in_direction(self, 3) end

function api.window:focuswindow_east()  return focus_first_valid_window(self:windows_to_east()) end
function api.window:focuswindow_west()  return focus_first_valid_window(self:windows_to_west()) end
function api.window:focuswindow_north() return focus_first_valid_window(self:windows_to_north()) end
function api.window:focuswindow_south() return focus_first_valid_window(self:windows_to_south()) end
