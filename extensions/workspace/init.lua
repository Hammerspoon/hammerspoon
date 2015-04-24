--- === hs.workspace ===
---
--- Consists of a collection of regions assigned to a screen. Has various methods for manipulating and traversing regions.
---
--- Usage: local workspace = require "hs.workspace"
local workspace = {}

local alert = require "hs.alert"
local region = require "hs.region"

local Direction =
{
  Left  = { -1 , 0 },
  Right = {  0 , 1 },
  Up    = { -1 , 0 },
  Down  = {  0 , 1 }
}

--- hs.workspace:create(regions, screen)
--- Constructor
--- * Create a new workspace that's attached to a screen.
---
--- Parameters:
---  * regions - Optional table of regions. Add keys to each region in order to apply the app map with `hs.workspace.applyAppMapLayout`. If empty, defaults to a region that takes up the whole screen when empty.
---  * screen - Optional screen for the workspace. If empty, defaults to mainScreen.
function workspace.create(regions, screen)
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

--- hs.workspace:createWithGrid(width, height, screen)
--- Constructor
--- * Create a new workspace from a grid layout.
---
--- Parameters:
---  * width - The number of cells wide the grid is.
---  * height - The number of cells high the grid is.
---  * screen - Optional screen for the workspace. If empty, defaults to mainScreen.
function workspace.createWithGrid(width, height, screen)
  if not (width and height) or (width < 1 or height < 1) then
    alert.show("Invalid width or height provided to workspace")
  end
  if not screen then
    screen = hs.screen.mainScreen()
  end
  local out = setmetatable({}, { __index = workspace })
  out.regions = {}
  out.screen = screen
  local frame      = screen:frame()
  local cellWidth  = frame.w / width
  local cellHeight = frame.h / height
  local regionCount = 0
  for i = 0, height - 1 do
    for j = 0, width - 1 do
      local x = frame.x + cellWidth * j
      local y = frame.y + cellHeight * i
      local w = cellWidth
      local h = cellHeight
      local r = region.new(x, y, w, h)
      regionCount = regionCount + 1
      local key = tostring(regionCount)
      print(key)
      out.regions[key] = r
    end
  end
  return out
end

--- hs.workspace.createWithWindowgram(wingram)
--- Constructor
--- Create a workspace with a windowgram, similar to tmuxomatic
---
--- Parameters:
---  * wingram - The windowgram. See below.
---  * screen - Optional screen for the workspace. If empty, defaults to mainScreen
---
--- Notes:
---  * The windowgram is a multiline string that contains keys layed out in rectangles that match the desired layout. The crunch '#' can be used for commenting.
---
--- ~~~lua
--- local wingram = [[
---   AAAAAAAAAAAABBBBBBBBBBBB # This is a comment
---   AAAAAAAAAAAABBBBBBBBBBBB
---   AAAAAAAAAAAABBBBBBBBBBBB
---   CCCCCCCCCCCCCCCCCCCCCCCC
---   CCCCCCCCCCCCCCCCCCCCCCCC
--- ]]
--- ~~~
function workspace.createWithWindowgram(wingram, screen)
  local totalWidth = 0
  local totalHeight = 0
  local grid = parseWindowgram(wingram)
  if not screen then
    screen = hs.screen.mainScreen()
  end
  local screenSize = screen:frame()

  -- Get the total size
  for k,v in pairs(grid) do
    if v.w > totalWidth then totalWidth = v.w end
    if v.h > totalHeight then totalHeight = v.h end
  end

  -- calculate the ratios as percentages of the windowgram
  local ratios = {}
  for k,w in pairs(grid) do
    ratios[k] = {}
    ratios[k].x = w.x == 1 and 0 or (w.x - 1) / totalWidth
    ratios[k].y = w.y == 1 and 0 or (w.y - 1) / totalHeight
    ratios[k].w = w.w == 1 and 0 or (w.w) / totalWidth
    ratios[k].h = w.h == 1 and 0 or (w.h) / totalHeight
  end

  local out = setmetatable({}, { __index = workspace })
  out.regions = {}
  out.screen = screen
  -- Populate regions
  for k,r in pairs(ratios) do
    local x = r.x * screenSize.w
    local y = r.y * screenSize.h + screenSize.y
    local widthRatio = r.w - r.x
    local heightRatio = r.h - r.y
    local w = screenSize.w * widthRatio
    local h = screenSize.h * heightRatio
    local region = region.new(x, y, w, h)
    out.regions[k] = region
  end

  return out
end

-- Returns a table with the relative cols and rows.
function parseWindowgram(wg)
  local gridw = nil
  local grid = {}

  -- Split into lines
  local lines = {}
  for line in string.gmatch(wg, "[^\r\n]+") do
    if #line > 0 then
      table.insert(lines, line)
    end
  end
  lines = cleanLines(lines)

  for i, line in ipairs(lines) do
    if gridw then
      if gridw ~= line:len() then
        error('inconsistent grid width in windowgram')
      end
    else
      gridw=line:len()
    end
    for column = 1, #line do
      local char = line:sub(column, column)
      if not grid[char] then
        -- new window, create it with size 1x1
        grid[char] = { x = column , y = i}
      else
        -- expand it
        grid[char].w = column
        grid[char].h = i
      end
    end
  end
  return grid
end

function cleanLines(wg)
  local target = {}
  for i,l in ipairs(wg) do
    -- Remove comments and whitespace
    l = l:gsub('#.*','')
    l = l:gsub("%s+","")
    table.insert(target, l)
  end
  return target
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

--- hs.workspace.applyAppMapLayout(map)
--- Method
--- * Uses a key/app map table to layout the current windows based on the regions pixel coords
---
--- Parameters:
---  * map - A list table formatted with the key/value pair delimited by a space.
---
--- Notes:
--- * The key in the map is the one used for the regions generated in any of the workspace constructors. The value is the name of the App.
---
--- Example with a windowgram;
--- ~~~lua
--- local wingram = {
---   "AAAABBBB",
---   "AAAABBBB",
---   "AAAACCCC",
---   "AAAACCCC",
--- }
--- ~~~
---
--- An app map would look like this;
---  ~~~lua
--- local map = {
---   "A MacVim",
---   "A Firefox",
---   "B iTerm2",
---   "B Skype",
---   "C Xcode"
--- }
---  ~~~
---
--- Example with a 2x2 grid;
--- ~~~lua
--- local wingram = {
---   "11112222",
---   "11112222",
---   "33334444"
---   "33334444"
--- }
--- ~~~
---
--- An app map would look like this;
---  ~~~lua
--- local map = {
---   "1 MacVim",
---   "1 Firefox",
---   "2 iTerm2",
---   "3 Skype",
---   "4 Xcode"
--- }
---  ~~~
function workspace:applyAppMapLayout(map)
  for _, line in ipairs(map) do
    local key = line:sub(1,1)
    local appName = line:sub(3)
    local region = self:getRegion(key)
    if not region then
      error(string.format('invalid application key (%s) for %s', key, appName))
    end
    local app = hs.appfinder.appFromName(appName)
    if app ~= nil then
      local appWindows = app:allWindows()
      for char, window in pairs(appWindows) do
        if window then region:addWindow(window) end
      end
    end
    region.currentWindow:focus()
  end
end

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
    fn = function(a)  return a >= 60 and a <= 120 end
  elseif direction == Direction.Right then
    fn = function(a) return a >= -120 and a <= -60 end
  elseif direction == Direction.Up then
    fn = function(a) return a > -30 and a < 30 end
  elseif direction == Direction.Down then
    fn = function(a) return a < -150 or a > 150 end
  end
  local center = region:getCenterPoint()
  for _, r in pairs(workspace.regions) do
    if r ~= region then
      local candidateCenter = r:getCenterPoint()
      local angle = getAngle(center, candidateCenter)
      if fn(angle) then
        table.insert(candidates, r)
      end
    end
  end
  return candidates
end

function getAngle(p1, p2)
  return math.atan2(p1.x - p2.x, p1.y - p2.y) * 180 / math.pi
end

function workspace:switchNextWindowInStack()
  local r = getRegionWithWindow(self.regions, hs.window.focusedWindow())
  if r then
    r:focusNextWindow()
  end
end

function workspace:switchPrevWindowInStack()
  local r = getRegionWithWindow(self.regions, hs.window.focusedWindow())
  if r then
    r:focusPrevWindow()
  end
end

function workspace:resetWindow()
    local w = hs.window.focusedWindow()
    local r = getRegionWithWindow(self.regions, w)
    if r then
        r:addWindow(w)
    end
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

function pushFocusedWindow(workspace, direction)
  local w = hs.window.focusedWindow()
  local workingRegion = getRegionWithWindow(workspace.regions, w)
  if workingRegion then
    local r = getClosestRegionInDirection(workspace, direction, workingRegion)
    if r then
      r:addWindow(w)
      workingRegion:removeWindow(w)
    end
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

function focusRegion(workspace, direction)
  local w = hs.window.focusedWindow()
  local workingRegion = getRegionWithWindow(workspace.regions, w)
  if workingRegion then
    local r = getClosestRegionInDirection(workspace, direction, workingRegion)
    if r and r.currentWindow then
      r.currentWindow:focus()
    end
  end
end

function workspace:changeScreen(screen)
  -- TODO: Make it shift all the windows and everything to the screen
end

return workspace
