function api.window.allwindows()
  return api.fn.mapcat(api.app.runningapps(), api.app.allwindows)
end

function api.window:isvisible()
  return not self:app():ishidden() and
    not self:isminimized() and
    self:isstandard()
end

function api.window:frame()
  local s = self:size()
  local tl = self:topleft()
  return {x = tl.x, y = tl.y, w = s.w, h = s.h}
end

function api.window:setframe(f)
  self:setsize(f)
  self:settopleft(f)
  self:setsize(f)
end

function api.window:otherwindows_samescreen()
  return api.fn.filter(api.window.visiblewindows(), function(win) return self ~= win and self:screen() == win:screen() end)
end

function api.window:otherwindows_allscreens()
  return api.fn.filter(api.window.visiblewindows(), function(win) return self ~= win end)
end

function api.window:focus()
  return self:becomemain() and self:app():activate()
end

function api.window.visiblewindows()
  return api.fn.filter(api.window:allwindows(), api.window.isvisible)
end

function api.window:maximize()
  local screenrect = self:screen():frame_without_dock_or_menu()
  self:setframe(screenrect)
end

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

function api.window:windows_to_east()  return windows_in_direction(self, 0) end
function api.window:windows_to_west()  return windows_in_direction(self, 2) end
function api.window:windows_to_north() return windows_in_direction(self, 1) end
function api.window:windows_to_south() return windows_in_direction(self, 3) end

function api.window:focuswindow_east()  return focus_first_valid_window(self:windows_to_east()) end
function api.window:focuswindow_west()  return focus_first_valid_window(self:windows_to_west()) end
function api.window:focuswindow_north() return focus_first_valid_window(self:windows_to_north()) end
function api.window:focuswindow_south() return focus_first_valid_window(self:windows_to_south()) end
