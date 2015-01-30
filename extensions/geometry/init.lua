--- === hs.geometry ===
---
--- Mathematical functions

local geometry = require "hs.geometry.internal"

--- hs.geometry.rotateCCW(point, aroundpoint, ntimes = 1) -> point
--- Function
--- Rotates a point around another point N times.
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
--- Returns hypotenuse of a line defined from 0,0 to point.
function geometry.hypot(p)
  return math.sqrt(p.x * p.x + p.y * p.y)
end

--- hs.geometry.rect(x, y, w, h) -> rect
--- Constructor
--- Convenience function for creating a rect-table.
function geometry.rect(x, y, w, h)
  return {x = x, y = y, w = w, h = h}
end

--- hs.geometry.point(x, y) -> point
--- Constructor
--- Convenience function for creating a point-table.
function geometry.point(x, y)
  return {x = x, y = y}
end

--- hs.geometry.size(w, h) -> size
--- Constructor
--- Convenience function for creating a size-table.
function geometry.size(w, h)
  return {w = w, h = h}
end

--- hs.geometry.isPointInRect(point, rect) -> bool
--- Function
--- Tests whether a point falls inside a rect
---
--- Parameters:
---  * point - A table containing x and y co-ordinates
---  * rect - A table containing x and y co-ordinates, and w(idth) and h(eight) values
---
--- Returns:
---  * True if the point falls inside the rect, otherwise false
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
