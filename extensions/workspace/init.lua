--- === hs.workspace ===
---
--- Consists of a collection of regions assigned to a screen. Has various
--- methods for manipulating and traversing regions.
---
--- Usage: local workspace = require "hs.workspace"
local workspace = {}

local alert = require "hs.alert"
local Direction = {
  Left  = { -1 , 0 },
  Right = {  0 , 1 },
  Up    = { -1 , 0 },
  Down  = {  0 , 1 }
}

function getClosestRegionInDirection(workspace, direction, region)
  local candidates = getRegionsInDirection(workspace, direction, region)
  if #candidates == 0 then return nil end
  local scores = {}
  -- The weight gives a preferential score to x or y make sure it picks a region
  -- that's more in the given direction
  local weight = 1.5
  local center = region:getCenterPoint()
  local fn = nil
  if direction == Direction.Left or direction == Direction.Right then
    fn = function(p1, p2)
      return math.abs(p1.x - p2.x) + math.abs(p1.y - p2.y) * weight
    end
  elseif direction == Direction.Up or direction == Direction.Down then
    fn = function(p1, p2)
      return math.abs(p1.x - p2.x) * weight + math.abs(p1.y - p2.y)
    end
  end
  for i, c in ipairs(candidates) do
    local candidateCenter = c:getCenterPoint()
    local s = { candidate = c , score = fn(center, candidateCenter) }
    scores[i] = s
  end
  table.sort(scores, function(a,b) return a.score < b.score end)
  return scores[1].candidate
end

function getRegionsInDirection(workspace, direction, region)
  local fn = nil
  local candidates = {}
  if direction == Direction.Left then
    fn = function(p1, p2) return p1.x > p2.x end
  elseif direction == Direction.Right then
    fn = function(p1, p2) return p1.x < p2.x end
  elseif direction == Direction.Up then
    fn = function(p1, p2) return p1.y > p2.y end
  elseif direction == Direction.Down then
    fn = function(p1, p2) return p1.y < p2.y end
  end
  local center = region:getCenterPoint()
  for _, r in pairs(workspace.regions) do
    local candidateCenter = r:getCenterPoint()
    if fn(center, candidateCenter) then
      table.insert(candidates, r)
    end
  end
  return candidates
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

function pushFocusedWindow(workspace, direction)
  local w = hs.window.focusedWindow()
  local workingRegion = getRegionWithWindow(workspace.regions, w)
  local r = getClosestRegionInDirection(workspace, direction, workingRegion)
  if r then
    r:addWindow(w)
    workingRegion:removeWindow(w)
  end
end

function workspace:pushFocusedWindowEast()
  pushFocusedWindow(self, Direction.Right)
end

function workspace:pushFocusedWindowWest()
  pushFocusedWindow(self, Direction.Left)
end

function workspace:pushFocusedWindowNorth()
  pushFocusedWindow(self, Direction.Up)
end

function workspace:pushFocusedWindowSouth()
  pushFocusedWindow(self, Direction.Down)
end

function focusRegion(workspace, direction)
  local w = hs.window.focusedWindow()
  local workingRegion = getRegionWithWindow(workspace.regions, w)
  local r = getClosestRegionInDirection(workspace, direction, workingRegion)
  if r and r.currentWindow then
    r.currentWindow:focus()
  end
end

function workspace:focusRegionEast()
  focusRegion(self, Direction.Right)
end

function workspace:focusRegionWest()
  focusRegion(self, Direction.Left)
end

function workspace:focusRegionNorth()
  focusRegion(self, Direction.Up)
end

function workspace:focusRegionSouth()
  focusRegion(self, Direction.Down)
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
