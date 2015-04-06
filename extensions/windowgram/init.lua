--- === hs.windowgram ===
---
--- auto-layout using ascii rows similar to tmuxomatic

local windowgram = {}

local alert = require 'hs.alert'
local screen = require 'hs.screen'

local gridh
local gridw

--- hs.windowgram.getRects(wg)
--- Function
--- Converts a windowgram to a table with rects.
---
--- Parameters:
---  * wg - The windowgram: A table containing strings, representing the desired
--- window layout
---
--- Returns:
---  * Table with rects which contain an X, Y, W, and H values
---
--- Notes:
---  * Rects are relative to the positions in the windowgram.
---
--- ~~~lua
--- local wg = {
---   "AAAAAAAAAAAABBBBBBBBBBBB",
---   "AAAAAAAAAAAABBBBBBBBBBBB",
---   "AAAAAAAAAAAABBBBBBBBBBBB",
---   "CCCCCCCCCCCCCCCCCCCCCCCC",
---   "CCCCCCCCCCCCCCCCCCCCCCCC"
--- }
--- local windows = windowgram.getWindows(wg)
--- ~~~
---
--- This will return the following table;
--- ~~~lua
--- print(wg["A"])
--- -- prints { x=1, y=1, w=12, h=3 }
--- print(wg["B"])
--- -- prints { x=12, y=1, w=24, h=3 }
--- print(wg["C"])
--- -- prints { x=1, y=3, w=24, h=5 }
--- ~~~
function windowgram.getRects(wg)
  wg = removeWhitspace(wg)

  gridh = #wg
  gridw = nil

  local windows = {}

  for i, line in ipairs(wg) do
    if gridw then
      if gridw ~= line:len() then
        error('inconsistent grid width in windowgram')
      end
    else
      gridw=line:len()
    end
    for column = 1, #line do
      local char = line:sub(column, column)
      if not windows[char] then
        -- new window, create it with size 1x1
        windows[char] = { x = column , y = i}
      else
        -- expand it
        windows[char].w = column
        windows[char].h = i
      end
    end
  end
  return windows

end

function removeWhitspace(wg)
  local target = {}
  for i,l in ipairs(wg) do
    l = l:gsub("%s+","")
    table.insert(target, l)
  end
  return target
end

--- hs.windowgram.getRatios(rects)
--- Function
--- Gets a table with ratios from the rects table
---
--- Parameters:
---  * rects - The rects table returned by getRects
---
--- Returns:
---  * Table with ratios. ex; { x1=0, y1=0.5, x2=0.5, y2=1 }
---
--- Notes:
--- * These are numbers between 0 and 1 and represent two points; the top left
--- corner and the bottom right corner.
function windowgram.getRatios(rects)
  local ratios = {}
  local totalWidth = 0
  local totalHeight = 0
  for k,v in pairs(rects) do
    if v.w > totalWidth then totalWidth = v.w end
    if v.h > totalHeight then totalHeight = v.h end
  end
  for k,w in pairs(rects) do
    ratios[k] = {}
    ratios[k].x1 = w.x == 1 and 0 or (w.x - 1) / totalWidth
    ratios[k].y1 = w.y == 1 and 0 or (w.y - 1) / totalHeight
    ratios[k].x2 = w.w == 1 and 0 or (w.w) / totalWidth
    ratios[k].y2 = w.h == 1 and 0 or (w.h) / totalHeight
  end
  return ratios
end

function resizeToGrid(window, gridRatio)
    local screenSize = screen.mainScreen():frame()
    local frame = {}

    frame["x"] = screenSize.w * gridRatio.x1
    frame["y"] = screenSize.h * gridRatio.y1 + screenSize.y
    local widthRatio = gridRatio.x2 - gridRatio.x1
    local heightRatio = gridRatio.y2 - gridRatio.y1
    frame["w"] = screenSize.w * widthRatio
    frame["h"] = screenSize.h * heightRatio + screenSize.y
    window:setFrame(frame)
end

--- hs.windowgram.applyAppMapLayout(rects, map)
--- Function
--- * Uses an map table to layout the current windows based on the windowgram
--- rects
---
--- Parameters:
---  * rects - The rects table returned by getRects
---  * map - A key/value table where the key is the ascii character used in
---  the windowgram and the value is the name of the map.
---  Ex;
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
function windowgram.applyAppMapLayout(rects, map)
  local ratios = windowgram.getRatios(rects)
  for k, line in pairs(map) do
    local key = line:sub(1,1)
    local appName = line:sub(3)
    if not rects[key] then
      error(string.format('no rect found for application %s (%s)', key, appName))
    end
    local app = hs.appfinder.appFromName(appName)
    if app ~= nil then
      local appWindows = app:allWindows()
      for char, window in pairs(appWindows) do
        if window then resizeToGrid(window, ratios[key]) end
      end
    end
  end
end

return windowgram
