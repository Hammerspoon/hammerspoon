--- === hs.grille ===
---
--- A module for moving/resizing your windows along a virtual grid (or more),
--- using a fluent interface (see Usage below).
---
--- hs.grille was based on hs.sd.grid and hs.bg.grid modules, but went through
--- significant modifications to suit my workflows. For example, it allows one to use multiple grids
--- at the same time and uses a fluent interface, so the intentions are more readable.
---
--- hs.grille uses hs.window.fluent and one can use all the commands that hs.window.fluent supports.
---
--- The grid is an partition of your screen; by default it is 3x3, i.e. 3 cells wide by 3 cells tall.
---
--- Grid cells are just a table with keys: x, y, w, h
---
--- For a grid of 2x2:
---
--- * a cell {x=0, y=0, w=1, h=1} will be in the upper-left corner
--- * a cell {x=1, y=0, w=1, h=1} will be in the upper-right corner
--- * and so on...
---
--- Usage:
---   local grille = require "hs.grille"
---
---   -- default grid is 3x3
---   local grid33 = grille.new(3, 3)
---   local grid42 = grille.new(4, 2)
---
---   local cmdalt  = {"cmd", "alt"}
---   local scmdalt  = {"cmd", "alt", "shift"}
---   local ccmdalt = {"ctrl", "cmd", "alt"}
---
---    == the code below needs to be reworked ==
---    -- move windows as per grid segments
---    hotkey.bind(cmdalt, 'LEFT', grid33:focused():left():move())
---    hotkey.bind(cmdalt, 'RIGHT', grid33:focused():right():move())
---
---    -- resize windows to grid
---    hotkey.bind(scmdalt, 'LEFT', grid33:focused():thinner():resize())
---    hotkey.bind(scmdalt, 'RIGHT', grid33:focused():wider():resize())
---
---    -- on a 3x3 grid make a 2x3 window and place it on left
---    hotkey.bind(cmdalt, 'h', grid33:focused():wide(2):tallest():leftmost():place())
---
---    -- on a 3x3 grid make a 1x3 window and place it rightmost
---    hotkey.bind(cmdalt, 'j', grid33:focused():tallest():rightmost():place())
---
---  defaults are:
---    1 cell wide, 1 cell tall, top-left corner, focused window
---
---  One must start with grid:focused() or grid:window('title') and end with a command move(),
---  place(), resize(), or act() (they are all synonyms for the same action). This chain of
---  command will return a function that one can pass to hotkey.bind.
---
--- @author    Nikola Knezevic
--- @copyright 2014
---
local grille = {
  _VERSION     = '0.5.0',
  _DESCRIPTION = 'A module for moving/resizing windows on a grid, using a fluent interface. This module supports multiple grids at the same time.',
}

local window = require "hs.window"
local fluent = require "hs.window.fluent"

local function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end

-- class that deals with coordinate transformations
local GrilleCoordTrans = {}

function GrilleCoordTrans.new(_width, _height, _xmargin, _ymargin)
  local self = {
    -- The number of vertical cells of the grid (default 3)
    height = math.max(_height or 3, 1),

    -- The number of horizontal cells of the grid
    width = math.max(_width or 3, 1),

    -- The margin between each window horizontally.
    xmargin = math.max(_xmargin or 0, 0),

    -- The margin between each window vertically.
    ymargin = math.max(_ymargin or 0, 0),
  }
  setmetatable(self, { __index = GrilleCoordTrans })
  return self
end

--- hs.grille:get(win)
--- Function
--- Gets the cell this window is on
function GrilleCoordTrans:get(win, _screen)
  local winframe = win:frame()
  local screen = _screen or win:screen()
  local screenrect = screen:frame()
  local screenwidth = screenrect.w / self.width
  local screenheight = screenrect.h / self.height
  return {
    x = round((winframe.x - screenrect.x) / screenwidth),
    y = round((winframe.y - screenrect.y) / screenheight),
    w = math.max(1, round(winframe.w / screenwidth)),
    h = math.max(1, round(winframe.h / screenheight)),
    screenw = self.width,
    screenh = self.height,
  }
end

--- hs.grille:set(win, grid, screen)
--- Function
--- Sets the cell this window should be on
function GrilleCoordTrans:set(win, screen, f)
  local screenrect = screen:frame()
  local screenwidth = screenrect.w / self.width
  local screenheight = screenrect.h / self.height
  local newframe = {
    x = (f.x * screenwidth) + screenrect.x,
    y = (f.y * screenheight) + screenrect.y,
    w = f.w * screenwidth,
    h = f.h * screenheight,
  }

  newframe.x = newframe.x + self.xmargin
  newframe.y = newframe.y + self.ymargin
  newframe.w = newframe.w - (self.xmargin * 2)
  newframe.h = newframe.h - (self.ymargin * 2)

  win:setFrame(newframe)
end

-- class table
local Grille = {}

local function grille_focused(self)
  return fluent.focused(self.ct)
end

local function grille_window(self, title)
  return fluent.window(title or '', self.ct)
end

--- hs.grille.new(width, height) -> window.fluent object
--- Function
--- Creates a new window.fluent object that uses coordinate tranformations to place the windows on a grid with given width and height. Default width and height are 3.
---
--- Parameters:
---  * width - width of the grid
---  * height - height of the grid
---
--- Returns:
---  * A window.fluent object that could be used for further manipulation
---
--- Notes:
---  * See the documentation for hs.window.fluent module
function grille.new(width, height, xmargin, ymargin)
  local ct = GrilleCoordTrans.new(width, height, xmargin, ymargin)
  local self = fluent.new(ct)
  self.focused = grille_focused
  self.window = grille_window
  print(string.format("New grille ready, width = %d, height =%d", width, height))
  return self
end

--- hs.grille:fits_cell(win) -> boolean
--- Method
--- Returns whether a window fits cells (that is, it doesn't need readjustments)
---
--- Parameters:
---  * win - hs.window object
---
--- Returns:
---  * true is the window fits the current grid
function Grille:fits_cell(win)
  local winframe = win:frame()
  local screenrect = win:screen():frame()
  local screenwidth = screenrect.w / self.width
  local screenheight = screenrect.h / self.height
  return ((winframe.x - screenrect.x) % screenwidth == 0)
         and ((winframe.y - screenrect.y) % screenheight == 0)
end

return grille
