--- === hs.region ===
---
--- A region represents an area where you can dock windows
---
--- Usage: local region = require "hs.region"
local region = {}

local alert = require "hs.alert"

--- hs.region.new(x, y, w, h) -> regionObject
--- Constructor
--- Creates a new region
---
--- Parameters:
---  * x - region's topleft position
---  * y - region's topleft position
---  * w - region's width
---  * h - region's height
---
--- Returns:
---  * An `hs.region` object, or nil if an error occurred
function region.new(x, y, w, h)
    if not (x and y and w and h) then
      alert.show("Bad coordinate arguments passed to region constructor")
      return nil
    end
    out = setmetatable({}, { __index = region })
    out.x = x
    out.y = y
    out.w = w
    out.h = h
    out.windows = {}
    return out
end

function resizeWindow(r, win)
  local frame = {}

  frame.x = r.x
  frame.y = r.y
  frame.w = r.w
  frame.h = r.h
  win:setFrame(frame)
end

--- hs.region:addWindow(win)
--- Method
--- * Applies the window's frame to the region while also adding it to the stack
---
--- Parameters:
---  * win - `hs.window` object
function region:addWindow(win)
  local hasWindow = false
  for _, w in pairs(self.windows) do
    if w == win then
      hasWindow = true
      break
    end
  end
  if not hasWindow then
    table.insert(self.windows, win)
  end
  resizeWindow(self, win)
  self.currentWindow = win
end

function region:removeWindow(win)
  local index = -1
  for i, w in ipairs(self.windows) do
    if win == w then index = i end
  end
  if index ~= -1 then
    table.remove(self.windows, index)
  end
end

function region:getCenterPoint()
  return { self.x + self.w / 2 , self.y + self.h / 2 }
end

--- hs.region:move(x, y)
--- Method
--- * Move the region in x or y. Also moves any windows on the stack.
---
--- Parameters:
---  * x - Optional x position to move the region to
---  * y - Optional y position to move the region to
function region:move(x, y)
  if x then
    self.x = x
  end
  if y then
    self.y = y
  end
  if x or y and self.windows then
    for i, w in ipairs(self.windows) do
      resizeWindow(self, w)
    end
  end
end

--- hs.region:resize(w, h)
--- Method
--- * Increase the size of the region. Also resizes any windows on the stack.
---
--- Parameters:
---  * w - Optional width to expand the region
---  * h - Optional height to expand the region
function region:resize(w, h)
  if w then
    self.w = w
  end
  if h then
    self.h = h
  end
  if w or h and self.windows then
    for i, w in ipairs(self.windows) do
      resizeWindow(self, w)
    end
  end
end

return region
