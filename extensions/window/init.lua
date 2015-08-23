--- === hs.window ===
---
--- Inspect/manipulate windows
---
--- Notes:
---  * See `hs.screen` for detailed explanation of how Hammerspoon uses window/screen coordinates.

local uielement = hs.uielement  -- Make sure parent module loads
local window = require "hs.window.internal"
local application = require "hs.application.internal"
--local moses = require "hs.moses"
local geometry = require "hs.geometry"
local screen = require "hs.screen"
local timer = require "hs.timer"
local pairs,ipairs,next,min,max,abs,cos,type = pairs,ipairs,next,math.min,math.max,math.abs,math.cos,type
local tinsert,tremove,tsort,tunpack,tpack = table.insert,table.remove,table.sort,table.unpack,table.pack
--- hs.window.animationDuration (number)
--- Variable
--- The default duration for animations, in seconds. Initial value is 0.2; set to 0 to disable animations.
---
--- Usage:
--- hs.window.animationDuration = 0 -- disable animations
--- hs.window.animationDuration = 3 -- if you have time on your hands
window.animationDuration = 0.2

--- hs.window.allWindows() -> list of hs.window objects
--- Constructor
--- Returns all windows
---
--- Parameters:
---  * None
---
--- Returns:
---  * A list of `hs.window` objects representing all open windows
function window.allWindows()
  --  return fnutils.mapCat(application.runningApplications(), application.allWindows) -- nope
  local r={}
  for _,app in ipairs(application.runningApplications()) do
    if app:kind()>0 then for _,w in ipairs(app:allWindows()) do r[#r+1]=w end end -- major speedup by excluding non-gui apps
  end
  return r
end

--- hs.window.visibleWindows() -> list of hs.window objects
--- Constructor
--- Gets all visible windows
---
--- Parameters:
---  * None
---
--- Returns:
---  * A list containing `hs.window` objects representing all windows that are visible as per `hs.window:isVisible()`
function window.visibleWindows()
  --  return fnutils.filter(window.allWindows(), window.isVisible) -- nope
  local r={}
  for _,app in ipairs(application.runningApplications()) do
    if app:kind()>0 and not app:isHidden() then for _,w in ipairs(app:visibleWindows()) do r[#r+1]=w end end -- speedup by excluding hidden apps
  end
  return r
end

--- hs.window.orderedWindows() -> list of hs.window objects
--- Constructor
--- Returns all visible windows, ordered from front to back
---
--- Parameters:
---  * None
---
--- Returns:
---  * A list of `hs.window` objects representing all visible windows, ordered from front to back
function window.orderedWindows()
  local r,winset,ids = {},{},window._orderedwinids()
  for _,w in ipairs(window.visibleWindows()) do winset[w:id()or -1]=w end
  for _,id in ipairs(ids) do r[#r+1]=winset[id] end -- no inner loop with a set, seems about 5% faster (iterating with prepoluated tables it's 50x faster)
  return r
end
--[[ -- using hs.func, slower (I eradicated the moses version because it was just too ugly - *and* slower)
function window.orderedWindows() 
  local r,wins={},hs.func(window.visibleWindows())
  hs.func.ieach(window._orderedwinids(),function(id)r[#r+1]=wins:ifind(function(w)return w:id()==id end)end)
  return r
end
--]]

--- hs.window.get(hint) -> hs.window object
--- Constructor
--- Gets a specific window
---
--- Parameters:
---  * hint - search criterion for the desired window; it can be:
---    - an id number as per `hs.window:id()`
---    - a window title string as per `hs.window:title()`
---
--- Returns:
---  * the first hs.window object that matches the supplied search criterion, or `nil` if not found
---
--- Notes:
---  * see also `hs.window.find` and `hs.application:getWindow()`
function window.get(hint)
  return tpack(window.find(hint,true),nil)[1] -- just to be sure, discard extra results
end
window.windowForID=window.get

--- hs.window.find(hint) -> hs.window object(s)
--- Constructor
--- Finds windows
---
--- Parameters:
---  * hint - search criterion for the desired window(s); it can be:
---    - an id number as per `hs.window:id()`
---    - a string pattern that matches (via `string.find`) the window title as per `hs.window:title()` (for convenience, the matching will be done on lowercased strings)
---
--- Returns:
---  * one or more hs.window objects that match the supplied search criterion, or `nil` if none found
---
--- Notes:
---  * for convenience you can call this as `hs.window(hint)`
---  * see also `hs.window.get`
---  * for more sophisticated use cases and/or for better performance if you call this a lot, consider using `hs.window.filter`
---
--- Usage:
--- -- by id
--- hs.window(8812):title() --> Hammerspoon Console
--- -- by title
--- hs.window'bash':application():name() --> Terminal
function window.find(hint,exact,wins)
  if hint==nil then return end
  local typ,r=type(hint),{}
  wins=wins or window.allWindows()
  if typ=='number' then for _,w in ipairs(wins) do if w:id()==hint then return w end end
    --  if typ=='number' then return wins[moses.detect(wins,function(w)return w:id()==hint end)]
  elseif typ~='string' then error('hint must be a number or string',2) end
  if exact then for _,w in ipairs(wins) do if w:title()==hint then r[#r+1]=w end end
  else hint=hint:lower() for _,w in ipairs(wins) do if w:title():lower():find(hint) then r[#r+1]=w end end end
  --  r=moses.filter(wins,exact and function(_,w)return w:title()==hint end or function(_,w)return w:title():lower():find(hint:lower())end)
  if #r>0 then return tunpack(r) end
end

--- hs.window:isVisible() -> bool
--- Method
--- Determines if a window is visible (i.e. not hidden and not minimized)
---
--- Parameters:
---  * None
---
--- Returns:
---  * True if the window is visible, otherwise false
---
--- Notes:
---  * This does not mean the user can see the window - it may be obscured by other windows, or it may be off the edge of the screen
function window:isVisible()
  return not self:application():isHidden() and not self:isMinimized()
end


local animations, animTimer = {}


local function animate()
  --[[
  local function quad(x,s,len)
    local l=max(0,min(2,(x-s)*2/len))
    if l<1 then return l*l/2
    else
      l=2-l
      return 1-(l*l/2)
    end
  end
--]]
  local function quadOut(x,s,len)
    local l=1-max(0,min(1,(x-s)/len))
    return 1-l*l
  end
  local time = timer.secondsSinceEpoch()
  for id,anim in pairs(animations) do
    local r = quadOut(time,anim.time,anim.duration)
    local f = {}
    if r>=1 then
      f=anim.endFrame
      animations[id] = nil
    else
      for _,k in pairs{'x','y','w','h'} do
        f[k] = anim.startFrame[k] + (anim.endFrame[k]-anim.startFrame[k])*r
      end
    end
    anim.window:_setFrame(f)
  end
  if not next(animations) then animTimer:stop() end
end
animTimer = timer.new(0.017, animate)


local function getAnimationFrame(win)
  local id = win:id()
  if animations[id] then return animations[id].endFrame end
end

local function stopAnimation(win,snap,id)
  if not id then id = win:id() end
  local anim = animations[id]
  if not anim then return end
  animations[id] = nil
  if not next(animations) then animTimer:stop() end
  if snap then win:_setFrame(anim.endFrame) end
end

-- get actual window frame
function window:_frame()
  local tl,s = self:_topLeft(),self:_size()
  return {x = tl.x, y = tl.y, w = s.w, h = s.h}
end
-- set window frame instantly
function window:_setFrame(f)
  self:_setSize(f) self:_setTopLeft(f) self:_setSize(f)
  return self
end

--- hs.window:frame() -> rect
--- Method
--- Gets the frame of the window in absolute coordinates
---
--- Parameters:
---  * None
---
--- Returns:
---  * A rect-table containing the co-ordinates of the top left corner of the window, and it's width and height
function window:frame()
  return getAnimationFrame(self) or self:_frame()
end
--- hs.window:setFrame(rect[, duration]) -> window
--- Method
--- Sets the frame of the window in absolute coordinates
---
--- Parameters:
---  * rect - A rect-table containing the co-ordinates and size that should be applied to the window
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function window:setFrame(f, duration)
  if duration==nil then duration = window.animationDuration end
  if type(duration)~='number' then duration = 0 end
  local id = self:id()
  stopAnimation(self,false,id)
  if duration<=0 or not id then return self:_setFrame(f) end
  local frame = self:_frame()
  if not animations[id] then animations[id] = {window=self} end
  local anim = animations[id]
  anim.time=timer.secondsSinceEpoch() anim.duration=duration
  anim.startFrame=frame anim.endFrame=f
  animTimer:start()
  return self
end


-- wrapping these Lua-side for dealing with animations cache
function window:size()
  return getAnimationFrame(self) or self:_size()
end
function window:topLeft()
  return getAnimationFrame(self) or self:_topLeft()
end
function window:setSize(size)
  stopAnimation(self)
  return self:_setSize(size)
end
function window:setTopLeft(point)
  stopAnimation(self)
  return self:_setTopLeft(point)
end
function window:minimize()
  stopAnimation(self,true)
  return self:_minimize()
end
function window:unminimize()
  stopAnimation(self,true) -- ?
  return self:_unminimize()
end
function window:toggleZoom()
  stopAnimation(self,true)
  return self:_toggleZoom()
end
function window:setFullScreen(v)
  stopAnimation(self,true)
  return self:_setFullScreen(v)
end
function window:close()
  stopAnimation(self,true)
  return self:_close()
end

--- hs.window:otherWindowsSameScreen() -> win[]
--- Method
--- Gets other windows on the same screen
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table of `hs.window` objects representing the visible windows other than this one that are on the same screen
function window:otherWindowsSameScreen()
  local r=window.visibleWindows() for i=#r,1,-1 do if r[i]==self or r[i]:screen()~=self:screen() then tremove(r,i) end end return r
end

--- hs.window:otherWindowsAllScreens() -> win[]
--- Method
--- Gets every window except this one
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table containing `hs.window` objects representing all visible windows other than this one
function window:otherWindowsAllScreens()
  local r=window.visibleWindows() for i=#r,1,-1 do if r[i]==self then tremove(r,i) break end end return r
end



--- hs.window:focus() -> window
--- Method
--- Focuses the window
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.window` object
function window:focus()
  self:becomeMain()
  self:application():_bringtofront()
  return self
end

--- hs.window:maximize([duration]) -> window
--- Method
--- Maximizes the window
---
--- Parameters:
---  * duration - An optional number containing the number of seconds to animate the operation. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
---
--- Notes:
---  * The window will be resized as large as possible, without obscuring the dock/menu
function window:maximize(duration)
  local screenrect = self:screen():frame()
  return self:setFrame(screenrect, duration)
end

--- hs.window:toggleFullScreen() -> window
--- Method
--- Toggles the fullscreen state of the window
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.window` object
---
--- Notes:
---  * Not all windows support being full-screened
function window:toggleFullScreen()
  self:setFullScreen(not self:isFullScreen())
  return self
end

--- hs.window:screen()
--- Method
--- Gets the screen which the window is on
---
--- Parameters:
---  * None
---
--- Returns:
---  * An `hs.screen` object representing the screen which most contains the window (by area)
function window:screen()
  local frame,screens,maxa,maxs=geometry(self:frame()),screen.allScreens(),0
  for _,s in ipairs(screens) do
    local a=frame:intersect(s:fullFrame()).area
    if a>maxa then maxa,maxs=a,s end
  end
  return maxs
end
--[[ -- moses version
function window:screen()
  local frame,screens=geometry(self:frame()),moses(screen.allScreens())
  return screens:map(function(_,s)return frame:intersect(s:fullFrame()).area end)
    :zip(screens:value()):reduce(function(state,v)return v[1]>state[1] and v or state end,{0,nil}):value()[2]
end
-- hs.func version
function window:ascreen()
  local frame,screens=geometry(self:frame()),hs.func(screen.allScreens())
  return screens:map(function(s)return frame:intersect(s:fullFrame()).area,s end)
    :reduce(function(maxs,maxa,a,s)if a>maxa then return s,a else return maxs,maxa end end,nil,0)
end
--]]

local function isFullyBehind(f1,w2)
  local f2=geometry(w2:frame())
  return f1:intersect(f2).area>=f2.area*0.95
end

local function windowsInDirection(fromWindow, numRotations, candidateWindows, frontmost, strict)
  -- assume looking to east
  -- use the score distance/cos(A/2), where A is the angle by which it
  -- differs from the straight line in the direction you're looking
  -- for. (may have to manually prevent division by zero.)

  local fromFrame=geometry(fromWindow:frame())
  local winset,fromz,fromid={},99999,fromWindow:id() or -1
  for z,w in ipairs(candidateWindows or window.orderedWindows()) do
    if fromid==(w:id() or -2) then fromWindow=w fromz=z --workaround the fact that userdata keep changing
    elseif not candidateWindows or w:isVisible() then winset[w]=z end --make a set, avoid inner loop (if using .orderedWindows skip the visible check as it's done upstream)
  end
  if frontmost then for w,z in pairs(winset) do if z>fromz and isFullyBehind(fromFrame,w) then winset[w]=nil end end end
  local p1,wins=fromFrame.center,{}
  for win,z in pairs(winset) do
    local frame=geometry(win:frame())
    local delta = p1:vector(frame.center:rotateCCW(p1,numRotations))
    if delta.x > (strict and abs(delta.y) or 0) then
      wins[#wins+1]={win=win,score=#delta/cos(delta:angle()/2)+z,z=z,frame=frame}
    end
  end
  tsort(wins,function(a,b)return a.score<b.score end)
  if frontmost then
    local i=1
    while i<=#wins do
      for j=i+1,#wins do
        if wins[j].z<wins[i].z then
          local r=wins[i].frame:intersect(wins[j].frame)
          if r.w>5 and r.h>5 then --TODO var for threshold
            --this window is further away, but it occludes the closest
            local swap=wins[i] wins[i]=wins[j] wins[j]=swap
            i=i-1 break
          end
        end
      end
      i=i+1
    end
  end
  for i=1,#wins do wins[i]=wins[i].win end
  return wins
end

--TODO zorder direct manipulation (e.g. sendtoback)

local function focus_first_valid_window(ordered_wins)
  for _,win in ipairs(ordered_wins) do if win:focus() then return true end end
  return false
end

--- hs.window:windowsToEast(candidateWindows, frontmost, strict) -> list of `hs.window` objects
--- Method
--- Gets all windows to the east of this window
---
--- Parameters:
---  * candidateWindows - (optional) a list of candidate windows to consider; if nil, all visible windows
---    to the east are candidates.
---  * frontmost - (optional) boolean, if true unoccluded windows will be placed before occluded ones in the result list
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the
---    eastward axis
---
--- Returns:
---  * A list of `hs.window` objects representing all windows positioned east (i.e. right) of the window, in ascending order of distance
---
--- Notes:
---  * If you don't pass `candidateWindows`, Hammerspoon will query for the list of all visible windows
---    every time this method is called; this can be slow, consider using the equivalent methods in
---    `hs.window.filter` instead

--- hs.window:windowsToWest(candidateWindows, frontmost, strict) -> list of `hs.window` objects
--- Method
--- Gets all windows to the west of this window
---
--- Parameters:
---  * candidateWindows - (optional) a list of candidate windows to consider; if nil, all visible windows
---    to the west are candidates.
---  * frontmost - (optional) boolean, if true unoccluded windows will be placed before occluded ones in the result list
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the
---    westward axis
---
--- Returns:
---  * A list of `hs.window` objects representing all windows positioned west (i.e. left) of the window, in ascending order of distance
---
--- Notes:
---  * If you don't pass `candidateWindows`, Hammerspoon will query for the list of all visible windows
---    every time this method is called; this can be slow, consider using the equivalent methods in
---    `hs.window.filter` instead

--- hs.window:windowsToNorth(candidateWindows, frontmost, strict) -> list of `hs.window` objects
--- Method
--- Gets all windows to the north of this window
---
--- Parameters:
---  * candidateWindows - (optional) a list of candidate windows to consider; if nil, all visible windows
---    to the north are candidates.
---  * frontmost - (optional) boolean, if true unoccluded windows will be placed before occluded ones in the result list
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the
---    northward axis
---
--- Returns:
---  * A list of `hs.window` objects representing all windows positioned north (i.e. up) of the window, in ascending order of distance
---
--- Notes:
---  * If you don't pass `candidateWindows`, Hammerspoon will query for the list of all visible windows
---    every time this method is called; this can be slow, consider using the equivalent methods in
---    `hs.window.filter` instead

--- hs.window:windowsToSouth(candidateWindows, frontmost, strict) -> list of `hs.window` objects
--- Method
--- Gets all windows to the south of this window
---
--- Parameters:
---  * candidateWindows - (optional) a list of candidate windows to consider; if nil, all visible windows
---    to the south are candidates.
---  * frontmost - (optional) boolean, if true unoccluded windows will be placed before occluded ones in the result list
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the
---    southward axis
---
--- Returns:
---  * A list of `hs.window` objects representing all windows positioned south (i.e. down) of the window, in ascending order of distance
---
--- Notes:
---  * If you don't pass `candidateWindows`, Hammerspoon will query for the list of all visible windows
---    every time this method is called; this can be slow, consider using the equivalent methods in
---    `hs.window.filter` instead


--- hs.window.frontmostWindow() -> hs.window
--- Constructor
--- Returns the focused window or, if no window has focus, the frontmost one
---
--- Parameters:
---  * None
---
--- Returns:
--- * An `hs.window` object representing the frontmost window, or `nil` if there are no visible windows

function window.frontmostWindow()
  local w=window.focusedWindow()
  if w then return w end
  for _,w in ipairs(window.orderedWindows()) do
    local app=w:application()
    if (app and app:title()~='Hammerspoon') or w:subrole()~='AXUnknown' then return w end
  end
end

for n,dir in pairs{['0']='East','North','West','South'}do
  window['windowsTo'..dir]=function(self,...)
    self=self or window.frontmostWindow()
    return self and windowsInDirection(self,n,...)
  end
  window['focusWindow'..dir]=function(self,wins,...)
    self=self or window.frontmostWindow()
    if not self then return end
    if wins==true then -- legacy sameApp parameter
      wins=self:application():visibleWindows()
    end
    return self and focus_first_valid_window(window['windowsTo'..dir](self,wins,...))
  end
  window['moveOneScreen'..dir]=function(self,...) local s=self:screen() return self:moveToScreen(s['to'..dir](s),...) end
end

--- hs.window:focusWindowEast(candidateWindows, frontmost, strict) -> boolean
--- Method
--- Focuses the nearest possible window to the east
---
--- Parameters:
---  * candidateWindows - (optional) a list of candidate windows to consider; if nil, all visible windows
---    to the east are candidates.
---  * frontmost - (optional) boolean, if true focuses the nearest window that isn't occluded by any other window
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the
---    eastward axis
---
--- Returns:
---  * `true` if a window was found and focused, `false` otherwise; `nil` if the search couldn't take place
---
--- Notes:
---  * If you don't pass `candidateWindows`, Hammerspoon will query for the list of all visible windows
---    every time this method is called; this can be slow, consider using the equivalent methods in
---    `hs.window.filter` instead

--- hs.window:focusWindowWest(candidateWindows, frontmost, strict) -> boolean
--- Method
--- Focuses the nearest possible window to the west
---
--- Parameters:
---  * candidateWindows - (optional) a list of candidate windows to consider; if nil, all visible windows
---    to the west are candidates.
---  * frontmost - (optional) boolean, if true focuses the nearest window that isn't occluded by any other window
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the
---    westward axis
---
--- Returns:
---  * `true` if a window was found and focused, `false` otherwise; `nil` if the search couldn't take place
---
--- Notes:
---  * If you don't pass `candidateWindows`, Hammerspoon will query for the list of all visible windows
---    every time this method is called; this can be slow, consider using the equivalent methods in
---    `hs.window.filter` instead

--- hs.window:focusWindowNorth(candidateWindows, frontmost, strict) -> boolean
--- Method
--- Focuses the nearest possible window to the north
---
---  * candidateWindows - (optional) a list of candidate windows to consider; if nil, all visible windows
---    to the north are candidates.
---  * frontmost - (optional) boolean, if true focuses the nearest window that isn't occluded by any other window
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the
---    northward axis
---
--- Returns:
---  * `true` if a window was found and focused, `false` otherwise; `nil` if the search couldn't take place
---
--- Notes:
---  * If you don't pass `candidateWindows`, Hammerspoon will query for the list of all visible windows
---    every time this method is called; this can be slow, consider using the equivalent methods in
---    `hs.window.filter` instead

--- hs.window:focusWindowSouth(candidateWindows, frontmost, strict) -> boolean
--- Method
--- Focuses the nearest possible window to the south
---
---  * candidateWindows - (optional) a list of candidate windows to consider; if nil, all visible windows
---    to the south are candidates.
---  * frontmost - (optional) boolean, if true focuses the nearest window that isn't occluded by any other window
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the
---    southward axis
---
--- Returns:
---  * `true` if a window was found and focused, `false` otherwise; `nil` if the search couldn't take place
---
--- Notes:
---  * If you don't pass `candidateWindows`, Hammerspoon will query for the list of all visible windows
---    every time this method is called; this can be slow, consider using the equivalent methods in
---    `hs.window.filter` instead

--- hs.window:moveToUnit(unitrect[, duration]) -> hs.window object
--- Method
--- Moves and resizes the window to occupy a given fraction of the screen
---
--- Parameters:
---  * unitrect - An hs.geometry unit rect, or constructor argument to create one
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
---
--- Notes:
--   * An example, which would make a window fill the top-left quarter of the screen: `win:moveToUnit({x=0, y=0, w=0.5, h=0.5})`
function window:moveToUnit(unit, duration)
  return self:setFrame(geometry.fromUnitRect(unit,self:screen():frame()),duration)
end

--- hs.window:moveToScreen(screen[, duration]) -> hs.window object
--- Method
--- Moves the window to a given screen, retaining its relative position and size
---
--- Parameters:
---  * screen - An `hs.screen` object, or an argument for `hs.screen.find()`, representing the screen to move the window to
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function window:moveToScreen(toScreen, duration)
  toScreen=screen.find(toScreen)
  if not toScreen then return self end --TODO log?
  return self:setFrame(geometry(self:frame()):toUnitRect(self:screen():frame()):fromUnitRect(toScreen:frame()),duration)
end

--- hs.window:move(rect[, screen][, duration]) --> hs.window object
--- Method
--- Moves the window
---
--- Parameters:
---  * rect - It can be:
---    - an `hs.geometry` point, or argument to construct one; will move the screen by this delta, keeping its size constant; `screen` is ignored
---    - an `hs.geometry` rect, or argument to construct one; will set the window frame to this rect, in absolute coordinates; `screen` is ignored
---    - an `hs.geometry` unit rect, or argument to construct one; will set the window frame to this rect relative to the desired screen;
---      if `screen` is nil or omitted, use the screen the window is currently on
---  * screen - (optional) An `hs.screen` object or argument for `hs.screen.find`; only valid if `rect` is a unit rect
---  * duration - (optional) A number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function window:move(rect,toScreen,duration)
  rect=geometry(rect)
  local rtype=rect:type()
  if type(toScreen)=='number' and toScreen<20 and duration==nil then duration=toScreen toScreen=nil end
  if rtype=='point' then return self:setFrame(geometry(self:frame()):move(rect),duration)
  elseif rtype=='rect' then return self:setFrame(rect,duration)
  elseif rtype=='unitrect' then
    if toScreen then toScreen=screen.find(toScreen) if not toScreen then return self end --TODO log?
    else toScreen=self:screen() end
    return self:setFrame(rect:fromUnitRect(toScreen:frame()),duration)
  else error('rect must be a point, rect, or unit rect',2) end
end

--- hs.window:moveOneScreenWest([duration]) -> hs.window object
--- Method
--- Moves the window one screen west (i.e. left)
---
--- Parameters:
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object

--- hs.window:moveOneScreenEast([duration]) -> window
--- Method
--- Moves the window one screen east (i.e. right)
---
--- Parameters:
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object

--- hs.window:moveOneScreenNorth([duration]) -> window
--- Method
--- Moves the window one screen north (i.e. up)
---
--- Parameters:
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object

--- hs.window:moveOneScreenSouth([duration]) -> window
--- Method
--- Moves the window one screen south (i.e. down)
---
--- Parameters:
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object

--- hs.window:ensureIsInScreenBounds() -> window
--- Method
--- Movies and resizes the window to ensure it is inside the screen
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.window` object
---
--- Notes:
---  * Calling this method will immediately fast-forward to the end of any ongoing animation on the window
function window:ensureIsInScreenBounds()
  stopAnimation(self,true)
  return self:moveToScreen(self:screen(),0)
end

package.loaded[...]=window
window.filter=require "hs.window.filter"
--window.layout = require "hs.window.layout"

do
  local mt=getmetatable(window)
  --[[ this (lazy "autoload") won't work, objc wants the first metatable for objects
  setmetatable(window,{
    __call=function(_,...)return window.find(...)end,
    __index=function(t,k)
      if k=='filter' then window.filter=require'hs.window.filter' return window.filter
      else return mt[k] end
    end})
    --]]
  if not mt.__call then mt.__call=function(t,...)if t.find then return t.find(...) else error('cannot call uielement',2) end end end
end

return window
