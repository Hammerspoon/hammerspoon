--- === hs.geometry ===
---
--- Utility object to represent points, sizes and rects in a bidimensional plane
---
--- An hs.geometry object can be:
---  * a *point*, or vector2, with `x` and `y` fields for its coordinates
---  * a *size* with `w` and `h` fields for width and height respectively
---  * a *rect*, which has both a point component for one of its corners, and a size component - so it has all 4 fields
---
--- You can create these objects in many different ways, via `my_obj=hs.geometry.new(...)` or simply `my_obj=hs.geometry(...)`
--- by passing any of the following:
---  * 4 parameters `X,Y,W,H` for the respective fields - W and H, or X and Y, can be `nil`:
---    * `hs.geometry(X,Y)` creates a point
---    * `hs.geometry(nil,nil,W,H)` creates a size
---    * `hs.geometry(X,Y,W,H)` creates a rect given its width and height from a corner
---  * a table `{X,Y}` creates a point
---  * a table `{X,Y,W,H}` creates a rect
---  * a table `{x=X,y=Y,w=W,h=H}` creates a rect, or if you omit X and Y, or W and H, creates a size or a point respectively
---  * a table `{x1=X1,y1=Y1,x2=X2,y2=Y2}` creates a rect, where X1,Y1 and X2,Y2 are the coordinates of opposite corners
---  * a string:
---    * `"X Y"` or `"X,Y"` creates a point
---    * `"WxH"` or `"W*H"` creates a size
---    * `"X Y WxH"` or `"X,Y/W*H"` (or variations thereof) creates a rect given its width and height from a corner
---    * `"X1 Y1 > X2 Y2"` or `"X1,Y1,X2,Y2"` (or variations thereof) creates a rect given two opposite corners
---
--- You can use any of these anywhere an hs.geometry object is expected in Hammerspoon; the constructor will be called for you.

-- remove copy-on-new
--  * another `hs.geometry` object - creates a copy of that object

--TODO allow segments? (like rects, but no norm())

local rawget,rawset,type,pairs,tonumber,sqrt=rawget,rawset,type,pairs,tonumber,math.sqrt
local min,max,atan,smatch,sformat=math.min,math.max,math.atan,string.match,string.format
local getmetatable,setmetatable=getmetatable,setmetatable

local geometry = {}--require "hs.geometry.internal"

local ws=' *'
local sepout=ws..'([ ,>/])'..ws
local sepin=ws..'([ x*,])'..ws
local number='(%-?%d*%.?%d*)'
local function parse(s)
  local x,y,w,h
  local sept,n3,sep2,n4
  local n1,sep1,n2,i = smatch(s,number..sepin..number..'()')
  if i then sept,n3,sep2,n4 = smatch(s,sepout..number..sepin..number,i) end
  if sep1=='x' or sep1=='*' then --it's a size
    w=tonumber(n1) h=tonumber(n2)
    if not w then error('Cannot parse width',3) end
    if not h then error('Cannot parse height',3) end
  else
    x=tonumber(n1) y=tonumber(n2)
    if not x then error('Cannot parse x coord',3) end
    if not y then error('Cannot parse y coord',3) end
    if sept=='>' or sep2==' ' or sep2==',' then --it's a rectx2y2
      w=tonumber(n3)-x h=tonumber(n4)-y
      if not w then error('Cannot parse x2 coord',3) end
      if not h then error('Cannot parse y2 coord',3) end
    elseif sep2 then --it's a rectsize
      w=tonumber(n3) h=tonumber(n4)
      if not w then error('Cannot parse width',3) end
      if not h then error('Cannot parse height',3) end
    end
  end
  return x,y,w,h
end

local function gettype(t)
  if t._x and t._y then
    if t._w and t._h then return 'rect' else return 'point' end
  elseif t._w and t._h then return 'size' end
end
local function norm(t)
  if t._x and t._w and t._w<0 then t._x=t._x+t._w t._w=-t._w end
  if t._y and t._h and t._h<0 then t._y=t._y+t._h t._h=-t._h end
end

local function new(x,y,w,h)
  if getmetatable(x)==geometry then return x end -- disable copy-on-new
  if type(x)=='string' then
    x,y,w,h=parse(x)
  elseif type(x)=='table' then
    if x[1] then x,y,w,h=x[1],x[2],x[3],x[4]
    else
      local t=x
      x,y=t.x or t.x1,t.y or t.y1
      w,h=t.w or t.x2-x,t.h or t.y2-y
    end
  end
  local t={_x=x,_y=y,_w=w,_h=h}
  for k,v in pairs(t) do if type(v)~='number' then t[k]=nil end end
  norm(t)
  if not gettype(t) then error('Cannot create geometry object, wrong arguments',2) end
  return setmetatable(t,geometry)
end
--- hs.geometry.new(...) -> hs.geometry object
--- Constructor
--- Creates a new hs.geometry object
---
--- Parameters: see the module description at the top
---
--- Returns:
---  * a newly created hs.geometry object
geometry.new=new
--- hs.geometry.copy(geom) -> hs.geometry object
--- Constructor
--- Creates a copy of an hs.geometry object
---
--- Parameters:
---  * geom - an hs.geometry object to copy
---
--- Returns:
---  * a newly created copy of the hs.geometry object
function geometry.copy(o)
  return new(o.x,o.y,o.w,o.h)
end

function geometry.__tostring(t)
  local typ=gettype(t)
  local fmt
  if typ=='rect' then fmt=t.x..','..t.y..','..t.w..','..t.h
  elseif typ=='point' then fmt=t.x..','..t.y
  elseif typ=='size' then fmt=t.w..','..t.h end
  return sformat('hs.geometry.%s(%s)',typ,fmt)
end

-- getters and setters
--- hs.geometry.x
--- Field
--- The x coordinate for this point or rect's corner; changing it will move the rect but keep the same width and height

--- hs.geometry.y
--- Field
--- The y coordinate for this point or rect's corner; changing it will move the rect but keep the same width and height

--- hs.geometry.x1
--- Field
--- Alias for `x`

--- hs.geometry.y1
--- Field
--- Alias for `y`
function geometry.getx(t) return t._x end
function geometry.gety(t) return t._y end
geometry.getx1=geometry.getx
geometry.gety1=geometry.gety
function geometry.getw(t) return t._w end
function geometry.geth(t) return t._h end
function geometry.getx2(t) return t._x+(t._w or 0) end
function geometry.gety2(t) return t._y+(t._h or 0) end

function geometry.setx(t,v) t._x=tonumber(v) or error('number expected',3) end
function geometry.sety(t,v) t._y=tonumber(v) or error('number expected',3) end
geometry.setx1=geometry.setx
geometry.sety1=geometry.sety

--- hs.geometry.xy
--- Field
--- The point component for this hs.geometry object; setting this to a new point will move the rect but keep the same width and height

--- hs.geometry.topleft
--- Field
--- Alias for `xy`
function geometry.getxy(t) return new(t._x,t._y) end
function geometry.setxy(t,p) p=new(p) t._x=p.x t._y=p.y end
geometry.gettopleft=geometry.getxy
geometry.settopleft=geometry.setxy

--- hs.geometry.w
--- Field
--- The width of this rect or size; changing it will keep the rect's x,y corner constant

--- hs.geometry.h
--- Field
--- The height of this rect or size; changing it will keep the rect's x,y corner constant
function geometry.setw(t,v)
  t._w=max(tonumber(v) or error('number expected',3),0) -- disallow negative w,h instead of flipping the rect
  --  norm(t)
end
function geometry.seth(t,v)
  t._h=max(tonumber(v) or error('number expected',3),0)
  --  norm(t)
end
--- hs.geometry.x2
--- Field
--- The x coordinate for the second corner of this rect; changing it will affect the rect's width

--- hs.geometry.y2
--- Field
--- The y coordinate for the second corner of this rect; changing it will affect the rect's height
function geometry.setx2(t,v)
  if not t.x then error('not a rect',3) end
  t._w=(tonumber(v) or error('number expected',3))-t._x
  norm(t)
end
function geometry.sety2(t,v)
  if not t.y then error('not a rect',3) end
  t._h=(tonumber(v) or error('number expected',3))-t._y
  norm(t)
end

--- hs.geometry.wh
--- Field
--- The size component for this hs.geometry object; setting this to a new size will keep the rect's x,y corner constant

--- hs.geometry.size
--- Field
--- Alias for `wh`
function geometry.getwh(t) return new(nil,nil,t._w,t._h)end
function geometry.setwh(t,s) s=new(s) t._w=s.w t._h=s.h end
geometry.getsize=geometry.getwh
geometry.setsize=geometry.setwh

--- hs.geometry.center
--- Field
--- A point representing the geometric center of this rect or the midpoint of this vector2; changing it will move the rect/vector accordingly
function geometry.getcenter(t)
  return new((t.x or 0)+(t.w or 0)/2,(t.y or 0)+(t.h or 0)/2)
end
function geometry.setcenter(t,...)
  local c,nc=geometry.getcenter(t),new(...)
  if not nc.x or not nc.y then error('not a point',3) end
  if t.x then t.x=t.x+nc.x-c.x end
  if t.y then t.y=t.y+nc.y-c.y end
end
--- hs.geometry.length
--- Field
--- A number representing the length of the diagonal of this rect, or the length of this vector2; changing it will scale the rect/vector - see `hs.geometry:scale()`
function geometry.getlength(t)
  if t.w and t.h then t=new(t.w-(t.x or 0),t.h-(t.y or 0)) end
  return sqrt(t.x^2+t.y^2)
end
function geometry.setlength(t,l)
  l=tonumber(l) or error('number expected',3)
  local ol=geometry.getlength(t)
  if ol>0 then
    local f=sqrt(l/ol)
    return geometry.scale(t,f,f)
  end
end
--- hs.geometry.area
--- Field
--- A number representing the area of this rect or size; changing it will scale the rect/size - see `hs.geometry:scale()`
function geometry.getarea(t)
  return (t.w or 0)*(t.h or 0)
end
function geometry.setarea(t,a)
  local oa=geometry.getarea(t)
  if oa>0 then
    local f=sqrt(a/oa)
    return geometry.scale(t,f,f)
  end
end

function geometry.__index(t,k)
  local r=rawget(geometry,'get'..k)
  return r and r(t) or rawget(geometry,k)
end
function geometry.__newindex(t,k,v)
  local r=rawget(geometry,'set'..k)
  if r then r(t,v) else rawset(t,k,v) end
end

-- methods
--- hs.geometry:equals(other) -> boolean
--- Method
--- Checks if two geometry objects are equal
---
--- Parameters:
---  * other - another hs.geometry object, or a table or string or parameter list to construct one
---
--- Returns:
---  * `true` if this hs.geometry object perfectly overlaps other, `false` otherwise
function geometry.equals(t1,t2)
  return t1.x==t2.x and t1.y==t2.y and t1.w==t2.w and t1.h==t2.h
end

--- hs.geometry:move(point) -> hs.geometry object
--- Method
--- Moves this point/rect
---
--- Parameters:
---  * point - an hs.geometry object, or a table or string or parameter list to construct one, indicating the x and y displacement to apply
---
--- Returns:
---  * this hs.geometry object for method chaining
function geometry.move(t,...)
  t=new(t) local p=new(...)
  if t.x then t.x=t.x+(p.x or p.w) end
  if t.y then t.y=t.y+(p.y or p.h) end
  return t
end

--- hs.geometry:scale(size) -> hs.geometry object
--- Method
--- Scales this size/rect, *keeping its center constant*
---
--- Parameters:
---  * size - an hs.geometry object, or a table or string or parameter list to construct one, indicating the factors for scaling this rect's width and height;
---    if a number, the rect will be scaled by the same factor in both axes
---
--- Returns:
---  * this hs.geometry object for method chaining
function geometry.scale(t,s1,s2,...)
  t=new(t)
  if type(s1)=='number' and not s2 then s2=s1 end
  local s=new(s1,s2,...)
  local c=geometry.getcenter(t)
  if t.w and t.h then
    t.w=t.w*(s.w or s.x)
    t.h=t.h*(s.h or s.y)
  else
    t.x=t.x*(s.w or s.x)
    t.y=t.y*(s.h or s.y)
  end
  geometry.setcenter(t,c)
  return t
end

--- hs.geometry:normalize() -> point
--- Method
--- Normalizes this vector2
---
--- Parameters:
---  * None
---
--- Returns:
---  * this hs.geometry point for method chaining
function geometry.normalize(t)
  t=new(t)
  geometry.setlength(t,1)
  return t
end

--- hs.geometry:vector(point) -> point
--- Method
--- Returns the vector2 from this point or rect's center to another point or rect's center
---
--- Parameters:
---  * point - an hs.geometry object, or a table or string or parameter list to construct one; if a rect, uses the rect's center
---
--- Returns:
---  * an hs.geometry point
function geometry.vector(t,...)
  t=new(t) local t2=new(...)
  if gettype(t)=='rect' then t=geometry.getcenter(t) end
  if gettype(t2)=='rect' then t2=geometry.getcenter(t2) end
  return new((t.x or 0)-(t2.x or 0),(t.y or 0)-(t2.y or 0))
end

--- hs.geometry:angle() -> number
--- Method
--- Returns the angle between the positive x axis and this vector2
---
--- Parameters:
---  * None
---
--- Returns:
---  * a number represeting the angle in radians
function geometry.angle(t)
  return atan(t.y or t.h,t.x or t.w)
end

--- hs.geometry:angleTo(point) -> number
--- Method
--- Returns the angle between the positive x axis and the vector connecting this point or rect's center to another point or rect's center
---
--- Parameters:
---  * point - an hs.geometry object, or a table or string or parameter list to construct one; if a rect, uses the rect's center
---
--- Returns:
---  * a number represeting the angle in radians
function geometry.angleTo(t,...)
  return geometry.angle(geometry.vector(t,...))
end

--- hs.geometry:aspect() -> number
--- Method
--- Returns the aspect ratio of this rect or size
---
--- Parameters:
---  * None
---
--- Returns:
---  * a number represeting the aspect ratio
function geometry.aspect(t)
  return (t.w or t.x)/(t.h or t.y)
end

--- hs.geometry:distance(point) -> number
--- Method
--- Finds the distance between this point or rect's center and another point or rect's center
---
--- Parameters:
---  * point - an hs.geometry object, or a table or string or parameter list to construct one; if a rect, uses the rect's center
---
--- Returns:
---  * a number indicating the distance
function geometry.distance(t,...)
  return geometry.getlength(geometry.vector(t,...))
end

--- hs.geometry:union(rect) -> hs.geometry rect
--- Method
--- Returns the smallest rect that encloses both this rect and another rect
---
--- Parameters:
---  * rect - an hs.geometry rect, or a table or string or parameter list to construct one
---
--- Returns:
---  * a new hs.geometry rect
function geometry.union(t1,...)
  t1=new(t1) local t2=new(...)
  if gettype(t1)~='rect' or gettype(t2)~='rect' then error('cannot find union for non-rects',2) end
  return new{x=min(t1.x,t2.x),y=min(t1.y,t2.y),x2=max(t1.x2,t2.x2),y2=max(t1.y2,t2.y2)}
end

--- hs.geometry:inside(rect) -> boolean
--- Method
--- Checks if this hs.geometry object lies fully inside a given rect
---
--- Parameters:
---  * rect - an hs.geometry rect, or a table or string or parameter list to construct one
---
--- Returns:
---  * `true` if this point/rect lies fully inside the given rect, `false` otherwise
function geometry.inside(t1,...)
  t1=new(t1) local t2=new(...)
  if gettype(t1)=='size' or gettype(t2)=='size' then error('sizes have no inside',2) end
  return t1.x>=t2.x and t1.y>=t2.y and t1.x2<=t2.x2 and t1.y2<=t2.y2
end

--- hs.geometry:intersect(rect) -> hs.geometry rect
--- Method
--- Returns the intersection rect between this rect and another rect
---
--- Parameters:
---  * rect - an hs.geometry rect, or a table or string or parameter list to construct one
---
--- Returns:
---  * a new hs.geometry rect
---
--- Notes:
---  * If the two rects don't intersect, the result rect will be a "projection" of the second rect onto this rect's
---    closest edge or corner along the x or y axis; the `w` and/or `h` fields in the result rect will be 0.
function geometry.intersect(t1,...)
  t1=new(t1) local t2=new(...)
  if gettype(t1)~='rect' or gettype(t2)~='rect' then error('cannot find intersection for non-rects',2) end
  local t1x,t1y,t1x2,t1y2=t1.x,t1.y,t1.x2,t1.y2
  local t2x,t2y,t2x2,t2y2=t2.x,t2.y,t2.x2,t2.y2
  if t1x<t2x then t2x=min(t1x2,t2x) t2x2=min(t1x2,t2x2)
  else t2x=max(t1x,t2x) t2x2=max(t1x,t2x2) end
  if t1y<t2y then t2y=min(t1y2,t2y) t2y2=min(t1y2,t2y2)
  else t2y=max(t1y,t2y) t2y2=max(t1y,t2y2) end
  return new{x=t2x,y=t2y,x2=t2x2,y2=t2y2}
end

-- fun with operator overloading
geometry.__eq=geometry.equals
geometry.__len=geometry.getlength
geometry.__unm=function(t) return new(t.x and -t.x,t.y and -t.y,t.w,t.h) end
geometry.__add=function(t1,t2) -- :move or :union
  t2=new(t2)
  local tp1,tp2=gettype(t1),gettype(t2)
  if tp1=='size' or tp2=='size' then error('cannot add to a size',2)
  elseif tp1=='point' or tp2=='point' then return new(t1.x+t2.x,t1.y+t2.y,t1.w or t2.w,t1.h or t2.h)
    --  elseif tp2=='point' then return geometry.move(t1,t2)
  else return geometry.union(t1,t2) end
end
geometry.__concat=geometry.union --TODO if segments, allow here
geometry.__sub=function(t1,t2)return geometry.vector(t2,t1)end
geometry.__mul=geometry.scale
geometry.__pow=geometry.intersect
geometry.__lt=function(t1,t2)
  t2=new(t2)
  if t1.w and t1.h and t2.w and t2.h then -- rect<rect
    return geometry.getarea(t1)<geometry.getarea(t2)
  elseif t1.x and t1.y and t2.x and t2.y then
    if t2.w and t2.h then -- point<rect
      return geometry.inside(t1,t2)
    else -- point<point, treat them like vector2
      return geometry.getlength(t1)<geometry.getlength(t2)
    end
  else error('cannot compare geometry objects of different type',2) end
end


-- legacy
geometry.hypot=geometry.getlength
geometry.rectMidPoint=geometry.getcenter
geometry.intersectionRect=geometry.intersect
geometry.isPointInRect=geometry.inside

--- hs.geometry:rotateCCW(aroundpoint, ntimes) -> hs.geometry point
--- Method
--- Rotates a point around another point N times
---
--- Parameters:
---  * aroundpoint - an hs.geometry point to rotate this point around
---  * ntimes - the number of times to rotate, defaults to 1
---
--- Returns:
---  * A new hs.geometry point containing the location of the rotated point
function geometry.rotateCCW(p, ap, ntimes)
  p,ap=new(p),new(ap)
  if gettype(p)=='size' or gettype(ap)=='size' then error('cannot rotate sizes',2) end
  local r=new(p.x,p.y)
  for i=1, ntimes or 1 do
    local rx = r.x
    r.x = (ap.x - (r.y - ap.y))
    r.y = (ap.y + (rx - ap.x))
  end
  return r
end

--- hs.geometry.rect(x, y, w, h) -> hs.geometry rect
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
---  * An hs.geometry rect object
geometry.rect=new

--- hs.geometry.point(x, y) -> hs.geometry point
--- Constructor
--- Convenience function for creating a point object
---
--- Parameters:
---  * x - A number containing the horizontal co-ordinate of the point
---  * y - A number containing the vertical co-ordinate of the point
---
--- Returns:
---  * An hs.geometry point object
geometry.point=new

--- hs.geometry.size(w, h) -> hs.geometry size
--- Constructor
--- Convenience function for creating a size object
---
--- Parameters:
---  * w - A number containing a width
---  * h - A number containing a height
---
--- Returns:
---  * An hs.geometry size object
function geometry.size(w, h)
  return new(nil,nil,w,h)
end

return setmetatable(geometry,{__call=function(_,...)return new(...) end})

