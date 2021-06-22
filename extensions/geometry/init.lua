--- === hs.geometry ===
---
--- Utility object to represent points, sizes and rects in a bidimensional plane
---
--- An hs.geometry object can be:
---  * a *point*, or vector2, with `x` and `y` fields for its coordinates
---  * a *size* with `w` and `h` fields for width and height respectively
---  * a *rect*, which has both a point component for one of its corners, and a size component - so it has all 4 fields
---  * a *unit rect*, which is a rect with all fields between 0 and 1; it represents a "relative" rect within another (absolute) rect
---    (e.g. a unit rect `x=0,y=0 , w=0.5,h=0.5` is the quarter portion closest to the origin); please note that hs.geometry
---    makes no distinction internally between regular rects and unit rects; you can convert to and from as needed via the appropriate methods
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
---    * `"X Y/WxH"` or `"X,Y W*H"` (or variations thereof) creates a rect given its width and height from a corner
---    * `"X1,Y1>X2,Y2"` or `"X1 Y1 X2 Y2"` (or variations thereof) creates a rect given two opposite corners
---    * `"[X,Y WxH]"` or `"[X1,Y1 X2,Y2]"` or variations (note the square brackets) creates a unit rect where x=X/100, y=Y/100, w=W/100, h=H/100
---  * a point and a size `"X Y","WxH"` or `{x=X,y=Y},{w=W,h=H}` create a rect
---
--- You can use any of these anywhere an hs.geometry object is expected in Hammerspoon; the constructor will be called for you.

-- remove copy-on-new
--  * another `hs.geometry` object - creates a copy of that object

--TODO guard against infinites etc everywhere (constructor, length,...)
--TODO allow segments? (like rects, but no norm())

local rawget,rawset,type,pairs,ipairs,tonumber,tostring,sqrt=rawget,rawset,type,pairs,ipairs,tonumber,tostring,math.sqrt
local min,max,floor,atan,smatch,sformat=math.min,math.max,math.floor,math.atan,string.match,string.format
local getmetatable,setmetatable=getmetatable,setmetatable

local geometry = {}

--- hs.geometry:type() -> string
--- Method
--- Returns the type of an hs.geometry object
---
--- Parameters:
---  * None
---
--- Returns:
---  * a string describing the type of this hs.geometry object, i.e. 'point', 'size', 'rect' or 'unitrect'; `nil` if not a valid object
local function gettype(t)
  if t._x and t._y then
    if t._w and t._h then
      for _,k in ipairs{'_x','_y','_w','_h'} do
        if t[k]>1.0000000000001 or t[k]<-0.0000000000001 then return 'rect' end
      end
      return 'unitrect'
    else return 'point' end
  elseif t._w and t._h then return 'size' end
end
geometry.type=gettype
local function isRect(t) local typ=gettype(t) return typ=='rect' or typ=='unitrect' end

local function norm(t)
  if t._x and t._w and t._w<0 then t._x=t._x+t._w t._w=-t._w end
  if t._y and t._h and t._h<0 then t._y=t._y+t._h t._h=-t._h end
end

-- constructor stuff
local function parse(s)
  local ws=' *'
  local outeropen=ws..'(%[?)'..ws
  local outerclose=ws..'(%]?)'
  local sepout=ws..'([ ,>/|])'..ws
  local sepin=ws..'([ x*,])'..ws
  local number='(%-?%d*%.?%d*)'
  local x,y,w,h
  local sept,n3,sep2,n4,close
  local open,n1,sep1,n2,i = smatch(s,outeropen..number..sepin..number..'()')
  if i then sept,n3,sep2,n4,close = smatch(s,sepout..number..sepin..number..outerclose,i) end
  if open and #open==0 then open=nil end
  if close and #close==0 then close=nil end
  if (not open)~=(not close) then error('Mismatched brackets or missing element',3) end
  if sep1=='x' or sep1=='*' then --it's a size
    w=tonumber(n1) h=tonumber(n2)
    if not w then error('Cannot parse width',3) end
    if not h then error('Cannot parse height',3) end
  else
    x=tonumber(n1) y=tonumber(n2)
    if not x then error('Cannot parse x coord',3) end
    if not y then error('Cannot parse y coord',3) end
    if sept=='>' or sep2==' ' or sep2==',' then --it's a rectx2y2
      w=tonumber(n3) h=tonumber(n4)
      if not w then error('Cannot parse x2 coord',3) end
      if not h then error('Cannot parse y2 coord',3) end
      w=w-x h=h-y
    elseif sep2 then --it's a rectsize
      w=tonumber(n3) h=tonumber(n4)
      if not w then error('Cannot parse width',3) end
      if not h then error('Cannot parse height',3) end
    end
  end
  if open then
    if not x or not y or not w or not h then error('Missing element',3)
    else x,y,w,h=x/100,y/100,w/100,h/100 end
  end
  return x,y,w,h
end

local function parsearg(a)
  if type(a)=='string' then return parse(a)
  elseif type(a)=='table' then
    local x,y,w,h
    if a[1] then x,y,w,h=a[1],a[2],a[3],a[4]
    else
      x,y=a.x or a.x1,a.y or a.y1
      w,h=a.w or (a.x2 and a.x2-(x or 0)),a.h or (a.y2 and a.y2-(y or 0))
    end
    return x,y,w,h
  end
end
local function maketable(t,x,y,w,h)
  local nt={_x=t._x or x,_y=t._y or y,_w=t._w or w,_h=t._h or h}
  for k,v in pairs(nt) do if type(v)~='number' then nt[k]=nil end end
  return nt
end

local function new(x,y,w,h)
  if y==nil and getmetatable(x)==geometry then return x end -- disable copy-on-new
  local t=maketable({},x,y,w,h)
  for _,a in ipairs{x,y--[[,w,h--]]} do
    if a~=nil and (not t._x or not t._y or not t._w or not t._h) then t=maketable(t,parsearg(a)) end
  end
  norm(t)
  if not gettype(t) then error('Cannot create geometry object, wrong arguments',2) end
  return setmetatable(t,geometry)
end
--- hs.geometry.new(...) -> hs.geometry object
--- Constructor
--- Creates a new hs.geometry object
---
--- Parameters:
---  * ... - see the module description at the top
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
local function copy(o) return new(o.x,o.y,o.w,o.h) end
geometry.copy=copy

function geometry.__tostring(t)
  local typ=gettype(t)
  local fmt
  if typ=='rect' or typ=='unitrect' then fmt=t.x..','..t.y..','..t.w..','..t.h
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
function geometry.getx2(t) return (t._w and t._x) and (t._x+t._w) or nil end
function geometry.gety2(t) return (t._h and t._y) and (t._y+t._h) or nil end

function geometry.setx(t,v) t._x=tonumber(v) or error('number expected',3) return t end
function geometry.sety(t,v) t._y=tonumber(v) or error('number expected',3) return t end
geometry.setx1=geometry.setx
geometry.sety1=geometry.sety

--- hs.geometry.xy
--- Field
--- The point component for this hs.geometry object; setting this to a new point will move the rect but keep the same width and height

--- hs.geometry.topleft
--- Field
--- Alias for `xy`
function geometry.getxy(t) return (t._x and t._y) and new(t._x,t._y) or nil end
function geometry.setxy(t,p) p=new(p) t._x=p.x t._y=p.y return t end
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
  return t
end
function geometry.seth(t,v)
  t._h=max(tonumber(v) or error('number expected',3),0)
  --  norm(t)
  return t
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
  return t
end
function geometry.sety2(t,v)
  if not t.y then error('not a rect',3) end
  t._h=(tonumber(v) or error('number expected',3))-t._y
  norm(t)
  return t
end

--- hs.geometry.wh
--- Field
--- The size component for this hs.geometry object; setting this to a new size will keep the rect's x,y corner constant

--- hs.geometry.size
--- Field
--- Alias for `wh`
function geometry.getwh(t) return (t._w and t._h) and new(nil,nil,t._w,t._h) or nil end
function geometry.setwh(t,s) s=new(s) t._w=s.w t._h=s.h return t end
geometry.getsize=geometry.getwh
geometry.setsize=geometry.setwh

--- hs.geometry.x2y2
--- Field
--- The point denoting the other corner of this hs.geometry object; setting this to a new point will change the rect's width and height

--- hs.geometry.bottomright
--- Field
--- Alias for `x2y2`
function geometry.getx2y2(t) return (t.x2 and t.y2) and new(t.x2,t.y2) or nil end
function geometry.setx2y2(t,s) s=new(s) t.x2=s.x t.y2=s.y return t end
geometry.getbottomright=geometry.getx2y2
geometry.setbottomright=geometry.setx2y2

--- hs.geometry.table
--- Field
--- The `{x=X,y=Y,w=W,h=H}` table for this hs.geometry object; useful e.g. for serialization/deserialization
function geometry.gettable(t) return {x=t._x,y=t._y,w=t._w,h=t._h} end
function geometry.settable(t,nt) t._x=nt.x t._y=nt.y t._w=nt.w t._h=nt.h return t end

--- hs.geometry.string
--- Field
--- The `"X,Y/WxH"` string for this hs.geometry object (*reduced precision*); useful e.g. for logging

local function ntos(n)
  local f=floor(n)
  return f==n and tostring(f) or sformat('%.2f',n)
end

function geometry.getstring(t)
  local typ=geometry.type(t)
  if typ=='point' then return ntos(t._x)..','..ntos(t._y)--sformat('%.2f,%.2f',t._x,t._y)
  elseif typ=='size' then return ntos(t._w)..'x'..ntos(t._h) --sformat('%.2fx%.2f',t._w,t._h)
  elseif typ=='rect' then return ntos(t._x)..','..ntos(t._y)..'/'..ntos(t._w)..'x'..ntos(t._h) --sformat('%.2f,%.2f/%.2fx%.2f',t._x,t._y,t._w,t._h)
  elseif typ=='unitrect' then return '['..ntos(t._x*100)..','..ntos(t._y*100)..'>'..ntos(t.x2*100)..','..ntos(t.y2*100)..']' --sformat('[%.0f,%.0f>%.0f,%.0f]',t._x*100,t._y*100,t.x2*100,t.y2*100)
  else return ''
  end
end
function geometry.setstring(t,s)
  local nt=new(s)
  t._x=nt._x t._y=nt._y t._w=nt._w t._h=nt._h
  return t
end

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
  return t
end
--- hs.geometry.length
--- Field
--- A number representing the length of the diagonal of this rect, or the length of this vector2; changing it will scale the rect/vector - see `hs.geometry:scale()`
function geometry.getlength(t)
  if t.w and t.h then t=new(t.w,t.h) end
  return sqrt(t.x^2+t.y^2)
end
function geometry.setlength(t,l)
  l=tonumber(l) or error('number expected',3)
  local ol=geometry.getlength(t)
  if ol>0 then
    t=geometry.scale(t,l/ol)
  end
  return t
end
--- hs.geometry.area
--- Field
--- A number representing the area of this rect or size; changing it will scale the rect/size - see `hs.geometry:scale()`
function geometry.getarea(t)
  return (t.w or 0)*(t.h or 0)
end
function geometry.setarea(t,a,...)
  local oa=geometry.getarea(t)
  if oa>0 then
    if type(a)~='number' then
      a=geometry.getarea(new(a,...))
    end
    if a<=0 or a/2==a then error('invalid area, must be > 0 and < inf',2) end
    local f=sqrt(a/oa)
    geometry.scale(t,f)
  end
  return t
end

--- hs.geometry.aspect
--- Field
--- A number representing the aspect ratio of this rect or size; changing it will reshape the rect/size, keeping its area and center constant
function geometry.getaspect(t)
  return (t.w or t.x)/(t.h or t.y) -- downstream deals with NaN
end

function geometry.setaspect(t,asp,...)
  if t.w and t.h and t.w>0 and t.h>0 then
    if type(asp)~='number' then
      asp=geometry.getaspect(new(asp,...))
    end
    if asp<=0 or asp/2==asp then error('invalid aspect, must be > 0 and < inf',2) end
    local oasp,oc,oa=geometry.getaspect(t),geometry.getcenter(t),geometry.getarea(t)
    t.w=t.w*asp/oasp
    geometry.setarea(t,oa) geometry.setcenter(t,oc)
  end
  return t
end

function geometry.__index(t,k)
  if k == "__luaSkinType" then  -- support table<->NSValue auto-conversion in LuaSkin
    local typ=gettype(t)
    if typ=='rect' or typ=='unitrect' then return "NSRect"
    elseif typ=='point' then return "NSPoint"
    elseif typ=='size' then return "NSSize" end
  else
    local r=rawget(geometry,'get'..k)
    if r then return r(t) else return rawget(geometry,k) end --avoid getting .size metatable fn when it's nil
  end
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
--- Scales this vector2/size, or this rect *keeping its center constant*
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
  local sw,sh=s.w or s.x,s.h or s.y
  if (sw~=0 and sw/2==sw) or (sh~=0 and sh/2==sh) then error('invalid scale factor, must be < inf',2) end
  if t.w and t.h then
    if sw<=0 or sh<=0 then error('invalid scale factor, must be > 0',2) end
    t.w=t.w*sw
    t.h=t.h*sh
    geometry.setcenter(t,c)
  else
    t.x=t.x*sw
    t.y=t.y*sh
  end
  return t
end

--- hs.geometry:fit(bounds) -> hs.geometry object
--- Method
--- Ensure this rect is fully inside `bounds`, by scaling it down if it's larger (preserving its aspect ratio) and moving it if necessary
---
--- Parameters:
---  * bounds - an hs.geometry rect object, or a table or string or parameter list to construct one, indicating the rect that
---    must fully contain this rect
---
--- Returns:
---  * this hs.geometry object for method chaining

function geometry.fit(t,...)
  t=new(t) local bounds=new(...)
  if not isRect(t) then error('not a rect',2) elseif not isRect(bounds) then error('bounds must be a rect',2) end
  if t:inside(bounds) then return t end
  if t.w>bounds.w then t:scale(bounds.w/t.w) end
  if t.h>bounds.h then t:scale(bounds.h/t.h) end
  return t:move(bounds:intersect(t).center-t.center):move((t:intersect(bounds).center-t.center)*2):intersect(bounds)
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

--- hs.geometry:floor() -> hs.geometry object
--- Method
--- Truncates all coordinates in this object to integers
---
--- Parameters:
---  * None
---
--- Returns:
---  * this hs.geometry point for method chaining
function geometry.floor(t)
  t=new(t)
  for _,k in ipairs{'_x','_y','_w','_h'} do
    if t[k] then t[k]=floor(t[k]) end
  end
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
  if isRect(t) then t=geometry.getcenter(t) end
  if isRect(t2) then t2=geometry.getcenter(t2) end
  return new((t2.x or 0)-(t.x or 0),(t2.y or 0)-(t.y or 0))
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
  if not isRect(t1) or not isRect(t2) then error('cannot find union for non-rects',2) end
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
  return t1.x>=t2.x and t1.y>=t2.y and (t1.x2 or t1.x)<=(t2.x2 or t2.x) and (t1.y2 or t1.y)<=(t2.y2 or t2.y)
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
  if not isRect(t1) or not isRect(t2) then error('cannot find intersection for non-rects',2) end
  local t1x,t1y,t1x2,t1y2=t1.x,t1.y,t1.x2,t1.y2
  local t2x,t2y,t2x2,t2y2=t2.x,t2.y,t2.x2,t2.y2
  t2x=min(t1x2,max(t1x,t2x)) t2x2=max(t1x,min(t1x2,t2x2))
  t2y=min(t1y2,max(t1y,t2y)) t2y2=max(t1y,min(t1y2,t2y2))
  return new{x=t2x,y=t2y,x2=t2x2,y2=t2y2}
end

-- fun with operator overloading
geometry.__eq=geometry.equals
--geometry.__len=geometry.getlength
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
geometry.__sub=function(t1,t2)
  t2=new(t2)
  local tp1,tp2=gettype(t1),gettype(t2)
  if tp1=='size' or tp2=='size' then error('cannot subtract from a size',2) end
  if isRect(t2) then t2=geometry.getcenter(t2) end
  return new(t1.x-t2.x,t1.y-t2.y,t1.w,t1.h)
    --  return geometry.vector(t2,t1)
end
geometry.__mul=function(t1,t2)t1=copy(t1) return geometry.scale(t1,t2) end
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

--- hs.geometry:toUnitRect(frame) -> hs.geometry unit rect
--- Method
--- Converts a rect into its unit rect within a given frame
---
--- Parameters:
---  * frame - an hs.geometry rect (with `w` and `h` >0)
---
--- Returns:
---  * An hs.geometry unit rect object
---
--- Notes:
---  * The resulting unit rect is always clipped within `frame`'s bounds (via `hs.geometry:intersect()`); if `frame`
---    does not encompass this rect *no error will be thrown*, but the resulting unit rect won't be a direct match with this rect
---    (i.e. calling `:fromUnitRect(frame)` on it will return a different rect)
function geometry.toUnitRect(t,...)
  t=new(t) local frame=new(...)
  if t._w and t._h and gettype(t)~='rect' then error('not a rect',2) end
  if gettype(frame)~='rect' or frame.area==0 then error('frame must be a valid rect',2) end
  -- if frame~=geometry.union(frame,t) then error('frame does not encompass this rect',2) end
  -- no error; but there might be reasons to change this
  t=geometry.intersect(frame,t)
  t._x=(t._x-frame._x)/frame._w
  t._y=(t._y-frame._y)/frame._h
  if t.w then t._w=t._w/frame._w end -- allow 'unit points' as well
  if t.h then t._h=t._h/frame._h end
  return t
end

--- hs.geometry:fromUnitRect(frame) -> hs.geometry rect
--- Method
--- Converts a unit rect within a given frame into a rect
---
--- Parameters:
---  * frame - an hs.geometry rect (with `w` and `h` >0)
---
--- Returns:
---  * An hs.geometry rect object
function geometry.fromUnitRect(t,...)
  t=new(t) local frame=new(...)
  if t._w and t._h and gettype(t)~='unitrect' then error('not a unit rect',2) end
  if gettype(frame)~='rect' or frame.area==0 then error('frame must be a valid rect',2) end
  return new(t._x*frame._w+frame._x,t._y*frame._h+frame._y,t._w and t._w*frame._w,t._h and t._h*frame._h)
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
  for _=1, ntimes or 1 do
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
geometry.unitrect=new

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
  if type(w)=='table' then return new(w) else return new(nil,nil,w,h) end
end

return setmetatable(geometry,{__call=function(_,...)return new(...) end})
