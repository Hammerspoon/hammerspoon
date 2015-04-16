--- === hs.windowgram ===
---
--- region generation using ascii rows similar to tmuxomatic for window areas

local windowgram = {}

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

--- hs.windowgram.getRegionRatios(regions)
--- Function
--- Gets a table with the regions as percentages of the screen resolution
---
--- Parameters:
---  * regions - The regions table returned by windowgram.convertToRegions(wg)
---
--- Returns:
---  * Table with ratios. ex; { x=0, y=0.5, w=0.5, h=1 }
---
--- Notes:
--- * These are numbers between 0 and 1 and represent two points; the top left
--- corner and the bottom right corner.
function windowgram.getRegionRatios(regions)
  local ratios = {}
  local screenSize = hs.screen.mainScreen():frame()
  for k,region in pairs(regions) do
    ratios[k] = {}
    ratios[k].x = region.x ~= 0 and region.x / screenSize.w or 0
    ratios[k].y = region.y ~= 0 and region.y / screenSize.h or 0
    ratios[k].w = region.w ~= 0 and region.w / screenSize.w or 0
    ratios[k].h = region.h ~= 0 and region.h / screenSize.h or 0
  end
  return ratios
end

--- hs.windowgram.convertToRegions(wg)
--- Function
--- Gets a table with pixel coords describing a region, given a windowgram
---
--- Parameters:
---  * wg - The windowgram: multiline string with the desired window layout
---
--- Returns:
---  * Table with regions which contain an X, Y, W, and H values
---
--- Notes:
---  * Regions are pixel based coordinates relative to the windowgram
---
--- ~~~lua
--- local wg = [[
---   AAAAAAAAAAAABBBBBBBBBBBB
---   AAAAAAAAAAAABBBBBBBBBBBB
---   AAAAAAAAAAAABBBBBBBBBBBB
---   CCCCCCCCCCCCCCCCCCCCCCCC
---   CCCCCCCCCCCCCCCCCCCCCCCC
--- ]]
--- local windows = windowgram.getWindows(wg)
--- ~~~
---
--- On a 1920x1080 resolution, This will return the following table;
--- ~~~lua
--- print(wg["A"])
--- -- prints { x=0, y=0, w=960, h=648 }
--- print(wg["B"])
--- -- prints { x=960, y=0, w=960, h=648 }
--- print(wg["C"])
--- -- prints { x=0, y=648, w=1920, h=432 }
--- ~~~
function windowgram.convertToRegions(wg)
  local regions = {}
  local totalWidth = 0
  local totalHeight = 0
  local screenSize = hs.screen.mainScreen():frame()
  local grid = parseWindowgram(wg)

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

  -- Populate regions
  for k,r in pairs(ratios) do
    regions[k] = {}
    regions[k].x = r.x * screenSize.w
    regions[k].y = r.y * screenSize.h + screenSize.y
    local widthRatio = r.w - r.x
    local heightRatio = r.h - r.y
    regions[k].w = screenSize.w * widthRatio
    regions[k].h = screenSize.h * heightRatio
  end

  return regions
end

--- hs.windowgram.applyAppMapLayout(regions, map)
--- Function
--- * Uses a key/app map table to layout the current windows based on the
--- regions pixel coords
---
--- Parameters:
---  * regions - The regions table returned by windowgram:convertToRegions(wg)
---  * map - A key/value table where the key is the ascii character used in
---  the windowgram and the value is the name of the map.
---
--- Ex;
--- Given the following windowgram which creates a 1 by 2 grid;
--- ~~~lua
--- local wg = {
---   "AABB",
---   "AACC",
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
function resizeToRegion(window, region)
  local screenSize = hs.screen.mainScreen():frame()
  local frame = {}

  frame.x = region.x
  frame.y = region.y
  frame.w = region.w
  frame.h = region.h
  window:setFrame(frame)
end

function windowgram.applyAppMapLayout(regions, map)
  for k, line in pairs(map) do
    local key = line:sub(1,1)
    local appName = line:sub(3)
    if not regions[key] then
      error(string.format('no region found for application %s (%s)', key, appName))
    end
    local app = hs.appfinder.appFromName(appName)
    if app ~= nil then
      local appWindows = app:allWindows()
      for char, window in pairs(appWindows) do
        if window then resizeToRegion(window, regions[key]) end
      end
    end
  end
end

return windowgram
