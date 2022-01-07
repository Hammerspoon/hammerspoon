--- === hs.screen ===
---
--- Manipulate screens (i.e. monitors)
---
--- The macOS coordinate system used by Hammerspoon assumes a grid that spans all the screens (positioned as per
--- System Preferences->Displays->Arrangement). The origin `0,0` is at the top left corner of the *primary screen*.
--- (Screens to the left of the primary screen, or above it, and windows on these screens, will have negative coordinates)

-- try to load private framework for brightness controls
local state, msg = package.loadlib(
    "/System/Library/PrivateFrameworks/DisplayServices.framework/Versions/Current/DisplayServices",
    "*"
)
if not state then
    hs.printf("-- unable to load DisplayServices framework; may impact brightness control: %s", msg)
end

local screen = require "hs.libscreen"
local geometry = require "hs.geometry"
require "hs.image"

screen.watcher = require "hs.libscreenwatcher"

local type,pairs,ipairs,cos,huge=type,pairs,ipairs,math.cos,math.huge
local tinsert,tremove,tsort,tunpack=table.insert,table.remove,table.sort,table.unpack
local getmetatable,pcall=getmetatable,pcall

local screenObject = hs.getObjectMetatable("hs.screen")

--- hs.screen.primaryScreen() -> screen
--- Constructor
--- Gets the primary screen
---
--- Parameters:
---  * None
---
--- Returns:
---  * An `hs.screen` object
function screen.primaryScreen()
  return screen.allScreens()[1]
end

--- hs.screen.find(hint) -> hs.screen object(s)
--- Function
--- Finds screens
---
--- Parameters:
---  * hint - search criterion for the desired screen(s); it can be:
---   * a number as per `hs.screen:id()`
---   * a string containing the UUID of the desired screen
---   * a string pattern that matches (via `string.match`) the screen name as per `hs.screen:name()` (for convenience, the matching will be done on lowercased strings)
---   * an hs.geometry *point* object, or constructor argument, with the *x and y position* of the screen in the current layout as per `hs.screen:position()`
---   * an hs.geometry *size* object, or constructor argument, with the *resolution* of the screen as per `hs.screen:fullFrame()`
---   * an hs.geometry *rect* object, or constructor argument, with an arbitrary rect in absolute coordinates; the screen
---      containing the largest part of the rect will be returned
---
--- Returns:
---  * one or more hs.screen objects that match the supplied search criterion, or `nil` if none found
---
--- Notes:
---  * for convenience you call call this as `hs.screen(hint)`
---
--- Example:
--- ```lua
--- hs.screen(724562417) --> Color LCD - by id
--- hs.screen'Dell'      --> DELL U2414M - by name
--- hs.screen'Built%-in' --> Built-in Retina Display, note the % to escape the hyphen repetition character
--- hs.screen'0,0'       --> PHL BDM4065 - by position, same as hs.screen.primaryScreen()
--- hs.screen{x=-1,y=0}  --> DELL U2414M - by position, screen to the immediate left of the primary screen
--- hs.screen'3840x2160' --> PHL BDM4065 - by screen resolution
--- hs.screen'-500,240 700x1300' --> DELL U2414M, by arbitrary rect
--- ```
function screen.find(p)
  if p==nil then return end
  local typ=type(p)
  if typ=='userdata' and getmetatable(p)==screenObject then return p
  else
    local screens,r=screen.allScreens(),{}
    if typ=='number' then
      for _,s in ipairs(screens) do if p==s:id() then return s end end return -- not found
    elseif typ=='string' then
      for _,s in ipairs(screens) do
        local sname=s:name()
        if s:getUUID() == p then
          r[#r+1]=s
        elseif sname and sname:lower():find(p:lower()) then
          r[#r+1]=s
        end
      end
      if #r>0 then return tunpack(r) end
    elseif typ~='table' then error('hint can be a number, string or table',2) end
    local ok
    ok,p=pcall(geometry.new,p) if not ok then return end -- not found
    if p.x and p.y then
      if not p.w and not p.h then -- position
        local positions=screen.screenPositions()
        for s,pos in pairs(positions) do if p==pos then return s end end
        return -- not found
      end
      local maxa,maxs=0 -- a rect
      if p.w==0 then p.w=1 end if p.h==0 then p.h=1 end
      for _,s in ipairs(screens) do
        local a=p:intersect(s:fullFrame()).area
        if a>maxa then maxa,maxs=a,s end
      end
      if maxs then return maxs end
      local mind=huge -- if (impossibly) a window is totally out of bounds, get the closest screen
      for _,s in ipairs(screens) do
        local d=p:vector(s:fullFrame()).length
        if d<mind then mind,maxs=d,s end
      end
      return maxs
    elseif p.w and p.h then -- resolution
      for _,s in ipairs(screens) do if p==geometry(s:fullFrame()).size then r[#r+1]=s end end
      if #r>0 then return tunpack(r) end
    end
  end
end

--legacy
screen.findByName=screen.find
screen.findByID=screen.find

--- hs.screen.screenPositions() -> table
--- Function
--- Returns a list of all connected and enabled screens, along with their "position" relative to the primary screen
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table where each *key* is an `hs.screen` object, and the corresponding value is a table {x=X,y=Y}, where X and Y attempt to indicate each screen's position relative to the primary screen (which is at {x=0,y=0}); so e.g. a value of {x=-1,y=0} indicates a screen immediately to the left of the primary screen, and a value of {x=0,y=2} indicates a screen positioned below the primary screen, with another screen inbetween.
---
--- Notes:
---  * grid-like arrangements of same-sized screens should behave consistently; but there's no guarantee of a consistent result for more "exotic" screen arrangements

-- if/when userdata's 'recycling' is addressed, the following note can be added
-- Notes:
--  * To get a specific screen's position in the current layout, you can simply use `pos=hs.screen.screenPositions()[myscreen]`

function screen.screenPositions()
  local screens = screen.allScreens()
  local primary = screens[1]
  tremove(screens,1)
  local res = {[primary]={x=0,y=0}}
  --  for k,v in ipairs(screens) do screens[v]=true screens[k]=nil end -- poor's man :toSet
  local function findNeighbors(x,y,s,ex,ey)
    for dir,co in pairs{East={1,0},West={-1,0},North={0,-1},South={0,1}} do
      if co[1]~=ex or co[2]~=ey then
        local f=s
        f = f['to'..dir](f,nil,true,screens)
        if res[f] then f=nil end
        if f then -- found a screen
          for i,ss in ipairs(screens) do if ss==f then tremove(screens,i) break end end
          local nx,ny=x+co[1],y+co[2]
          res[f]={x=nx,y=ny}--geometry(nx,ny)--
          findNeighbors(nx,ny,f,-co[1],-co[2])
        end
      end
    end
  end
  findNeighbors(0,0,primary,0,0)
  return res
end

--- hs.screen:position() -> x, y
--- Method
--- Return a given screen's position relative to the primary screen - see 'hs.screen.screenPositions()'
---
--- Parameters:
---  * None
---
--- Returns:
---  * two integers indicating the screen position in the current screen arrangement, in the x and y axis respectively.
function screenObject:position()
  local id = self:id()
  local pos=screen.screenPositions()
  for s,p in pairs(pos) do
    if s:id()==id then return p.x,p.y end
  end
end
--- hs.screen:fullFrame() -> hs.geometry rect
--- Method
--- Returns the screen frame, including the dock and menu.
---
--- Parameters:
---  * None
---
--- Returns:
---  * an hs.geometry rect describing this screen's frame in absolute coordinates
function screenObject:fullFrame()
  local primary_screen = screen.allScreens()[1]
  local f = self:_frame()
  f.y = primary_screen:_frame().h - f.h - f.y
  return geometry(f)
end

--- hs.screen:frame() -> hs.geometry rect
--- Method
--- Returns the screen frame, without the dock or menu.
---
--- Parameters:
---  * None
---
--- Returns:
---  * an hs.geometry rect describing this screen's "usable" frame (i.e. without the dock and menu bar) in absolute coordinates
function screenObject:frame()
  local primary_screen = screen.allScreens()[1]
  local f = self:_visibleframe()
  f.y = primary_screen:_frame().h - f.h - f.y
  return geometry(f)
end

--- hs.screen:fromUnitRect(unitrect) -> hs.geometry rect
--- Method
--- Returns the absolute rect of a given unit rect within this screen
---
--- Parameters:
---  * unitrect - an hs.geometry unit rect, or arguments to construct one
---
--- Returns:
---  * an hs.geometry rect describing the given unit rect in absolute coordinates
---
--- Notes:
---  * this method is just a convenience wrapper for `hs.geometry.fromUnitRect(unitrect,this_screen:frame())`
function screenObject:fromUnitRect(unit,...)
  return geometry(unit,...):fromUnitRect(self:frame()):floor()
end

--- hs.screen:toUnitRect(rect) -> hs.geometry unitrect
--- Method
--- Returns the unit rect of a given rect, relative to this screen
---
--- Parameters:
---  * rect - an hs.geometry rect, or arguments to construct one
---
--- Returns:
---  * an hs.geometry unit rect describing the given rect relative to this screen's frame
---
--- Notes:
---  * this method is just a convenience wrapper for `hs.geometry.toUnitRect(rect,this_screen:frame())`
function screenObject:toUnitRect(rect,...)
  return geometry(rect,...):toUnitRect(self:frame())
end

--- hs.screen:localToAbsolute(geom) -> hs.geometry object
--- Method
--- Transforms from the screen's local coordinate space, where `0,0` is at the screen's top left corner, to the absolute coordinate space used by OSX/Hammerspoon
---
--- Parameters:
---  * geom - an hs.geometry point or rect, or arguments to construct one
---
--- Returns:
---  * an hs.geometry point or rect, transformed to the absolute coordinate space
function screenObject:localToAbsolute(rect,...)
  return geometry(rect,...)+self:fullFrame().topleft
end

--- hs.screen:absoluteToLocal(geom) -> hs.geometry object
--- Method
--- Transforms from the absolute coordinate space used by OSX/Hammerspoon to the screen's local coordinate space, where `0,0` is at the screen's top left corner
---
--- Parameters:
---  * geom - an hs.geometry point or rect, or arguments to construct one
---
--- Returns:
---  * an hs.geometry point or rect, transformed to the screen's local coordinate space
function screenObject:absoluteToLocal(rect,...)
  return geometry(rect,...)-self:fullFrame().topleft
end

--- hs.screen:next() -> screen
--- Method
--- Gets the screen 'after' this one (in arbitrary order); this method wraps around to the first screen.
---
--- Parameters:
---  * None
---
--- Returns:
---  * An `hs.screen` object
function screenObject:next()
  local screens = screen.allScreens()
  local idx=1 for i,s in ipairs(screens) do if s==self then idx=i+1 break end end
  if idx>#screens then idx=1 end
  return screens[idx]
end


--- hs.screen:previous() -> screen
--- Method
--- Gets the screen 'before' this one (in arbitrary order); this method wraps around to the last screen.
---
--- Parameters:
---  * None
---
--- Returns:
---  * An `hs.screen` object
function screenObject:previous()
  local screens = screen.allScreens()
  local idx=1 for i,s in ipairs(screens) do if s==self then idx=i-1 break end end
  if idx<1 then idx=#screens end
  return screens[idx]
end

local function first_screen_in_direction(fromScreen, numrotations, fromPoint, strict, allscreens)
  if not allscreens then
    allscreens = screen.allScreens()
    if #allscreens==1 then return end
  end
  if #allscreens==0 then return end
  -- assume looking to east
  -- use the score distance/cos(A/2), where A is the angle by which it
  -- differs from the straight line in the direction you're looking
  -- for. (may have to manually prevent division by zero.)
  -- thanks mark!
  for i,s in ipairs(allscreens) do if s==fromScreen then tremove(allscreens,i) break end end
  local myf = geometry(fromScreen:fullFrame())
  local p1 = (fromPoint and myf:intersect(fromPoint) or myf).center
  local screens = {}
  for _, s in pairs(allscreens) do
    local p2 = geometry(s:fullFrame()).center:rotateCCW(p1,numrotations)
    local delta = p2-p1
    if delta.x > 0 then
      tinsert(screens, {s=s,score=delta.length/cos(delta:angle()/2)})
    end
  end

  if strict or (screen.strictScreenInDirection and strict~=false) then
    -- exclude screens without any horizontal/vertical overlap
    for i=#screens,1,-1 do
      local of=screens[i].s:fullFrame()
      if numrotations==1 or numrotations==3 then
        if of.x+of.w-1<myf.x or myf.x+myf.w-1<of.x then tremove(screens,i) end
      else
        if of.y+of.h-1<myf.y or myf.y+myf.h-1<of.y then tremove(screens,i) end
      end
    end
  end
  tsort(screens, function(a, b) return a.score < b.score end)
  return #screens>0 and screens[1].s or nil
end

--- hs.screen.strictScreenInDirection
--- Variable
--- If set to `true`, the methods `hs.screen:toEast()`, `:toNorth()` etc. will disregard screens that lie perpendicularly to the desired axis
screen.strictScreenInDirection = false

--- hs.screen:toEast(from, strict) -> hs.screen object
--- Method
--- Gets the first screen to the east of this one, ordered by proximity to its center or a specified point.
---
--- Parameters:
---  * from - An `hs.geometry.rect` or `hs.geometry.point` object; if omitted, the geometric center of this screen will be used
---  * strict - If `true`, disregard screens that lie completely above or below this one (alternatively, set `hs.screen.strictScreenInDirection`)
---
--- Returns:
---   * An `hs.screen` object, or `nil` if not found

--- hs.screen:toWest(from, strict) -> hs.screen object
--- Method
--- Gets the first screen to the west of this one, ordered by proximity to its center or a specified point.
---
--- Parameters:
---  * from - An `hs.geometry.rect` or `hs.geometry.point` object; if omitted, the geometric center of this screen will be used
---  * strict - If `true`, disregard screens that lie completely above or below this one (alternatively, set `hs.screen.strictScreenInDirection`)
---
--- Returns:
---   * An `hs.screen` object, or `nil` if not found

--- hs.screen:toNorth(from, strict) -> hs.screen object
--- Method
--- Gets the first screen to the north of this one, ordered by proximity to its center or a specified point.
---
--- Parameters:
---  * from - An `hs.geometry.rect` or `hs.geometry.point` object; if omitted, the geometric center of this screen will be used
---  * strict - If `true`, disregard screens that lie completely to the left or to the right of this one (alternatively, set `hs.screen.strictScreenInDirection`)
---
--- Returns:
---   * An `hs.screen` object, or `nil` if not found

--- hs.screen:toSouth(from, strict) -> hs.screen object
--- Method
--- Gets the first screen to the south of this one, ordered by proximity to its center or a specified point.
---
--- Parameters:
---  * from - An `hs.geometry.rect` or `hs.geometry.point` object; if omitted, the geometric center of this screen will be used
---  * strict - If `true`, disregard screens that lie completely to the left or to the right of this one (alternatively, set `hs.screen.strictScreenInDirection`)
---
--- Returns:
---   * An `hs.screen` object, or `nil` if not found
for r,d in pairs{[0]='East','North','West','South'} do
  screenObject['to'..d]=function(self,...) return first_screen_in_direction(self,r,...) end
end

--- hs.screen:shotAsPNG(filePath[, screenRect])
--- Method
--- Saves an image of the screen to a PNG file
---
--- Parameters:
---  * filePath - A string containing a file path to save the screenshot as
---  * screenRect - An optional `hs.geometry` rect (or arguments for its constructor) containing a portion of the screen to capture. Defaults to the whole screen
---
--- Returns:
---  * None
function screenObject:shotAsPNG(filePath, screenRect,...)
  local image = self:snapshot(screenRect and geometry(screenRect,...))
  image:saveToFile(filePath, "PNG")
end

--- hs.screen:shotAsJPG(filePath[, screenRect])
--- Method
--- Saves an image of the screen to a JPG file
---
--- Parameters:
---  * filePath - A string containing a file path to save the screenshot as
---  * screenRect - An optional `hs.geometry` rect (or arguments for its constructor) containing a portion of the screen to capture. Defaults to the whole screen
---
--- Returns:
---  * None
function screenObject:shotAsJPG(filePath, screenRect,...)
  local image = self:snapshot(screenRect and geometry(screenRect,...))
  image:saveToFile(filePath, "JPG")
end

getmetatable(screen).__call=function(_,...)return screen.find(...)end
return screen
