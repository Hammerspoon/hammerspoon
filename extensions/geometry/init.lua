--- === hs.geometry ===
---
--- Utility functions for math operations and constructing geometric objects (rects/points/etc)

local geometry = require "hs.geometry.internal"

--- hs.geometry.rotateCCW(point, aroundpoint, ntimes = 1) -> point
--- Function
--- Rotates a point around another point N times
---
--- Parameters:
---  * point - A point-table containing the point to be rotated
---  * aroundpoint - A point-table to rotate `point` around
---  * ntimes - A number containing the number of times to rotate
---
--- Returns:
---  * A point-table containing the new location of the rotated point
function geometry.rotateCCW(point, aroundpoint, ntimes)
  local p = {x = point.x, y = point.y}
  for i = 1, ntimes or 1 do
    local px = p.x
    p.x = (aroundpoint.x - (p.y - aroundpoint.y))
    p.y = (aroundpoint.y + (px - aroundpoint.x))
  end
  return p
end

--- hs.geometry.hypot(point) -> number
--- Function
--- Returns hypotenuse of a line defined from 0,0 to point
---
--- Parameters:
---  * point - A point-table containing the end of the line (its start being 0,0)
---
--- Returns:
---  * A number containing the hypotenuse
function geometry.hypot(p)
  return math.sqrt(p.x * p.x + p.y * p.y)
end

--- hs.geometry.rect(x, y, w, h) -> rect
--- Constructor
--- Convenience function for creating a rect-table
---
--- Parameters:
---  * x - A number containing the horizontal co-ordinate of the top-left point of the rect
---  * y - A number containing the vertical co-ordinate of the top-left point of the rect
---  * w - A number containing the width of the rect
---  * h - A number containing the height of the rect
---
--- Returns:
---  * A rect-table
function geometry.rect(x, y, w, h)
  return {x = x, y = y, w = w, h = h}
end

--- hs.geometry.point(x, y) -> point
--- Constructor
--- Convenience function for creating a point-table
---
--- Parameters:
---  * x - A number containing the horizontal co-ordinate of the point
---  * y - A number containing the vertical co-ordinate of the point
---
--- Returns:
---  * A point-table
function geometry.point(x, y)
  return {x = x, y = y}
end

--- hs.geometry.size(w, h) -> size
--- Constructor
--- Convenience function for creating a size-table
---
--- Parameters:
---  * w - A number containing a width
---  * h - A number containing a height
---
--- Returns:
---  * A size-table
function geometry.size(w, h)
  return {w = w, h = h}
end

--- hs.geometry.isPointInRect(point, rect) -> bool
--- Function
--- Determines whether a point falls inside a rect
---
--- Parameters:
---  * point - A point-table describing a point in space
---  * rect - A rect-table describing an area of space
---
--- Returns:
---  * A boolean, True if the point falls inside the rect, otherwise false
function geometry.isPointInRect(point, rect)
    if (point["x"] >= rect["x"] and
        point["y"] >= rect["y"] and
        point["x"] < (rect["x"] + rect["w"]) and
        point["y"] < (rect["y"] + rect["h"])) then
        return true
    end
    return false
end

return geometry
