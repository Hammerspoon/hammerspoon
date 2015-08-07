--- === hs.screen ===
---
--- Manipulate screens (i.e. monitors)
---
--- You usually get a screen through a window (see `hs.window.screen`). But you can get screens by themselves through this module, albeit not in any defined/useful order.
---
--- Hammerspoon's coordinate system assumes a grid that is the union of every screen's rect (see `hs.screen.fullFrame`).
---
--- Every window's position (i.e. `topleft`) and size are relative to this grid, and they're usually within the grid. A window that's semi-offscreen only intersects the grid.

local screen = require "hs.screen.internal"
local fnutils = require "hs.fnutils"
local geometry = require "hs.geometry"
local imagemod = require "hs.image"

screen.watcher = require "hs.screen.watcher"

local pairs,min,max,cos,atan=pairs,math.min,math.max,math.cos,math.atan
local tinsert,tremove,tsort=table.insert,table.remove,table.sort

--- hs.screen.primaryScreen() -> screen
--- Constructor
--- Returns the primary screen, i.e. the one containing the menubar
function screen.primaryScreen()
  return screen.allScreens()[1]
end

--- hs.screen.findByName(name) -> screen or nil
--- Function
--- Finds a screen by its name
---
--- Parameters:
---  * name - A string containing the name to search for
---
--- Returns:
---  * An `hs.screen` object, or nil if none could be found
function screen.findByName(name)
  return fnutils.find(screen.allScreens(), function(display) return (display:name() == name) end)
end

--- hs.screen.findByID(id) -> screen or nil
--- Function
--- Finds a screen by its ID
---
--- Parameters:
---  * id - A number containing the ID to search for
---
--- Returns:
---  * An `hs.screen` object, or nil if none could be found
function screen.findByID(id)
  return fnutils.find(screen.allScreens(), function(display) return (display:id() == id) end)
end


--- hs.screen.screenPositions() -> table
--- Function
--- Return a list of all connected and enabled screens, along with their "position" relative to the primary screen
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table where each *key* is an `hs.screen` object, and the corresponding value is a table {x=X,y=Y}, where X and Y attempt to indicate
---    each screen's position relative to the primary screen (which is at {x=0,y=0}); so e.g. a value of {x=-1,y=0} indicates a screen immediately to
---    the left of the primary screen, and a value of {x=0,y=2} indicates a screen positioned below the primary screen, with another screen inbetween.
---
--- Notes:
---  * grid-like arrangements of same-sized screens should behave consistently; but there's no guarantee of a consistent result for more "exotic" screen arrangements

-- if/when userdata's __eq and/or 'recycling' is addressed, the following note can be added
-- Notes:
--  * To get a specific screen's position in the current layout, you can simply use `pos=hs.screen.screenLayout()[myscreen]`

function screen.screenPositions()
  local screens = screen.allScreens()
  local primary = screens[1]
  tremove(screens,1)
  local res = {[primary]={x=0,y=0}}
  local function findNeighbors(x,y,s,ex,ey)
    for dir,co in pairs{East={1,0},West={-1,0},North={0,-1},South={0,1}} do
      if co[1]~=ex or co[2]~=ey then
        --        print('search from '..x..y..dir,#screens..'left:')
        local f=s
        f = f['to'..dir](f,nil,true,screens)
        if res[f] then f=nil end
        if f then
          --          print('found a screen')
          tremove(screens,fnutils.indexOf(screens,f))
          local nx,ny=x+co[1],y+co[2]
          res[f]={x=nx,y=ny}
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
function screen:position()
  local id = self:id()
  local pos=screen.screenPositions()
  for s,p in pairs(pos) do
    if s:id()==id then return p.x,p.y end
  end
end
--- hs.screen:fullFrame() -> rect
--- Method
--- Returns the screen's rect in absolute coordinates, including the dock and menu.
function screen:fullFrame()
  local primary_screen = screen.allScreens()[1]
  local f = self:_frame()
  f.y = primary_screen:_frame().h - f.h - f.y
  return f
end

--- hs.screen:frame() -> rect
--- Method
--- Returns the screen's rect in absolute coordinates, without the dock or menu.
function screen:frame()
  local primary_screen = screen.allScreens()[1]
  local f = self:_visibleframe()
  f.y = primary_screen:_frame().h - f.h - f.y
  return f
end

--- hs.screen:next() -> screen
--- Method
--- Returns the screen 'after' this one (I have no idea how they're ordered though); this method wraps around to the first screen.
function screen:next()
  local screens = screen.allScreens()
  local i = fnutils.indexOf(screens, self) + 1
  if i > # screens then i = 1 end
  return screens[i]
end


--- hs.screen:previous() -> screen
--- Method
--- Returns the screen 'before' this one (I have no idea how they're ordered though); this method wraps around to the last screen.
function screen:previous()
  local screens = screen.allScreens()
  local i = fnutils.indexOf(screens, self) - 1
  if i < 1 then i = # screens end
  return screens[i]
end

local function projection(base, rect) -- like hs.geometry,intersectionRect, but better
  local basex,basey,basex2,basey2=base.x,base.y,base.x+base.w,base.y+base.h
  local rectx,recty,rectx2,recty2=rect.x,rect.y,rect.x+(rect.w or 0),rect.y+(rect.h or 0)
  if basex<rectx then rectx=min(basex2,rectx) rectx2=min(basex2,rectx2)
  else rectx=max(basex,rectx) rectx2=max(basex,rectx2) end
  if basey<recty then recty=min(basey2,recty) recty2=min(basey2,recty2)
  else recty=max(basey,recty) recty2=max(basey,recty2) end
  return {x=rectx,y=recty,w=rectx2-rectx,h=recty2-recty}
end

local function first_screen_in_direction(screen, numrotations, from, strict, allscreens)
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

  local otherscreens = fnutils.filter(allscreens, function(s) return s ~= screen end)
  local myf=screen:fullFrame()
  local p1 = geometry.rectMidPoint(from and projection(myf,from) or myf)
  local screens = {}

  for _, s in pairs(otherscreens) do
    local p2 = geometry.rectMidPoint(s:fullFrame())
    p2 = geometry.rotateCCW(p2, p1, numrotations)
    local delta = {x=p2.x-p1.x,y=p2.y-p1.y}
    if delta.x > 0 then
      local angle = atan(delta.y, delta.x)
      local distance = geometry.hypot(delta)
      --      local anglediff = -angle
      local score = distance / cos(angle / 2)
      tinsert(screens, {s = s, score = score})
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
  return #screens>0 and screens[1].s
end

--- hs.screen.strictScreenInDirection
--- Variable
--- If set to `true`, the methods `hs.screen:toEast()`, `:toNorth()` etc. will disregard screens that lie perpendicularly to the desired axis
screen.strictScreenInDirection = false

--- hs.screen:toEast()
--- Method
--- Get the first screen to the east of this one, ordered by proximity to its center or a specified point.
---
--- Parameters:
---   * from - An `hs.geometry.rect` or `hs.geometry.point` object; if omitted, the geometric center of this screen will be used
---   * strict - If `true`, disregard screens that lie completely above or below this one (alternatively, set `hs.screen.strictScreenInDirection`)
function screen:toEast(...)  return first_screen_in_direction(self, 0, ...) end

--- hs.screen:toWest()
--- Method
--- Get the first screen to the west of this one, ordered by proximity to its center or a specified point.
--- Parameters:
---   * from - An `hs.geometry.rect` or `hs.geometry.point` object; if omitted, the geometric center of this screen will be used
---   * strict - If `true`, disregard screens that lie completely above or below this one (alternatively, set `hs.screen.strictScreenInDirection`)
function screen:toWest(...)  return first_screen_in_direction(self, 2, ...) end

--- hs.screen:toNorth()
--- Method
--- Get the first screen to the north of this one, ordered by proximity to its center or a specified point.
--- Parameters:
---   * from - An `hs.geometry.rect` or `hs.geometry.point` object; if omitted, the geometric center of this screen will be used
---   * strict - If `true`, disregard screens that lie completely to the left or to the right of this one (alternatively, set `hs.screen.strictScreenInDirection`)
function screen:toNorth(...) return first_screen_in_direction(self, 1, ...) end

--- hs.screen:toSouth()
--- Method
--- Get the first screen to the south of this one, ordered by proximity to its center or a specified point.
--- Parameters:
---   * from - An `hs.geometry.rect` or `hs.geometry.point` object; if omitted, the geometric center of this screen will be used
---   * strict - If `true`, disregard screens that lie completely to the left or to the right of this one (alternatively, set `hs.screen.strictScreenInDirection`)
function screen:toSouth(...) return first_screen_in_direction(self, 3, ...) end

--- hs.screen:shotAsPNG(filePath[, screenRect])
--- Method
--- Saves an image of the screen to a PNG file
---
--- Parameters:
---  * filePath - A string containing a file path to save the screenshot as
---  * screenRect - An optional `rect-table` containing a portion of the screen to capture. Defaults to the whole screen
---
--- Returns:
---  * None
function screen:shotAsPNG(filePath, screenRect)
  local image = self:snapshot(screenRect)
  image:saveToFile(filePath, "PNG")
end

--- hs.screen:shotAsJPG(filePath[, screenRect])
--- Method
--- Saves an image of the screen to a JPG file
---
--- Parameters:
---  * filePath - A string containing a file path to save the screenshot as
---  * screenRect - An optional `rect-table` containing a portion of the screen to capture. Defaults to the whole screen
---
--- Returns:
---  * None
function screen:shotAsJPG(filePath, screenRect)
  local image = self:snapshot(screenRect)
  image:saveToFile(filePath, "JPG")
end

return screen
