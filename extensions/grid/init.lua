--- === hs.grid ===
---
--- Move/resize windows within a grid
---
--- The grid partitions your screens for the purposes of window management. The default layout of the grid is 3 columns by 3 rows.
--- You can specify different grid layouts for different screens and/or screen resolutions.
---
--- Windows that are aligned with the grid have their location and size described as a `cell`. Each cell is an `hs.geometry` rect with these fields:
---  * x - The column of the left edge of the window
---  * y - The row of the top edge of the window
---  * w - The number of columns the window occupies
---  * h - The number of rows the window occupies
---
--- For a grid of 3x3:
---  * a cell `'0,0 1x1'` will be in the upper-left corner
---  * a cell `'2,0 1x1'` will be in the upper-right corner
---  * and so on...
---
--- Additionally, a modal keyboard driven interface for interactive resizing is provided via `hs.grid.show()`;
--- the grid will be overlaid on the focused or frontmost window's screen with keyboard hints to select the corner cells for
--- the desired size/position; you can also use the arrow keys to move the window onto adjacent screens, and
--- the tab/shift-tab keys to cycle to the next/previous window.

local window = require "hs.window"
local screen = require 'hs.screen'
local drawing = require'hs.drawing'
local geom = require'hs.geometry'
local timer = require'hs.timer'
local newmodal = require'hs.hotkey'.modal.new
local log = require'hs.logger'.new('grid')

local ipairs,pairs,min,max,floor,fmod = ipairs,pairs,math.min,math.max,math.floor,math.fmod
local sformat,smatch,ssub,ulen,type,tonumber,tostring = string.format,string.match,string.sub,utf8.len,type,tonumber,tostring
local tinsert,tpack=table.insert,table.pack
local setmetatable,rawget,rawset=setmetatable,rawget,rawset


local gridSizes = {[true]=geom'3x3'} -- user-defined grid sizes for each screen or geometry, default ([true]) is 3x3
local margins = geom'5x5'

local grid = {setLogLevel=log.setLogLevel,getLogLevel=log.getLogLevel} -- module


--- hs.grid.setGrid(grid,screen) -> hs.grid
--- Function
--- Sets the grid size for a given screen or screen resolution
---
--- Parameters:
---  * grid - an `hs.geometry` size, or argument to construct one, indicating the number of columns and rows for the grid
---  * screen - an `hs.screen` object, or a valid argument to `hs.screen.find()`, indicating the screen(s) to apply the grid to;
---    if omitted or nil, sets the default grid, which is used when no specific grid is found for any given screen/resolution
---
--- Returns:
---   * the `hs.grid` module for method chaining
---
--- Usage:
--- hs.grid.setGrid('5x3','Color LCD') -- sets the grid to 5x3 for any screen named "Color LCD"
--- hs.grid.setGrid('8x5','1920x1080') -- sets the grid to 8x5 for all screens with a 1920x1080 resolution
--- hs.grid.setGrid'4x4' -- sets the default grid to 4x4

local deleteUI
local function getScreenParam(scr)
  if scr==nil then return true end
  if getmetatable(scr)==hs.getObjectMetatable'hs.screen' then scr=scr:id() end
  if type(scr)=='string' or type(scr)=='table' then
    local ok,res=pcall(geom.new,scr)
    if ok then scr=res.string end
  end
  if type(scr)~='string' and type(scr)~='number' then error('invalid screen or geometry',3) end
  return scr
end
function grid.setGrid(gr,scr)
  gr=geom.new(gr)
  if geom.type(gr)~='size' then error('invalid grid',2) end
  scr=getScreenParam(scr)
  gr.w=min(gr.w,100) gr.h=min(gr.h,100) -- cap grid to 100x100, just in case
  gridSizes[scr]=gr
  if scr==true then log.f('default grid set to %s',gr.string)
  else log.f('grid for %s set to %s',scr,gr.string) end
  deleteUI()
  return grid
end

--- hs.grid.setMargins(margins) -> hs.grid
--- Function
--- Sets the margins between windows
---
--- Parameters:
---  * margins - an `hs.geometry` point or size, or argument to construct one, indicating the desired margins between windows in screen points
---
--- Returns:
---   * the `hs.grid` module for method chaining
function grid.setMargins(mar)
  mar=geom.new(mar)
  if geom.type(mar)=='point' then mar=geom.size(mar.x,mar.y) end
  if geom.type(mar)~='size' then error('invalid margins',2)end
  margins=mar
  log.f('window margins set to %s',margins.string)
  return grid
end


--- hs.grid.getGrid(screen) -> hs.geometry size
--- Function
--- Gets the defined grid size for a given screen or screen resolution
---
--- Parameters:
---  * screen - an `hs.screen` object, or a valid argument to `hs.screen.find()`, indicating the screen to get the grid of;
---    if omitted or nil, gets the default grid, which is used when no specific grid is found for any given screen/resolution
---
--- Returns:
---   * an `hs.geometry` size object indicating the number of columns and rows in the grid
---
--- Notes:
---   * if a grid was not set for the specified screen or geometry, the default grid will be returned
---
--- Usage:
--- local mygrid = hs.grid.getGrid('1920x1080') -- gets the defined grid for all screens with a 1920x1080 resolution
--- local defgrid=hs.grid.getGrid() defgrid.w=defgrid.w+2 -- increases the number of columns in the default grid by 2

-- interestingly, that last example above can be used to defeat the 100x100 cap

local function getGrid(screenObject)
  if not screenObject then return gridSizes[true] end
  local id=screenObject:id()
  for k,gridsize in pairs(gridSizes) do
    if k~=true then
      local screens=tpack(screen.find(k))
      for _,s in ipairs(screens) do if s:id()==id then return gridsize end end
    end
  end
  return gridSizes[true]
end
function grid.getGrid(scr)
  scr=getScreenParam(scr)
  if gridSizes[scr] then return gridSizes[scr] end
  return getGrid(screen.find(scr))
end


--- hs.grid.show([exitedCallback][, multipleWindows])
--- Function
--- Shows the grid and starts the modal interactive resizing process for the focused or frontmost window.
--- In most cases this function should be invoked via `hs.hotkey.bind` with some keyboard shortcut.
---
--- Parameters:
---  * exitedCallback - (optional) a function that will be called after the user dismisses the modal interface
---  * multipleWindows - (optional) if `true`, the resizing grid won't automatically go away after selecting the desired cells
---    for the frontmost window; instead, it'll switch to the next window
---
--- Returns:
---  * None
---
--- Notes:
---  * In the modal interface, press the arrow keys to jump to adjacent screens; spacebar to maximize/unmaximize; esc to quit without any effect
---  * Pressing `tab` or `shift-tab` in the modal interface will cycle to the next or previous window; if `multipleWindows`
---    is false or omitted, the first press will just enable the multiple windows behaviour
---  * The keyboard hints assume a QWERTY layout; if you use a different layout, change `hs.grid.HINTS` accordingly

--- hs.grid.hide()
--- Function
--- Hides the grid, if visible, and exits the modal resizing mode.
--- Call this function if you need to make sure the modal is exited without waiting for the user to press `esc`.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * If an exit callback was provided when invoking the modal interface, calling `.hide()` will call it

--- hs.grid.toggleShow([exitedCallback][, multipleWindows])
--- Function
--- Toggles the grid and modal resizing mode - see `hs.grid.show()` and `hs.grid.hide()`
---
--- Parameters: see `hs.grid.show()`
---
--- Returns:
---  * None

--- hs.grid.HINTS
--- Variable
--- A bidimensional array (table of tables of strings) holding the keyboard hints (as per `hs.keycodes.map`) to be used for the interactive resizing interface.
--- Change this if you don't use a QWERTY layout
---
--- Notes:
---  * `hs.inspect(hs.grid.HINTS)` from the console will show you how the table is built

local function getCellSize(screen)
  local grid=getGrid(screen)
  local screenframe=screen:frame()
  return geom.size(screenframe.w/grid.w,screenframe.h/grid.h)
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
--- * an `hs.window` object to get the cell of
---
--- Returns:
--- * a cell object (i.e. an `hs.geometry` rect), or nil if an error occurred
function grid.get(win)
  local winframe = win:frame()
  local winscreen = win:screen()
  if not winscreen then log.e('Cannot get the window\'s screen') return end
  local screenframe = winscreen:frame()
  local cellsize = getCellSize(winscreen)
  return geom{
    x = round((winframe.x - screenframe.x) / cellsize.w),
    y = round((winframe.y - screenframe.y) / cellsize.h),
    w = max(1, round(winframe.w / cellsize.w)),
    h = max(1, round(winframe.h / cellsize.h)),
  }
end

--- hs.grid.set(win, cell, screen) -> hs.grid
--- Function
--- Sets the cell for a window on a particular screen
---
--- Parameters:
---  * win - an `hs.window` object representing the window to operate on
---  * cell - a cell object, i.e. an `hs.geometry` rect or argument to construct one, to apply to the window
---  * screen - (optional) an `hs.screen` object or argument to `hs.screen.find()` representing the screen to place the window on; if omitted
---             the window's current screen will be used
---
--- Returns:
---  * the `hs.grid` module for method chaining
function grid.set(win, cell, scr)
  if not win then error('win cannot be nil',2) end
  scr=screen.find(scr)
  if not scr then scr=win:screen() end
  if not scr then log.e('Cannot get the window\'s screen') return grid end
  cell=geom.new(cell)
  local screenrect = scr:frame()
  local screengrid = getGrid(scr)
  -- sanitize, because why not
  cell.x=max(0,min(cell.x,screengrid.w-1)) cell.y=max(0,min(cell.y,screengrid.h-1))
  cell.w=max(1,min(cell.w,screengrid.w-cell.x)) cell.h=max(1,min(cell.h,screengrid.h-cell.y))
  local cellw, cellh = screenrect.w/screengrid.w, screenrect.h/screengrid.h
  local newframe = {
    x = (cell.x * cellw) + screenrect.x + margins.w,
    y = (cell.y * cellh) + screenrect.y + margins.h,
    w = cell.w * cellw - (margins.w * 2),
    h = cell.h * cellh - (margins.h * 2),
  }
  win:setFrameInScreenBounds(newframe) --TODO check this (against screen bottom stickiness)
  return grid
end

--- hs.grid.snap(win) -> hs.grid
--- Function
--- Snaps a window into alignment with the nearest grid lines
---
--- Parameters:
---  * win - an `hs.window` object to snap
---
--- Returns:
---  * the `hs.grid` module for method chaining
function grid.snap(win)
  if win:isStandard() then
    local cell = grid.get(win)
    if cell then grid.set(win, cell)
    else log.e('Cannot get the window\'s cell') end
  else log.e('Cannot snap nonstandard window') end
  return grid
end


--- hs.grid.adjustWindow(fn, window) -> hs.grid
--- Function
--- Calls a user specified function to adjust a window's cell
---
--- Parameters:
---  * fn - a function that accepts a cell object as its only argument. The function should modify it as needed and return nothing
---  * window - an `hs.window` object to act on; if omitted, the focused or frontmost window will be used
---
--- Returns:
---  * the `hs.grid` module for method chaining
function grid.adjustWindow(fn,win)
  if not win then win = window.frontmostWindow() end
  if not win then log.w('Cannot get frontmost window') return grid end
  local f = grid.get(win)
  if not f then log.e('Cannot get window cell') return grid end
  fn(f)
  return grid.set(win, f)
end

grid.adjustFocusedWindow=grid.adjustWindow

local function checkWindow(win)
  if not win then win = window.frontmostWindow() end
  if not win then log.w('Cannot get frontmost window') return end
  if not win:screen() then log.w('Cannot get the window\'s screen') return end
  return win
end

--- hs.grid.maximizeWindow(window) -> hs.grid
--- Function
--- Moves and resizes a window to fill the entire grid
---
--- Parameters:
---  * window - an `hs.window` object to act on; if omitted, the focused or frontmost window will be used
---
--- Returns:
---  * the `hs.grid` module for method chaining
function grid.maximizeWindow(win)
  win=checkWindow(win) if not win then return grid end
  local winscreen = win:screen()
  local screengrid = getGrid(winscreen)
  return grid.set(win, {0,0,screengrid.w,screengrid.h}, winscreen)
end

-- deprecate these two, :next() and :previous() screens are useless anyway due to random order
function grid.pushWindowNextScreen(win)
  win=checkWindow(win) if not win then return grid end
  local winscreen=win:screen()
  win:moveToScreen(winscreen:next())
  return grid.snap(win)
end
function grid.pushWindowPrevScreen(win)
  win=checkWindow(win) if not win then return grid end
  local winscreen=win:screen()
  win:moveToScreen(winscreen:previous())
  return grid.snap(win)
end

--- hs.grid.pushWindowLeft(window) -> hs.grid
--- Function
--- Moves a window one grid cell to the left, or onto the adjacent screen's grid when necessary
---
--- Parameters:
---  * window - an `hs.window` object to act on; if omitted, the focused or frontmost window will be used
---
--- Returns:
---  * the `hs.grid` module for method chaining
function grid.pushWindowLeft(win)
  win=checkWindow(win) if not win then return grid end
  local winscreen = win:screen()
  local cell = grid.get(win)
  if cell.x<=0 then
    -- go to left screen
    local frame=win:frame()
    local newscreen=winscreen:toWest(frame)
    if not newscreen then return grid end
    frame.x = frame.x-frame.w
    win:setFrameInScreenBounds(frame)
    return grid.snap(win)
  else return grid.adjustWindow(function(f)f.x=f.x-1 end, win) end
end

--- hs.grid.pushWindowRight(window) -> hs.grid
--- Function
--- Moves a window one cell to the right, or onto the adjacent screen's grid when necessary
---
--- Parameters:
---  * window - an `hs.window` object to act on; if omitted, the focused or frontmost window will be used
---
--- Returns:
---  * the `hs.grid` module for method chaining
function grid.pushWindowRight(win)
  win=checkWindow(win) if not win then return grid end
  local winscreen = win:screen()
  local screengrid = getGrid(winscreen)
  local cell = grid.get(win)
  if cell.x+cell.w>=screengrid.w then
    -- go to right screen
    local frame=win:frame()
    local newscreen=winscreen:toEast(frame)
    if not newscreen then return grid end
    frame.x = frame.x+frame.w
    win:setFrameInScreenBounds(frame)
    return grid.snap(win)
  else return grid.adjustWindow(function(f)f.x=f.x+1 end, win) end
end

--- hs.grid.resizeWindowWider(window) -> hs.grid
--- Function
--- Resizes a window to be one cell wider
---
--- Parameters:
---  * window - an `hs.window` object to act on; if omitted, the focused or frontmost window will be used
---
--- Returns:
---  * the `hs.grid` module for method chaining
---
--- Notes:
---  * if the window hits the right edge of the screen and is asked to become wider, its left edge will shift further left
function grid.resizeWindowWider(win)
  win=checkWindow(win) if not win then return grid end
  local screengrid = getGrid(win:screen())
  return grid.adjustWindow(function(f)
    if f.w + f.x >= screengrid.w and f.x > 0 then
      f.x = f.x - 1
    end
    f.w = min(f.w + 1, screengrid.w - f.x)
  end, win)
end

--- hs.grid.resizeWindowThinner(window) -> hs.grid
--- Function
--- Resizes a window to be one cell thinner
---
--- Parameters:
---  * window - an `hs.window` object to act on; if omitted, the focused or frontmost window will be used
---
--- Returns:
---  * the `hs.grid` module for method chaining
function grid.resizeWindowThinner(win)
  return grid.adjustWindow(function(f) f.w = max(f.w - 1, 1) end, win)
end

--- hs.grid.pushWindowDown(window) -> hs.grid
--- Function
--- Moves a window one grid cell down the screen, or onto the adjacent screen's grid when necessary
---
--- Parameters:
---  * window - an `hs.window` object to act on; if omitted, the focused or frontmost window will be used
---
--- Returns:
---  * the `hs.grid` module for method chaining
function grid.pushWindowDown(win)
  win=checkWindow(win) if not win then return grid end
  local winscreen = win:screen()
  local screengrid = getGrid(winscreen)
  local cell = grid.get(win)
  if cell.y+cell.h>=screengrid.h then
    -- go to screen below
    local frame=win:frame()
    local newscreen=winscreen:toSouth(frame)
    if not newscreen then return grid end
    frame.y = frame.y+frame.h
    win:setFrameInScreenBounds(frame)
    return grid.snap(win)
  else return grid.adjustWindow(function(f)f.y=f.y+1 end, win) end
end

--- hs.grid.pushWindowUp(window) -> hs.grid
--- Function
--- Moves a window one grid cell up the screen, or onto the adjacent screen's grid when necessary
---
--- Parameters:
---  * window - an `hs.window` object to act on; if omitted, the focused or frontmost window will be used
---
--- Returns:
---  * the `hs.grid` module for method chaining
function grid.pushWindowUp(win)
  win=checkWindow(win) if not win then return grid end
  local winscreen = win:screen()
  local cell = grid.get(win)
  if cell.y<=0 then
    -- go to screen above
    local frame=win:frame()
    local newscreen=winscreen:toNorth(frame)
    if not newscreen then return grid end
    frame.y = frame.y-frame.h
    win:setFrameInScreenBounds(frame)
    return grid.snap(win)
  else return grid.adjustWindow(function(f)f.y=f.y-1 end, win) end
end

--- hs.grid.resizeWindowShorter(window) -> hs.grid
--- Function
--- Resizes a window so its bottom edge moves one grid cell higher
---
--- Parameters:
---  * window - an `hs.window` object to act on; if omitted, the focused or frontmost window will be used
---
--- Returns:
---  * the `hs.grid` module for method chaining
function grid.resizeWindowShorter(win)
  return grid.adjustWindow(function(f) f.y = f.y - 0; f.h = max(f.h - 1, 1) end, win)
end

--- hs.grid.resizeWindowTaller(window) -> hs.grid
--- Function
--- Resizes a window so its bottom edge moves one grid cell lower
---
--- Parameters:
---  * window - an `hs.window` object to act on; if omitted, the focused or frontmost window will be used
---
--- Returns:
---  * the `hs.grid` module for method chaining
---
--- Notes:
---  * if the window hits the bottom edge of the screen and is asked to become taller, its top edge will shift further up
function grid.resizeWindowTaller(win)
  win=checkWindow(win) if not win then return grid end
  local screengrid = getGrid(win:screen())
  return grid.adjustWindow(function(f)
    if f.y + f.h >= screengrid.h and f.y > 0 then
      f.y = f.y -1
    end
    f.h = min(f.h + 1, screengrid.h - f.y)
  end, win)
end




-- modal grid stuff below

grid.HINTS={{'f1','f2','f3','f4','f5','f6','f7','f8','f9','f10'},
  {'1','2','3','4','5','6','7','8','9','0'},
  {'Q','W','E','R','T','Y','U','I','O','P'},
  {'A','S','D','F','G','H','J','K','L',';'},
  {'Z','X','C','V','B','N','M',',','.','/'}
}

local _HINTROWS,_HINTS = {{4},{3,4},{3,4,5},{2,3,4,5},{1,2,3,4,5},{1,2,3,9,4,5},{1,2,8,3,9,4,5},{1,2,8,3,9,4,10,5},{1,7,2,8,3,9,4,10,5},{1,6,2,7,3,8,9,4,10,5}}
-- 10x10 grid should be enough for anybody

local function getColor(t)
  if t.red then return t
  else return {red=t[1] or 0,green=t[2] or 0,blue=t[3] or 0,alpha=t[4] or 1} end
end

--- hs.grid.ui
--- Variable
--- Allows customization of the modal resizing grid user interface
---
--- This table contains variables that you can change to customize the look of the modal resizing grid.
--- The default values are shown in the right hand side of the assignements below.
---
--- To represent color values, you can use:
---  * a table {red=redN, green=greenN, blue=blueN, alpha=alphaN}
---  * a table {redN,greenN,blueN[,alphaN]} - if omitted alphaN defaults to 1.0
--- where redN, greenN etc. are the desired value for the color component between 0.0 and 1.0
---
--- The following variables must be color values:
---  * `hs.grid.ui.textColor = {1,1,1}`
---  * `hs.grid.ui.cellColor = {0,0,0,0.25}`
---  * `hs.grid.ui.cellStrokeColor = {0,0,0}`
---  * `hs.grid.ui.selectedColor = {0.2,0.7,0,0.4}` -- for the first selected cell during a modal resize
---  * `hs.grid.ui.highlightColor = {0.8,0.8,0,0.5}` -- to highlight the frontmost window behind the grid
---  * `hs.grid.ui.highlightStrokeColor = {0.8,0.8,0,1}`
---  * `hs.grid.ui.cyclingHighlightColor = {0,0.8,0.8,0.5}` -- to highlight the window to be resized, when cycling among windows
---  * `hs.grid.ui.cyclingHighlightStrokeColor = {0,0.8,0.8,1}`
---
--- The following variables must be numbers (in screen points):
---  * `hs.grid.ui.textSize = 200`
---  * `hs.grid.ui.cellStrokeWidth = 5`
---  * `hs.grid.ui.highlightStrokeWidth = 30`
---
--- The following variables must be strings:
---  * `hs.grid.ui.fontName = 'Lucida Grande'`
---
--- The following variables must be booleans:
---  * `hs.grid.ui.showExtraKeys = true` -- show non-grid keybindings in the center of the grid
local ui = {
  textColor={1,1,1},
  textSize=200,
  cellStrokeColor={0,0,0},
  cellStrokeWidth=5,
  cellColor={0,0,0,0.25},
  highlightColor={0.8,0.8,0,0.5},
  highlightStrokeColor={0.8,0.8,0,1},
  cyclingHighlightColor={0,0.8,0.8,0.5},
  cyclingHighlightStrokeColor={0,0.8,0.8,1},
  highlightStrokeWidth=30,
  selectedColor={0.2,0.7,0,0.4},
  showExtraKeys=true,
  fontName='Lucida Grande'
}

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
  _HINTS=nil
end

grid.ui=setmetatable({},{__newindex=function(t,k,v) ui[k]=v deleteUI()end,__index=ui})
local function makeHints() -- quick hack to double up rows (for portrait screens mostly)
  if _HINTS then return end
  _HINTS={}
  local rows=#grid.HINTS
  for i,v in ipairs(grid.HINTS) do _HINTS[i]=v _HINTS[i+rows]={} end -- double up the hints
  for y=1,rows do
    for x,h in ipairs(_HINTS[y]) do
      _HINTS[y+rows][x] = '⇧'.._HINTS[y][x] -- add shift
    end
  end
end

local function makeUI()
  local ts,tsh=ui.textSize,ui.textSize*0.5
  deleteUI()
  makeHints()
  uielements = {}
  local screens = screen.allScreens()
  local function dist(i,w1,w2) return round((i-1)/w1*w2)+1 end
  for i,screen in ipairs(screens) do
    local sgr = getGrid(screen)
    local cell = getCellSize(screen)
    local frame = screen:frame()
    log.f('Screen #%d %s (%s) -> grid %s (%s cells)',i,screen:name(),frame.size.string,sgr.string,cell:floor().string)
    local htf = {w=550,h=150}
    htf.x = frame.x+frame.w/2-htf.w/2  htf.y = frame.y+frame.h/2-htf.h/3*2
    if fmod(sgr.h,2)==1 then htf.y=htf.y-cell.h/2 end
    local howtorect = drawing.rectangle(htf)
    howtorect:setFill(true) howtorect:setFillColor(getColor(ui.cellColor)) howtorect:setStrokeWidth(ui.cellStrokeWidth)
    local howtotext=drawing.text(htf,'    ←→↑↓:select screen\n ⇥:next win  ⇧⇥:prev win\n  space:fullscreen esc:exit')
    howtotext:setTextSize(40) howtotext:setTextColor(getColor(ui.textColor))
    howtotext:setTextFont(ui.fontName)
    local sid=screen:id()
    uielements[sid] = {left=(screen:toWest() or screen):id(),
      up=(screen:toNorth() or screen):id(),
      right=(screen:toEast() or screen):id(),
      down=(screen:toSouth() or screen):id(),
      screen=screen, frame=frame,
      howto={rect=howtorect,text=howtotext},
      hints={}}
    -- create the ui for cells
    local hintsw,hintsh = #_HINTS[1],#_HINTS
    for hx=min(hintsw,sgr.w),1,-1 do
      local cx,cx2 = hx,hx+1
      -- allow for grid width > # available hint columns
      if sgr.w>hintsw then cx=dist(cx,hintsw,sgr.w) cx2=dist(cx2,hintsw,sgr.w) end
      local x,x2 = frame.x+cell.w*(cx-1),frame.x+cell.w*(cx2-1)
      for hy=min(hintsh,sgr.h),1,-1 do
        local cy,cy2 = hy,hy+1
        -- allow for grid heigth > # available hint rows
        if sgr.h>hintsh then cy=dist(cy,hintsh,sgr.h) cy2=dist(cy2,hintsh,sgr.h) end
        local y,y2 = frame.y+cell.h*(cy-1),frame.y+cell.h*(cy2-1)
        local elem = geom.new{x=x,y=y,x2=x2,y2=y2}
        local rect = drawing.rectangle(elem)
        rect:setFill(true) rect:setFillColor(getColor(ui.cellColor))
        rect:setStroke(true) rect:setStrokeColor(getColor(ui.cellStrokeColor)) rect:setStrokeWidth(ui.cellStrokeWidth)
        elem.rect = rect
        elem.hint = _HINTS[_HINTROWS[min(sgr.h,hintsh)][hy]][hx]
        local tw=ts*ulen(elem.hint)
        local text=drawing.text({x=x+(x2-x)/2-tw/2,y=y+(y2-y)/2-tsh,w=tw,h=ts*1.1},elem.hint)
        text:setTextSize(ts) text:setTextFont(ui.fontName)
        text:setTextColor(getColor(ui.textColor))
        elem.text=text
        log.vf('[%d] %s %.0f,%.0f>%.0f,%.0f',i,elem.hint,elem.x,elem.y,elem.x2,elem.y2)
        tinsert(uielements[sid].hints,elem)
      end
    end
  end
end


local function showGrid(id)
  if not id or not uielements[id] then log.e('Cannot get current screen, aborting') return end
  local elems = uielements[id].hints
  for _,e in ipairs(elems) do e.rect:show() e.text:show() end
  if ui.showExtraKeys then uielements[id].howto.rect:show() uielements[id].howto.text:show() end
end
local function hideGrid(id)
  if not id or not uielements or not uielements[id] then --[[log.e('Cannot obtain current screen') --]] return end
  uielements[id].howto.rect:hide() uielements[id].howto.text:hide()
  local elems = uielements[id].hints
  for _,e in pairs(elems) do e.rect:hide() e.text:hide() end
end

local initialized, showing, currentScreen, exitCallback
local currentWindow, currentWindowIndex, allWindows, cycledWindows, focusedWindow, reorderIndex, cycling, highlight
local function startCycling()
  allWindows=window.orderedWindows() cycledWindows={} reorderIndex=1 focusedWindow=currentWindow
  local cid=currentWindow:id()
  for i,w in ipairs(allWindows) do
    if w:id()==cid then currentWindowIndex=i break end
  end
  --[[focus the desktop so the windows can :raise
  local finder=application.find'Finder'
  for _,w in ipairs(finder:allWindows()) do
    if w:role()=='AXScrollArea' then w:focus() return end
  end--]]
end

local function _start()
  if initialized then return end
  screen.watcher.new(deleteUI):start()
  require'hs.spaces'.watcher.new(grid.hide):start()
  resizing=newmodal()
  local function showHighlight()
    if highlight then highlight:delete() end
    highlight = drawing.rectangle(currentWindow:frame())
    highlight:setFill(true) highlight:setFillColor(getColor(cycling and ui.cyclingHighlightColor or ui.highlightColor)) highlight:setStroke(true)
    highlight:setStrokeColor(getColor(cycling and ui.cyclingHighlightStrokeColor or ui.highlightStrokeColor)) highlight:setStrokeWidth(ui.highlightStrokeWidth)
    highlight:show()
  end
  function resizing:entered()
    if showing then return end
    if window.layout._hasActiveInstances then window.layout.pauseAllInstances() end
    --    currentWindow = window.frontmostWindow()
    if not currentWindow then log.w('Cannot get current window, aborting') resizing:exit() return end
    log.df('Start moving %s [%s]',currentWindow:subrole(),currentWindow:application():title())
    if currentWindow:isFullScreen() then currentWindow:setFullScreen(false) --[[resizing:exit()--]] end
    -- disallow resizing fullscreen windows as it doesn't really make much sense
    -- so fullscreen window gets toggled back first
    currentScreen = (currentWindow:screen() or screen.mainScreen()):id()
    showHighlight()
    if not uielements then makeUI() end
    showGrid(currentScreen)
    showing = true
  end
  local selectedElem
  local function clearSelection()
    if selectedElem then
      selectedElem.rect:setFillColor(getColor(ui.cellColor))
      selectedElem = nil
    end
  end
  function resizing:exited()
    if not showing then return true end
    if highlight then highlight:delete() highlight=nil end
    clearSelection()
    if cycling and #allWindows>0 then
      -- will STILL somewhat mess up window zorder, because orderedWindows~=most recently focused windows; but oh well
      for i=reorderIndex,1,-1 do if cycledWindows[i] then allWindows[i]:focus() timer.usleep(80000) end end
      if focusedWindow then focusedWindow:focus() end
    end
    hideGrid(currentScreen)
    showing = nil
    if window.layout._hasActiveInstances then window.layout.resumeAllInstances() end
    if type(exitCallback)=='function' then return exitCallback() end
  end
  local function cycle(d)
    if not cycling then cycling=true startCycling() currentWindowIndex=currentWindowIndex-d end
    clearSelection() hideGrid(currentScreen)
    local startIndex=currentWindowIndex
    repeat
      currentWindowIndex=(currentWindowIndex+d) % #allWindows
      if currentWindowIndex==0 then currentWindowIndex=#allWindows end
      currentWindow = allWindows[currentWindowIndex]
    until currentWindowIndex==startIndex or currentWindow:subrole()=='AXStandardWindow'
    reorderIndex=max(reorderIndex,currentWindowIndex)
    currentWindow:focus()
    cycledWindows[currentWindowIndex]=true
    currentScreen=(currentWindow:screen() or screen.mainScreen()):id()
    showHighlight()
    showGrid(currentScreen)
  end
  resizing:bind({},'tab',function()cycle(1)end)
  resizing:bind({'shift'},'tab',function()cycle(-1)end)
  resizing:bind({},'delete',clearSelection)
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
    local elem
    for _,hint in ipairs(uielements[currentScreen].hints) do
      if hint.hint==c then elem=hint break end
    end
    --    local elem = fnutils.find(uielements[currentScreen].hints,function(e)return e.hint==c end)
    if not elem then return end
    if not selectedElem then
      selectedElem = elem
      elem.rect:setFillColor(getColor(ui.selectedColor))
    else
      local x1,x2,y1,y2
      x1,x2 = min(selectedElem.x,elem.x)+margins.w,max(selectedElem.x,elem.x)-margins.h
      y1,y2 = min(selectedElem.y,elem.y)+margins.w,max(selectedElem.y,elem.y)-margins.h
      local frame={x=x1,y=y1,w=x2-x1+elem.w,h=y2-y1+elem.h}
      currentWindow:setFrameInScreenBounds(frame)
      log.f('move to %.0f,%.0f[%.0fx%.0f]',frame.x,frame.y,frame.w,frame.h)
      clearSelection()
      if cycling then cycle(1) else resizing:exit() end
    end
  end
  makeHints()
  for _,row in ipairs(_HINTS) do
    for _,c in ipairs(row) do
      local l=ssub(c,-3,-3)=='f' and -3 or (ssub(c,-2,-2)=='f' and -2 or -1)
      local mod,key=ssub(c,-20,l-1),ssub(c,l)
      resizing:bind({mod},key,function()hintPressed(c) end)
    end
  end
  --TODO perhaps disable all other keyboard input?
  initialized=true
end

function grid.show(cb,stay)
  if showing then return end
  if type(cb)=='boolean' then stay=cb cb=nil end
  exitCallback=cb
  if not initialized then _start() end
  cycling=stay and true or nil
  -- there will be some inconsistency when cycling (focusedWindow~=frontmost), but oh well
  currentWindowIndex,currentWindow=1,window.frontmostWindow()
  if cycling then startCycling() end
  --  else resizing:exit() end
  resizing:enter()
end

function grid.hide()
  if showing then resizing:exit() end
end

function grid.toggleShow(cb,stay)
  if showing then grid.hide() else grid.show(stay,cb) end
end



-- Legacy stuff below, deprecated
setmetatable(grid,{
  __index = function(t,k)
    if k=='GRIDWIDTH' then return gridSizes[true].w
    elseif k=='GRIDHEIGHT' then return gridSizes[true].h
    elseif k=='MARGINX' then return margins.w
    elseif k=='MARGINY' then return margins.h
    else return rawget(t,k) end
  end,
  __newindex = function(t,k,v)
    if k=='GRIDWIDTH' then grid.setGrid{w=v,h=gridSizes[true].h}
    elseif k=='GRIDHEIGHT' then grid.setGrid{w=gridSizes[true].w,h=v}
    elseif k=='MARGINX' then grid.setMargins{v,margins.h}
    elseif k=='MARGINY' then grid.setMargins{margins.w,v}
    else rawset(t,k,v) end
  end,
}) -- metatable for legacy variables

-- deprecate these too
function grid.adjustNumberOfRows(delta)
  grid.GRIDHEIGHT = max(1, grid.GRIDHEIGHT + delta)
  require'hs.fnutils'.map(window.visibleWindows(), grid.snap)
end

function grid.adjustNumberOfColumns(delta)
  grid.GRIDWIDTH = max(1, grid.GRIDWIDTH + delta)
  require'hs.fnutils'.map(window.visibleWindows(), grid.snap)
end
-- these are now doubly-deprecated :)
grid.adjustHeight = grid.adjustNumberOfRows
grid.adjustWidth = grid.adjustNumberOfColumns


return grid
