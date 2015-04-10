--- === hs.region ===
---
--- An area on the screen where windows can be positioned
---
--- Usage: local region = require "hs.region"
---
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
---  * screen - An optional `hs.screen` object this region will be on, if left
---  empty, will default to `hs.screen.mainScreen()`
---
--- Returns:
---  * An `hs.region` object, or nil if an error occurred
function region.new(x, y, w, h, screen)
    if not x or not y or not w or not h then
      alert.show("Bad coordinate arguments passed to region constructor")
      return nil
    end
    region.x = x
    region.y = y
    region.w = w
    region.h = h
    region.screen = screen or hs.screen.mainScreen()
    region.windows = {}
    return region
end

--- hs.region:getScreen() -> screenObject
--- Method
--- * Gets the screen this region is on
---
--- Returns:
---  * An `hs.screen` object
function region:getScreen()
    return self.screen
end

--- hs.region:applyWindow(win)
--- Method
--- * Applies the window's frame to the region while also adding it to the stack
---
--- Parameters:
---  * win - `hs.window` object
function region:applyWindow(win)
  local hasWindow = false
  for i, w in ipairs(self.windows) do
    if w == win then
      hasWindow = true
      break
    end
  end
  if not hasWindow then
    table.insert(self.windows, win)
  end
  resizeWindow(self, win)
end

function resizeWindow(region, win)
  local frame = {}

  frame.x = region.x
  frame.y = region.y
  frame.w = region.w
  frame.h = region.h
  win:setFrame(frame)
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
