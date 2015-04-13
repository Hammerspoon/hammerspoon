--- === hs.workspace ===
---
--- Consists of a collection of regions assigned to a screen. Has various
--- methods for manipulating and traversing regions.
---
--- Usage: local workspace = require "hs.workspace"
local workspace = {}

local alert = require "hs.alert"

function getCrossProduct(p1,p2)
end

function getDotProduct(p1,p2)
  return p1.x * p2.x + p1.y * p2.y
end

--- hs.workspace:new(regions, screen)
--- Constructor
--- * Create a new workspace that's attached to a screen
---
--- Parameters:
---  * regions - Optional collection of regions. If empty, defaults to a region
---  that takes up the whole screen
---  * screen - Optional screen for the workspace. If empty, defaults to
---  mainScreen
function workspace.new(regions, screen)
  local s = screen or hs.screen:mainScreen()
  local out = setmetatable({}, { __index = workspace })
  out.regions = {}
  if not regions then
    local f = s:frame()
    local r = hs.region.new(f.x, f.y, f.w, f.h)
    table.insert(out.regions, r)
  else
    out.regions = regions
  end
  out.screen = s
  return out
end

function workspace:addRegion(key, region)
  local hasRegion = false
  for _, r in pairs(self.regions) do
    if region == r then hasRegion = true end
  end
  if hasRegion then
    hs.alert.show("Workspace already contains regions")
  else
    self.regions[key] = region
  end
end

function workspace:getRegion(key)
  if not self.regions[key] then
    alert.show("Workspace does not contain a region with the key provided")
    return nil
  else
    return self.regions[key]
  end
end

function getClosestWindowEast()
end

function getRegionWithWindow(regions, win)
  for _, r in pairs(regions) do
    for _, w in pairs(r.windows) do
      if w == win then
        return r
      end
    end
  end
  return nil
end

function workspace:pushFocusedWindowRight()
  local w = hs.window.focusedWindow()
  local wr = getRegionWithWindow(self.regions, w)
  local candidates = {}
  for _, r in pairs(self.regions) do
    if wr.x < r.x and math.abs(wr.y - r.y) < 50 then
      table.insert(candidates, r)
    end
  end
  for _, r in pairs(candidates) do
    r:addWindow(w)
  end
  if #candidates > 0 then
    wr:removeWindow(w)
  end
end

function workspace:pushFocusedWindowLeft()
  local w = hs.window.focusedWindow()
  local wr = getRegionWithWindow(self.regions, w)
  local candidates = {}
  for _, r in pairs(self.regions) do
    if wr.x > r.x and math.abs(wr.y - r.y) < 50 then
      table.insert(candidates, r)
    end
  end
  for _, r in pairs(candidates) do
    r:addWindow(w)
  end
  if #candidates > 0 then
    wr:removeWindow(w)
  end
end

function workspace:changeScreen(screen)
  -- TODO: Make it shift all the windows and everything to the screen
end

return workspace
