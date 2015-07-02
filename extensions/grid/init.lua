--- === hs.grid ===
---
--- Move/resize windows within a grid
---
--- The grid partitions your screens for the purposes of window management. The default layout of the grid is 3 columns by 3 rows.
--- You can specify different grid layouts for different screens and/or screen resolutions.
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
---
--- Additionally, a modal keyboard driven interface for interactive resizing is provided via `hs.grid.show()`

local fnutils = require "hs.fnutils"
local window = require "hs.window"
local screen = require 'hs.screen'
local drawing = require'hs.drawing'
local newmodal = require'hs.hotkey'.modal.new
local log = require'hs.logger'.new('grid')

local ipairs,pairs,min,max,floor,fmod = ipairs,pairs,math.min,math.max,math.floor,math.fmod
local sformat,smatch,type,tonumber,tostring,tinsert = string.format,string.match,type,tonumber,tostring,table.insert
local setmetatable,rawget,rawset=setmetatable,rawget,rawset


local gridSizes = {{w=3,h=3}} -- user-defined grid sizes for each screen or geometry, default ([1]) is 3x3
--i'm using [1] to ease the possible future addition of multiple grid layouts per screen (they'd get [2] etc.)
local margins = {w=5,h=5}

local grid = {setLogLevel=log.setLogLevel} -- module

local function toRect(screen)
  local typ,rect=type(screen)
  if typ=='userdata' and screen.fullFrame then
    rect=screen:fullFrame()
  elseif typ=='table' then
    if screen.w and screen.h then rect=screen
    elseif #screen>=2 then rect={w=screen[1],h=screen[2]}
    elseif screen.x and screen.y then rect={w=screen.x,h=screen.y} -- sneaky addition for setMargins
    end
  elseif typ=='string' then
    local w,h
    w,h=smatch(screen,'(%d+)[x,-](%d+)')
    if w and h then rect={w=tonumber(w),h=tonumber(h)} end
  end
  return rect
end

local function toKey(rect) return sformat('%dx%d',rect.w,rect.h) end


--- hs.grid.setGrid(grid,screen) -> hs.grid
--- Function
--- Sets the grid size for a given screen or screen resolution
---
--- Parameters:
---  * grid - the number of columns and rows for the grid; it can be:
---    * a string in the format `CxR` (columns and rows respectively)
---    * a table in the format `{C,R}` or `{w=C,h=R}`
---    * an `hs.geometry.rect` or `hs.geometry.size` object
---  * screen - the screen or screen geometry to apply the grid to; it can be:
---    * an `hs.screen` object
---    * a number identifying the screen, as returned by `myscreen:id()`
---    * a string in the format `WWWWxHHHH` where WWWW and HHHH are the screen width and heigth in screen points
---    * a table in the format `{WWWW,HHHH}` or `{w=WWWW,h=HHHH}`
---    * an `hs.geometry.rect` or `hs.geometry.size` object describing the screen width and heigth in screen points
---    * if omitted or nil, sets the default grid, which is used when no specific grid is found for any given screen/resolution
---
--- Returns:
---   * hs.grid for method chaining
---
--- Usage:
--- hs.grid.setGrid('5x3','1920x1080') -- sets the grid to 5x3 for all screens with a 1920x1080 resolution
--- hs.grid.setGrid{4,4} -- sets the default grid to 4x4

local deleteUI
function grid.setGrid(gr,scr)
  gr = toRect(gr)
  if not gr then error('Invalid grid',2) return end
  if scr~=nil then
    if type(scr)=='userdata' and scr.id then scr=scr:id() end
    if type(scr)~='number' then scr=toRect(scr) end
    if not scr then error('Invalid screen or geometry',2) return end
  else scr=1 end
  if type(scr)~='number' then scr=toKey(scr) end
  gr.w=min(gr.w,50) gr.h=min(gr.h,50) -- cap grid to 50x50, just in case
  gridSizes[scr]=gr
  if scr==1 then log.f('Default grid set to %d by %d',gr.w,gr.h)
  else log.f('Grid for %s set to %d by %d',tostring(scr),gr.w,gr.h) end
  deleteUI()
  return grid
end

--- hs.grid.setMargins(margins) -> hs.grid
--- Function
--- Sets the margins between windows
---
--- Parameters:
---  * margins - the desired margins between windows, in screen points; it can be:
---    * a string in the format `XXxYY` (horizontal and vertical margin respectively)
---    * a table in the format `{XX,YY}` or `{w=XX,h=YY}`
---    * an `hs.geometry.rect` or `hs.geometry.size` object
---
--- Returns:
---   * hs.grid for method chaining
function grid.setMargins(mar)
  mar=toRect(mar)
  if not mar then error('Invalid margins',2) return end
  margins=mar
  log.f('Window margins set to %d,%d',margins.w,margins.h)
  return grid
end


--- hs.grid.getGrid(screen) -> ncolumns, nrows
--- Function
--- Gets the defined grid size for a given screen or screen resolution
---
--- Parameters:
---  * screen - the screen or screen resolution to get the grid of; it can be:
---    * an `hs.screen` object
---    * a number identifying the screen, as returned by `myscreen:id()`
---    * a string in the format `WWWWxHHHH` where WWWW and HHHH are the screen width and heigth in screen points
---    * a table in the format `{WWWW,HHHH}` or `{w=WWWW,h=HHHH}`
---    * an `hs.geometry.rect` or `hs.geometry.size` object describing the screen width and heigth in screen points
---    * if omitted or nil, gets the default grid, which is used when no specific grid is found for any given screen/resolution
---
--- Returns:
---   * the number of columns in the grid
---   * the number of rows in the grid
---
--- Notes:
---   * if a grid was not set for the specified screen or geometry, the default grid will be returned
---
--- Usage:
--- local w,h = hs.grid.getGrid('1920x1080') -- gets the defined grid for all screens with a 1920x1080 resolution
--- local w,h=hs.grid.getGrid() hs.grid.setGrid{w+2,h} -- increases the number of columns in the default grid by 2

function grid.getGrid(scr)
  if scr~=nil then
    local scrobj
    if type(scr)=='userdata' and scr.id then scrobj=scr scr=scr:id() end
    if type(scr)~='number' then scr=toRect(scr) end
    if not scr then error('Invalid screen or geometry',2) return end
    if type(scr)=='number' then
      -- test with screen id
      if gridSizes[scr] then return gridSizes[scr].w,gridSizes[scr].h end
      -- check if there's a geometry matching the current resolution
      if not scrobj then
        local screens=screen.allScreens()
        for _,s in ipairs(screens) do
          if s:id()==scr then scrobj=s break end
        end
      end
      if scrobj then
        local screenframe=scrobj:fullFrame()
        scr=toKey(screenframe)
      end
    else
      scr=toKey(scr)
    end
    if gridSizes[scr] then return gridSizes[scr].w,gridSizes[scr].h end
  end
  return gridSizes[1].w,gridSizes[1].h
end


--- hs.grid.show()
--- Function
--- Shows the grid and starts the modal interactive resizing process for the focused window.
--- In most cases this function should be invoked via `hs.hotkey.bind` with some keyboard shortcut.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * In the modal interface, press the arrow keys to jump to adjacent screens; spacebar to maximize/unmaximize; esc to quit without any effect
---  * The keyboard hints assume a QWERTY layout; if you use a different layout, change `hs.grid.HINTS` accordingly

--- hs.grid.HINTS
--- Variable
--- A bidimensional array (table of tables of strings) holding the keyboard hints (as per `hs.keycodes.map`) to be used for the interactive resizing interface.
--- Change this if you don't use a QWERTY layout
---
--- Notes:
---  * `hs.inspect(hs.grid.HINTS)` from the console will show you how the table is built

local function getCellSize(screen)
  local gridw,gridh = grid.getGrid(screen)
  local screenframe = screen:frame()
  return screenframe.w/gridw, screenframe.h/gridh
end

local function round(num, idp)
  local mult = 10^(idp or 0)
  return floor(num * mult + 0.5) / mult
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
    log.w('Cannot get the window\'s screen')
    return nil
  end
  local screenframe = winscreen:frame()
  local cellw, cellh = getCellSize(winscreen)
  return {
    x = round((winframe.x - screenframe.x) / cellw),
    y = round((winframe.y - screenframe.y) / cellh),
    w = max(1, round(winframe.w / cellw)),
    h = max(1, round(winframe.h / cellh)),
  }
end

--- hs.grid.set(win, cell, screen) -> hs.grid
--- Function
--- Sets the cell for a window, on a particular screen
---
--- Parameters:
---  * win - An `hs.window` object representing the window to operate on
---  * cell - A cell-table to apply to the window
---  * screen - An `hs.screen` object representing the screen to place the window on
---
--- Returns:
---  * The `hs.grid` module for method chaining
function grid.set(win, cell, screen)
  local screenrect = screen:frame()
  local gridw,gridh = grid.getGrid(screen)
  -- sanitize, because why not
  cell.x=max(0,min(cell.x,gridw-1)) cell.y=max(0,min(cell.y,gridh-1))
  cell.w=max(1,min(cell.w,gridw-cell.x)) cell.h=max(1,min(cell.h,gridh-cell.y))
  local cellw, cellh = screenrect.w/gridw, screenrect.h/gridh
  local newframe = {
    x = (cell.x * cellw) + screenrect.x + margins.w,
    y = (cell.y * cellh) + screenrect.y + margins.h,
    w = cell.w * cellw - (margins.w * 2),
    h = cell.h * cellh - (margins.h * 2),
  }
  win:setFrame(newframe)
  return grid
end

--- hs.grid.snap(win) -> hs.grid
--- Function
--- Snaps a window into alignment with the nearest grid lines
---
--- Parameters:
---  * win - A `hs.window` object to snap
---
--- Returns:
---  * The `hs.grid` module for method chaining
function grid.snap(win)
  if win:isStandard() then
    local gridframe = grid.get(win)
    if gridframe then
      grid.set(win, gridframe, win:screen())
    end
  else log.i('Cannot snap nonstandard window') end
  return grid
end


--- hs.grid.adjustWindow(fn, window) -> hs.grid
--- Function
--- Calls a user specified function to adjust a window's cell
---
--- Parameters:
---  * fn - A function that accepts a cell-table as its only argument. The function should modify the cell-table as needed and return nothing
---  * window - An `hs.window` object to act on; if omitted, the focused window will be used
---
--- Returns:
---  * The `hs.grid` module for method chaining
function grid.adjustWindow(fn,win)
  if not win then win = window.focusedWindow() end
  if not win then log.w('Cannot get focused window') return grid end
  local f = grid.get(win)
  if not f then log.w('Cannot get window cell') return grid end
  fn(f)
  return grid.set(win, f, win:screen())
end

--- hs.grid.adjustFocusedWindow(fn) -> hs.grid
--- Function
--- Calls a user specified function to adjust the currently focused window's cell
---
--- Parameters:
---  * fn - A function that accepts a cell-table as its only argument. The function should modify the cell-table as needed and return nothing
---
--- Returns:
---  * The `hs.grid` module for method chaining
---
--- Notes:
---  * Legacy function, use `adjustWindow` instead
grid.adjustFocusedWindow=grid.adjustWindow

local function checkWindow(win)
  if not win then win = window.focusedWindow() end
  if not win then log.w('Cannot get focused window') return end
  if not win:screen() then log.w('Cannot get the window\'s screen') return end
  return win
end
--- hs.grid.maximizeWindow(window) -> hs.grid
--- Function
--- Moves and resizes a window to fill the entire grid
---
--- Parameters:
---  * window - An `hs.window` object to act on; if omitted, the focused window will be used
---
--- Returns:
---  * The `hs.grid` module for method chaining
function grid.maximizeWindow(win)
  win=checkWindow(win)
  if not win then return grid end
  local winscreen = win:screen()
  local w,h = grid.getGrid(winscreen)
  local f = {x = 0, y = 0, w = w, h = h}
  return grid.set(win, f, winscreen)
end

--- hs.grid.pushWindowNextScreen(window) -> hs.grid
--- Function
--- Moves a window to the next screen, snapping it to the screen's grid
---
--- Parameters:
---  * window - An `hs.window` object to act on; if omitted, the focused window will be used
---
--- Returns:
---  * The `hs.grid` module for method chaining
function grid.pushWindowNextScreen(win)
  win=checkWindow(win)
  if not win then return grid end
  local winscreen=win:screen()
  win:moveToScreen(winscreen:next())
  return grid.snap(win)
end

--- hs.grid.pushWindowPrevScreen(window) -> hs.grid
--- Function
--- Moves a window to the previous screen, snapping it to the screen's grid
---
--- Parameters:
---  * window - An `hs.window` object to act on; if omitted, the focused window will be used
---
--- Returns:
---  * The `hs.grid` module for method chaining
function grid.pushWindowPrevScreen(win)
  win=checkWindow(win)
  if not win then return grid end
  local winscreen=win:screen()
  win:moveToScreen(winscreen:previous())
  return grid.snap(win)
end

--- hs.grid.pushWindowLeft(window) -> hs.grid
--- Function
--- Moves a window one grid cell to the left, or onto the adjacent screen's grid when necessary
---
--- Parameters:
---  * window - An `hs.window` object to act on; if omitted, the focused window will be used
---
--- Returns:
---  * The `hs.grid` module for method chaining
function grid.pushWindowLeft(win)
  win=checkWindow(win)
  if not win then return grid end
  local winscreen = win:screen()
  local w,h = grid.getGrid(winscreen)
  local f = grid.get(win)
  if f.x<=0 then
    -- go to left screen
    local frame=win:frame()
    local newscreen=winscreen:toWest(frame)
    if not newscreen then return grid end
    frame.x = frame.x-frame.w
    win:setFrame(frame) win:ensureIsInScreenBounds()
    return grid.snap(win)
  else return grid.adjustWindow(function(f)f.x=f.x-1 end, win) end
end

--- hs.grid.pushWindowRight(window) -> hs.grid
--- Function
--- Moves a window one cell to the right, or onto the adjacent screen's grid when necessary
---
--- Parameters:
---  * window - An `hs.window` object to act on; if omitted, the focused window will be used
---
--- Returns:
---  * The `hs.grid` module for method chaining
function grid.pushWindowRight(win)
  win=checkWindow(win)
  if not win then return grid end
  local winscreen = win:screen()
  local w,h = grid.getGrid(winscreen)
  local f = grid.get(win)
  if f.x+f.w>=w then
    -- go to right screen
    local frame=win:frame()
    local newscreen=winscreen:toEast(frame)
    if not newscreen then return grid end
    frame.x = frame.x+frame.w
    win:setFrame(frame) win:ensureIsInScreenBounds()
    return grid.snap(win)
  else return grid.adjustWindow(function(f)f.x=f.x+1 end, win) end
end

--- hs.grid.resizeWindowWider(window) -> hs.grid
--- Function
--- Resizes a window to be one cell wider
---
--- Parameters:
---  * window - An `hs.window` object to act on; if omitted, the focused window will be used
---
--- Returns:
---  * The `hs.grid` module for method chaining
---
--- Notes:
---  * If the window hits the right edge of the screen and is asked to become wider, its left edge will shift further left
function grid.resizeWindowWider(win)
  win=checkWindow(win)
  if not win then return grid end
  local w,h = grid.getGrid(win:screen())
  return grid.adjustWindow(function(f)
    if f.w + f.x >= w and f.x > 0 then
      f.x = f.x - 1
    end
    f.w = min(f.w + 1, w - f.x)
  end, win)
end

--- hs.grid.resizeWindowThinner(window) -> hs.grid
--- Function
--- Resizes a window to be one cell thinner
---
--- Parameters:
---  * window - An `hs.window` object to act on; if omitted, the focused window will be used
---
--- Returns:
---  * The `hs.grid` module for method chaining
function grid.resizeWindowThinner(win)
  return grid.adjustWindow(function(f) f.w = max(f.w - 1, 1) end, win)
end

--- hs.grid.pushWindowDown(window) -> hs.grid
--- Function
--- Moves a window one grid cell down the screen, or onto the adjacent screen's grid when necessary
---
--- Parameters:
---  * window - An `hs.window` object to act on; if omitted, the focused window will be used
---
--- Returns:
---  * The `hs.grid` module for method chaining
function grid.pushWindowDown(win)
  win=checkWindow(win)
  if not win then return grid end
  local winscreen = win:screen()
  local w,h = grid.getGrid(winscreen)
  local f = grid.get(win)
  if f.y+f.h>=h then
    -- go to screen below
    local frame=win:frame()
    local newscreen=winscreen:toSouth(frame)
    if not newscreen then return grid end
    frame.y = frame.y+frame.h
    win:setFrame(frame) win:ensureIsInScreenBounds()
    return grid.snap(win)
  else return grid.adjustWindow(function(f)f.y=f.y+1 end, win) end
end

--- hs.grid.pushWindowUp(window) -> hs.grid
--- Function
--- Moves a window one grid cell up the screen, or onto the adjacent screen's grid when necessary
---
--- Parameters:
---  * window - An `hs.window` object to act on; if omitted, the focused window will be used
---
--- Returns:
---  * The `hs.grid` module for method chaining
function grid.pushWindowUp(win)
  win=checkWindow(win)
  if not win then return grid end
  local winscreen = win:screen()
  local w,h = grid.getGrid(winscreen)
  local f = grid.get(win)
  if f.y<=0 then
    -- go to screen above
    local frame=win:frame()
    local newscreen=winscreen:toNorth(frame)
    if not newscreen then return grid end
    frame.y = frame.y-frame.h
    win:setFrame(frame) win:ensureIsInScreenBounds()
    return grid.snap(win)
  else return grid.adjustWindow(function(f)f.y=f.y-1 end, win) end
end

--- hs.grid.resizeWindowShorter(window) -> hs.grid
--- Function
--- Resizes a window so its bottom edge moves one grid cell higher
---
--- Parameters:
---  * window - An `hs.window` object to act on; if omitted, the focused window will be used
---
--- Returns:
---  * The `hs.grid` module for method chaining
function grid.resizeWindowShorter(win)
  return grid.adjustWindow(function(f) f.y = f.y - 0; f.h = max(f.h - 1, 1) end, win)
end

--- hs.grid.resizeWindowTaller(window) -> hs.grid
--- Function
--- Resizes a window so its bottom edge moves one grid cell lower
---
--- Parameters:
---  * window - An `hs.window` object to act on; if omitted, the focused window will be used
---
--- Returns:
---  * The `hs.grid` module for method chaining
---
--- Notes:
---  * If the window hits the bottom edge of the screen and is asked to become taller, its top edge will shift further up
function grid.resizeWindowTaller(win)
  win=checkWindow(win)
  if not win then return grid end
  local w,h = grid.getGrid(win:screen())
  return grid.adjustWindow(function(f)
    if f.y + f.h >= h and f.y > 0 then
      f.y = f.y -1
    end
    f.h = min(f.h + 1, h - f.y)
  end, win)
end




-- modal grid stuff below

grid.HINTS={{'f1','f2','f3','f4','f5','f6','f7','f8'},
  {'1','2','3','4','5','6','7','8'},
  {'Q','W','E','R','T','Y','U','I'},
  {'A','S','D','F','G','H','J','K'},
  {'Z','X','C','V','B','N','M',','}
}

local HINTS_ROWS = {{4},{3,4},{3,4,5},{2,3,4,5},{1,2,3,4,5}}
--TODO (unlikely) expose this to allow crazy custom bindings (e.g. rotated 90 degrees on the keyboard for portrait screens?)

local COLOR_BLACK={red=0,green=0,blue=0,alpha=1}
local COLOR_WHITE={red=1,green=1,blue=1,alpha=1}
local COLOR_DARKOVERLAY={red=0,green=0,blue=0,alpha=0.25}
local COLOR_HIGHLIGHT={red=0.8,green=0.75,blue=0,alpha=0.55}
local COLOR_SELECTED={red=0.2,green=0.75,blue=0,alpha=0.4}
local COLOR_YELLOW={red=0.8,green=0.75,blue=0,alpha=1}


local uielements -- drawing objects
local resizing -- modal "hotkey"

deleteUI=function()
  if not uielements then return end
  for _,s in pairs(uielements) do
    s.howto.rect:delete() s.howto.text:delete()
    for _,e in pairs(s.hints) do
      e.rect:delete() e.text:delete()
    end
  end
  uielements = nil
end
local function makeUI()
  deleteUI()
  uielements = {}
  local screens = screen.allScreens()
  local function dist(i,w1,w2) return round((i-1)/w1*w2)+1 end
  for i,screen in ipairs(screens) do
    local w,h = grid.getGrid(screen)
    local cellw,cellh = getCellSize(screen)
    local frame = screen:frame()
    log.f('Screen #%d %s (%s) -> grid %d by %d (%dx%d cells)',i,screen:name(),toKey(frame),w,h,floor(cellw),floor(cellh))
    local htf = {w=500,h=100}
    htf.x = frame.x+frame.w/2-htf.w/2  htf.y = frame.y+frame.h/2-htf.h/2
    if fmod(h,2)==1 then htf.y=htf.y-cellh/2 end
    local howtorect = drawing.rectangle(htf)
    howtorect:setFill(true) howtorect:setFillColor(COLOR_DARKOVERLAY) howtorect:setStrokeWidth(5)
    local howtotext=drawing.text(htf,'    ←→↑↓:select screen\n  space:fullscreen esc:exit')
    howtotext:setTextSize(40) howtotext:setTextColor(COLOR_WHITE)
    local sid=screen:id()
    uielements[sid] = {left=(screen:toWest() or screen):id(),
      up=(screen:toNorth() or screen):id(),
      right=(screen:toEast() or screen):id(),
      down=(screen:toSouth() or screen):id(),
      screen=screen, frame=frame,
      howto={rect=howtorect,text=howtotext},
      hints={}}
    -- create the ui for cells
    local hintsw,hintsh = #grid.HINTS[1],#grid.HINTS
    for hx=min(hintsw,w),1,-1 do
      local cx,cx2 = hx,hx+1
      -- allow for grid width > # available hint columns
      if w>hintsw then cx=dist(cx,hintsw,w) cx2=dist(cx2,hintsw,w) end
      local x,x2 = frame.x+cellw*(cx-1),frame.x+cellw*(cx2-1)
      for hy=min(hintsh,h),1,-1 do
        local cy,cy2 = hy,hy+1
        -- allow for grid heigth > # available hint rows
        if h>hintsh then cy=dist(cy,hintsh,h) cy2=dist(cy2,hintsh,h) end
        local y,y2 = frame.y+cellh*(cy-1),frame.y+cellh*(cy2-1)
        local elem = {x=x,y=y,w=x2-x,h=y2-y}
        local rect = drawing.rectangle(elem)
        rect:setFill(true) rect:setFillColor(COLOR_DARKOVERLAY)
        rect:setStroke(true) rect:setStrokeColor(COLOR_BLACK) rect:setStrokeWidth(5)
        elem.rect = rect
        elem.hint = grid.HINTS[HINTS_ROWS[min(h,hintsh)][hy]][hx]
        local text=drawing.text({x=x+(x2-x)/2-100,y=y+(y2-y)/2-100,w=200,h=200},elem.hint)
        text:setTextSize(200)--ystep/3*2)
        text:setTextColor(COLOR_WHITE)
        elem.text=text
        log.vf('[%d] %s %.0f,%.0f>%.0f,%.0f',i,elem.hint,elem.x,elem.y,elem.x+elem.w,elem.y+elem.h)
        tinsert(uielements[sid].hints,elem)
      end
    end
  end
end


local function showGrid(id)
  if not id or not uielements[id] then log.e('Cannot get current screen, aborting') return end
  local elems = uielements[id].hints
  for _,e in ipairs(elems) do e.rect:show() e.text:show() end
  uielements[id].howto.rect:show() uielements[id].howto.text:show()
end
local function hideGrid(id)
  if not id or not uielements or not uielements[id] then --[[log.e('Cannot obtain current screen') --]] return end
  uielements[id].howto.rect:hide() uielements[id].howto.text:hide()
  local elems = uielements[id].hints
  for _,e in pairs(elems) do e.rect:hide() e.text:hide() end
end



local initialized, currentScreen, currentWindow, highlight
local function _start()
  if initialized then return end
  screen.watcher.new(deleteUI):start()
  resizing=newmodal()
  local function showHighlight()
    if highlight then highlight:delete() end
    highlight = drawing.rectangle(currentWindow:frame())
    highlight:setFill(true) highlight:setFillColor(COLOR_HIGHLIGHT)
    highlight:setStroke(true) highlight:setStrokeColor(COLOR_YELLOW) highlight:setStrokeWidth(30)
    highlight:show()
  end
  function resizing:entered()
    currentWindow = window.focusedWindow()
    if not currentWindow then log.w('Cannot get current window, aborting') resizing:exit() return end
    log.df('Start moving %s [%s]',currentWindow:subrole(),currentWindow:application():title())
    --  if window:isFullScreen() then resizing:exit() alert('(')return end
    --TODO check fullscreen
    currentScreen = (currentWindow:screen() or screen.mainScreen()):id()
    showHighlight()
    if not uielements then makeUI() end
    showGrid(currentScreen)
  end
  local selectedElem
  local function clearSelection()
    if selectedElem then
      selectedElem.rect:setFillColor(COLOR_DARKOVERLAY)
      selectedElem = nil
    end
  end
  function resizing:exited()
    if highlight then highlight:delete() highlight=nil end
    clearSelection()
    hideGrid(currentScreen)
  end
  resizing:bind({},'escape',function()log.d('abort move')resizing:exit()end)
  resizing:bind({},'space',function()
    --    local wasfs=currentWindow:isFullScreen()
    log.d('toggle fullscreen')currentWindow:toggleFullScreen()
    if currentWindow:isFullScreen() then resizing:exit()
      --    elseif not wasfs then currentWindow:setFrame(currentWindow:screen():frame(),0) resizing:exit()
    end
  end)
  for _,dir in ipairs({'left','right','up','down'}) do
    resizing:bind({},dir,function()
      log.d('select screen '..dir)
      clearSelection() hideGrid(currentScreen)
      currentScreen=uielements[currentScreen][dir]
      currentWindow:moveToScreen(uielements[currentScreen].screen,0)
      showHighlight()
      showGrid(currentScreen)
    end)
  end
  local function hintPressed(c)
    -- find the elem; if there was a way to unbind modals, we'd unbind on screen change, and pass here the elem directly
    local elem = fnutils.find(uielements[currentScreen].hints,function(e)return e.hint==c end)
    if not elem then return end
    if not selectedElem then
      selectedElem = elem
      elem.rect:setFillColor(COLOR_SELECTED)
    else
      local x1,x2,y1,y2
      x1,x2 = min(selectedElem.x,elem.x)+margins.w,max(selectedElem.x,elem.x)-margins.h
      y1,y2 = min(selectedElem.y,elem.y)+margins.w,max(selectedElem.y,elem.y)-margins.h
      local frame={x=x1,y=y1,w=x2-x1+elem.w,h=y2-y1+elem.h}
      currentWindow:setFrame(frame,0)
      log.f('move to %.0f,%.0f[%.0fx%.0f]',frame.x,frame.y,frame.w,frame.h)
      resizing:exit()
    end
  end
  for _,row in ipairs(grid.HINTS) do
    for _,c in ipairs(row) do
      resizing:bind({},c,function()hintPressed(c) end)
    end
  end
  --TODO perhaps disable all other keyboard input?
  initialized=true
end

function grid.show()
  if not initialized then _start()
  else resizing:exit() end
  resizing:enter()
end




-- Legacy stuff below


--- hs.grid.MARGINX = 5
--- Variable
--- The margin between each window horizontally, measured in screen points (typically a point is a pixel on a non-retina screen, or two pixels on a retina screen
---
--- Notes:
---   * Legacy variable; use `setMargins` instead
--grid.MARGINX = 5

--- hs.grid.MARGINY = 5
--- Variable
--- The margin between each window vertically, measured in screen points (typically a point is a pixel on a non-retina screen, or two pixels on a retina screen)
---
--- Notes:
---   * Legacy variable; use `setMargins` instead
--grid.MARGINY = 5

--- hs.grid.GRIDHEIGHT = 3
--- Variable
--- The number of rows in the grid
---
--- Notes:
---   * Legacy variable; use `setGrid` instead
--grid.GRIDHEIGHT = 3

--- hs.grid.GRIDWIDTH = 3
--- Variable
--- The number of columns in the grid
---
--- Notes:
---   * Legacy variable; use `setGrid` instead
--grid.GRIDWIDTH = 3
setmetatable(grid,{
  __index = function(t,k)
    if k=='GRIDWIDTH' then return gridSizes[1].w
    elseif k=='GRIDHEIGHT' then return gridSizes[1].h
    elseif k=='MARGINX' then return margins.w
    elseif k=='MARGINY' then return margins.h
    else return rawget(t,k) end
  end,
  __newindex = function(t,k,v)
    if k=='GRIDWIDTH' then grid.setGrid{v,gridSizes[1].h}
    elseif k=='GRIDHEIGHT' then grid.setGrid{gridSizes[1].w,v}
    elseif k=='MARGINX' then grid.setMargins{v,margins.h}
    elseif k=='MARGINY' then grid.setMargins{margins.w,v}
    else rawset(t,k,v) end
  end,
}) -- metatable for legacy variables

--- hs.grid.adjustNumberOfRows(delta)
--- Function
--- Increases or decreases the number of rows in the default grid, then snaps all windows to the new grid
---
--- Parameters:
---  * delta - A number to increase or decrease the rows of the default grid by. Positive to increase the number of rows, negative to decrease it
---
--- Returns:
---  * None
---
--- Notes:
---  * Legacy function; use `getGrid` and `setGrid` instead
---  * Screens with a specified grid (via `setGrid`) won't be affected, as this function only alters the default grid
function grid.adjustNumberOfRows(delta)
  grid.GRIDHEIGHT = max(1, grid.GRIDHEIGHT + delta)
  fnutils.map(window.visibleWindows(), grid.snap)
end
-- This is for legacy purposes
grid.adjustHeight = grid.adjustNumberOfRows

--- hs.grid.adjustNumberOfColumns(delta)
--- Function
--- Increases or decreases the number of columns in the default grid, then snaps all windows to the new grid
---
--- Parameters:
---  * delta - A number to increase or decrease the columns of the default grid by. Positive to increase the number of columns, negative to decrease it
---
--- Returns:
---  * None
---
--- Notes:
---  * Legacy function; use `getGrid` and `setGrid` instead
---  * Screens with a specified grid (via `setGrid`) won't be affected, as this function only alters the default grid
function grid.adjustNumberOfColumns(delta)
  grid.GRIDWIDTH = max(1, grid.GRIDWIDTH + delta)
  fnutils.map(window.visibleWindows(), grid.snap)
end
grid.adjustWidth = grid.adjustNumberOfColumns


return grid
