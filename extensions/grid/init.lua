--- === hs.grid ===
---
--- Move/resize windows within a grid
---
--- The grid partitions of your screen for the purposes of window management. The default layout of the grid is 3 columns and 3 rows.
---
--- Windows that are aligned with the grid have their location and size described as a `cell`. Each cell is a table which contains the keys:
---  * x - A number containing the column of the left edge of the window
---  * y - A number containing the row of the top edge of the window
---  * w - A number containing the number of columns the window occupies
---  * h - A number containing the number of rows the window occupies
---
--- For a grid of 2x2:
---  * a cell {x = 0, y = 0, w = 1, h = 1} will be in the upper-left corner
---  * a cell {x = 1, y = 0, w = 1, h = 1} will be in the upper-right corner
---  * and so on...

local grid = {}

local fnutils = require "hs.fnutils"
local window = require "hs.window"
local alert = require "hs.alert"


--- hs.grid.MARGINX = 5
--- Variable
--- The margin between each window horizontally, measured in screen points (typically a point is a pixel on a non-retina screen, or two pixels on a retina screen
grid.MARGINX = 5

--- hs.grid.MARGINY = 5
--- Variable
--- The margin between each window vertically, measured in screen points (typically a point is a pixel on a non-retina screen, or two pixels on a retina screen)
grid.MARGINY = 5

--- hs.grid.GRIDHEIGHT = 3
--- Variable
--- The number of rows in the grid
grid.GRIDHEIGHT = 3

--- hs.grid.GRIDWIDTH = 3
--- Variable
--- The number of columns in the grid
grid.GRIDWIDTH = 3

local function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

--- hs.grid.get(win) -> cell
--- Function
--- Gets the cell describing a window
---
--- Parameters:
--- * An `hs.window` object to get the cell of
---
--- Returns:
--- * A cell object, or nil if an error occurred
function grid.get(win)
  local winframe = win:frame()
  local winscreen = win:screen()
  if not winscreen then
      return nil
  end
  local screenrect = win:screen():frame()
  local thirdscreenwidth = screenrect.w / grid.GRIDWIDTH
  local halfscreenheight = screenrect.h / grid.GRIDHEIGHT
  return {
    x = round((winframe.x - screenrect.x) / thirdscreenwidth),
    y = round((winframe.y - screenrect.y) / halfscreenheight),
    w = math.max(1, round(winframe.w / thirdscreenwidth)),
    h = math.max(1, round(winframe.h / halfscreenheight)),
  }
end

--- hs.grid.set(win, cell, screen)
--- Function
--- Sets the cell for a window, on a particular screen
---
--- Parameters:
---  * win - An `hs.window` object representing the window to operate on
---  * cell - A cell-table to apply to the window
---  * screen - An `hs.screen` object representing the screen to place the window on
---
--- Returns:
---  * None
function grid.set(win, cell, screen)
  local screenrect = screen:frame()
  local thirdscreenwidth = screenrect.w / grid.GRIDWIDTH
  local halfscreenheight = screenrect.h / grid.GRIDHEIGHT
  local newframe = {
    x = (cell.x * thirdscreenwidth) + screenrect.x,
    y = (cell.y * halfscreenheight) + screenrect.y,
    w = cell.w * thirdscreenwidth,
    h = cell.h * halfscreenheight,
  }

  newframe.x = newframe.x + grid.MARGINX
  newframe.y = newframe.y + grid.MARGINY
  newframe.w = newframe.w - (grid.MARGINX * 2)
  newframe.h = newframe.h - (grid.MARGINY * 2)

  win:setFrame(newframe)
end

--- hs.grid.snap(win)
--- Function
--- Snaps a window into alignment with the nearest grid lines
---
--- Parameters:
---  * win - A `hs.window` object to snap
---
--- Returns:
---  * None
function grid.snap(win)
  if win:isStandard() then
    local gridframe = grid.get(win)
    if gridframe then
        grid.set(win, gridframe, win:screen())
    end
  end
end

--- hs.grid.adjustNumberOfRows(delta) -> number
--- Function
--- Increases or decreases the number of rows in the grid
---
--- Parameters:
---  * delta - A number to increase or decrease the rows of the grid by. Positive to increase the number of rows, negative to decrease it
---
--- Returns:
---  * None
function grid.adjustNumberOfRows(delta)
  grid.GRIDHEIGHT = math.max(1, grid.GRIDHEIGHT + delta)
  fnutils.map(window.visibleWindows(), grid.snap)
end
-- This is for legacy purposes
grid.adjustHeight = grid.adjustNumberOfRows

--- hs.grid.adjustNumberOfColumns(delta)
--- Function
--- Increases or decreases the number of columns in the grid
---
--- Parameters:
---  * delta - A number to increase or decrease the columns of the grid by. Positive to increase the number of columns, negative to decrease it
---
--- Returns:
---  * None
function grid.adjustNumberOfColumns(delta)
  grid.GRIDWIDTH = math.max(1, grid.GRIDWIDTH + delta)
  fnutils.map(window.visibleWindows(), grid.snap)
end
grid.adjustWidth = grid.adjustNumberOfColumns

--- hs.grid.adjustFocusedWindow(fn)
--- Function
--- Calls a user specified function to adjust the currently focused window's cell
---
--- Parameters:
---  * fn - A function that accepts a cell-table as its only argument. The function should modify the cell-table as needed and return nothing
---
--- Returns:
---  * None
function grid.adjustFocusedWindow(fn)
  local win = window.focusedWindow()
  local f = grid.get(win)
  if f then
    fn(f)
    grid.set(win, f, win:screen())
  end
end

--- hs.grid.maximizeWindow()
--- Function
--- Moves and resizes the currently focused window to fill the entire grid
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function grid.maximizeWindow()
  local win = window.focusedWindow()
  local f = {x = 0, y = 0, w = grid.GRIDWIDTH, h = grid.GRIDHEIGHT}
  local winscreen = win:screen()
  if winscreen then
    grid.set(win, f, winscreen)
  end
end

--- hs.grid.pushWindowNextScreen()
--- Function
--- Moves the focused window to the next screen, retaining its cell
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function grid.pushWindowNextScreen()
  local win = window.focusedWindow()
  local gridframe = grid.get(win)
  if gridframe then
    grid.set(win, gridframe, win:screen():next())
  end
end

--- hs.grid.pushWindowPrevScreen()
--- Function
--- Moves the focused window to the previous screen, retaining its cell
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function grid.pushWindowPrevScreen()
  local win = window.focusedWindow()
  local gridframe = grid.get(win)
  if gridframe then
    grid.set(win, gridframe, win:screen():previous())
  end
end

--- hs.grid.pushWindowLeft()
--- Function
--- Moves the focused window one grid cell to the left
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function grid.pushWindowLeft()
  grid.adjustFocusedWindow(function(f) f.x = math.max(f.x - 1, 0) end)
end

--- hs.grid.pushWindowRight()
--- Function
--- Moves the focused window one cell to the right
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function grid.pushWindowRight()
  grid.adjustFocusedWindow(function(f) f.x = math.min(f.x + 1, grid.GRIDWIDTH - f.w) end)
end

--- hs.grid.resizeWindowWider()
--- Function
--- Resizes the focused window to be one cell wider
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * If the window hits the right edge of the screen and is asked to become wider, its left edge will shift further left
function grid.resizeWindowWider()
  grid.adjustFocusedWindow(function(f)
    if f.w + f.x >= grid.GRIDWIDTH and f.x > 0 then
      f.x = f.x - 1
    end
    f.w = math.min(f.w + 1, grid.GRIDWIDTH - f.x)
  end)
end

--- hs.grid.resizeWindowThinner()
--- Function
--- Resizes the focused window to be one cell thinner
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function grid.resizeWindowThinner()
  grid.adjustFocusedWindow(function(f) f.w = math.max(f.w - 1, 1) end)
end

--- hs.grid.pushWindowDown()
--- Function
--- Moves the focused window one grid cell down the screen
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function grid.pushWindowDown()
  grid.adjustFocusedWindow(function(f) f.y = math.min(f.y + 1, grid.GRIDHEIGHT - f.h) end)
end

--- hs.grid.pushWindowUp()
--- Function
--- Moves the focused window one grid cell up the screen
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function grid.pushWindowUp()
  grid.adjustFocusedWindow(function(f) f.y = math.max(f.y - 1, 0) end)
end

--- hs.grid.resizeWindowShorter()
--- Function
--- Resizes the focused window so its bottom edge moves one grid cell higher
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function grid.resizeWindowShorter()
  grid.adjustFocusedWindow(function(f) f.y = f.y - 0; f.h = math.max(f.h - 1, 1) end)
end

--- hs.grid.resizeWindowTaller()
--- Function
--- Resizes the focused window so its bottom edge moves one grid cell lower
---
--- Parameters:
---  * If the window hits the bottom edge of the screen and is asked to become taller, its top edge will shift further up
---
--- Returns:
---  * None
---
--- Notes:
function grid.resizeWindowTaller()
  grid.adjustFocusedWindow(function(f)
    if f.y + f.h >= grid.GRIDHEIGHT and f.y > 0 then
      f.y = f.y -1
    end
    f.h = math.min(f.h + 1, grid.GRIDHEIGHT - f.y)
  end)
end

return grid
