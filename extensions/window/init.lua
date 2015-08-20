--- === hs.window ===
---
--- Inspect/manipulate windows
---
--- Notes:
---  * See `hs.screen` for detailed explanation of how Hammerspoon uses window/screen coordinates.

local uielement = hs.uielement  -- Make sure parent module loads
local window = require "hs.window.internal"
local application = require "hs.application.internal"
local moses = require "hs.moses"
local geometry = require "hs.geometry"
local screen = require "hs.screen"
local timer = require "hs.timer"
local pairs,ipairs,next,min,max,type = pairs,ipairs,next,math.min,math.max,type
local tinsert,tsort,tunpack = table.insert,table.sort,table.unpack
local intersection,hypot,rectMidPoint,rotateCCW = geometry.intersectionRect,geometry.hypot,geometry.rectMidPoint,geometry.rotateCCW
local atan,cos,abs = math.atan,math.cos,math.abs
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
    if app:kind()>0 then for _,w in ipairs(app:allWindows()) do tinsert(r,w) end end -- major speedup by excluding non-gui apps
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
    if app:kind()>0 and not app:isHidden() then for _,w in ipairs(app:visibleWindows()) do tinsert(r,w) end end -- speedup by excluding hidden apps
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
  local r,wins,ids = {},window.visibleWindows(),window._orderedwinids()
  for _,id in ipairs(ids) do
    for _,w in ipairs(wins) do
      if id == w:id() then
        tinsert(r, w)
        break
      end
    end
  end
  return r
end

--- hs.window.find(hint[, exact]) -> hs.window object(s)
--- Function
--- Finds windows
---
--- Parameters:
---  * hint - search criterion for the desired window(s); it can be:
---    - an id number as per `hs.window:id()`
---    - a string pattern that matches (via `string.find`) the window title as per `hs.window:title()` (for convenience, the matching will be done on lowercased strings)
---  * exact - (optional) if `true`, `hint` is the exact title of the window to find; will use `==` instead of `string.find` (and the original case)
---
--- Returns:
---  * one or more hs.application objects that match the supplied search criterion, or `nil` if none found
---
--- Notes:
---  * for convenience you can call this as `hs.window(hint)`
---  * for more sophisticated use cases and/or for better performance if you call this a lot, consider using `hs.window.filter`
---
--- Usage:
--- -- by id
--- hs.window(8812):title() --> Hammerspoon Console
--- -- by title
--- hs.window'bash':application():name() --> Terminal
function window.find(hint,exact)
  if hint==nil then return end
  local typ=type(hint)
  local wins=window.allWindows()
  if typ=='number' then return wins[moses.detect(wins,function(w)return w:id()==hint end)]
  elseif typ~='string' then error('hint must be a number or string',2) end
  local r=moses.filter(wins,exact and function(_,w)return w:title()==hint end or function(_,w)return w:title():lower():find(hint:lower())end)
  if #r>0 then return tunpack(r) end
end

window.windowForID=window.find

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
---  * A table of `hs.window` objects representing the other windows that are on the same screen as this one
function window:otherWindowsSameScreen()
  return moses.filter(window.visibleWindows(), function(_,win) return self ~= win and self:screen() == win:screen() end)
end

--- hs.window:otherWindowsAllScreens() -> win[]
--- Method
--- Gets every window except this one
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table containing `hs.window` objects representing all windows other than this one
function window:otherWindowsAllScreens()
  return moses.filter(window.visibleWindows(), function(_,win) return self ~= win end)
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
  self:setFrame(screenrect, duration)
  return self
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
  local windowframe = self:frame()
  local lastvolume = 0
  local lastscreen = nil

  for _, s in pairs(screen.allScreens()) do
    local screenframe = s:fullFrame()
    local r = intersection(windowframe, screenframe)
    local volume = r.w * r.h

    if volume > lastvolume then
      lastvolume = volume
      lastscreen = s
    end
  end

  return lastscreen
end

local function isFullyBehind(w1,w2)
  local f1,f2=w1:frame(),w2:frame()
  local r = intersection(f1,f2)
  return r.w*r.h>=f2.w*f2.h*0.95
end

local function windowsInDirection(srcwin, numrotations, candidateWindows, frontmost, strict)
  -- assume looking to east

  -- use the score distance/cos(A/2), where A is the angle by which it
  -- differs from the straight line in the direction you're looking
  -- for. (may have to manually prevent division by zero.)

  -- thanks mark!

  local p1 = rectMidPoint(srcwin:frame())
  local zwins = candidateWindows or window.orderedWindows()

  local zsrc=moses.indexOf(zwins,srcwin) or -1
  -- fnutils.filter uses pairs
  local otherwindows = moses.filter(zwins, function(_,candidate)
    return window.isVisible(candidate) --[[and window.isStandard(candidate)--]] and candidate ~= srcwin
      and (not frontmost or moses.indexOf(zwins,candidate)<zsrc or not isFullyBehind(srcwin,candidate))
  end)
  local wins={}
  for z, win in ipairs(otherwindows) do
    local frame = win:frame()
    local p2 = rectMidPoint(frame)
    p2 = rotateCCW(p2, p1, numrotations)
    local delta = {x=p2.x-p1.x,y=p2.y-p1.y}
    if delta.x > (strict and abs(delta.y) or 0) then
      --cos(atan(y,x)=1/sqrt(1+(y/x)^2), but it's using angle/2
      --      local cosangle = 1/(1+(delta.y/delta.x)^2)^0.5
      local angle = atan(delta.y, delta.x)
      local distance = (delta.x^2+delta.y^2)^0.5
      local score = (distance/cos(angle/2))+z
      tinsert(wins,{win=win,score=score,z=z,frame=frame})
    end
  end
  tsort(wins,function(a,b)return a.score<b.score end)
  if frontmost then
    local i=1
    while i<=#wins do
      --    for i=1,#wins do
      for j=i+1,#wins do
        if wins[j].z<wins[i].z then
          local r=intersection(wins[i].frame,wins[j].frame)
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
  return moses.map(wins,function(_,x)return x.win end)
end

--TODO zorder direct manipulation (e.g. sendtoback)

local function focus_first_valid_window(ordered_wins)
  for _, win in pairs(ordered_wins) do
    if win:focus() then return true end
  end
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
end

--- hs.window:focusWindowEast(candidateWindows, frontmost, strict)
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
---  * None
---
--- Notes:
---  * If you don't pass `candidateWindows`, Hammerspoon will query for the list of all visible windows
---    every time this method is called; this can be slow, consider using the equivalent methods in
---    `hs.window.filter` instead

--- hs.window:focusWindowWest(candidateWindows, frontmost, strict)
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
---  * None
---
--- Notes:
---  * If you don't pass `candidateWindows`, Hammerspoon will query for the list of all visible windows
---    every time this method is called; this can be slow, consider using the equivalent methods in
---    `hs.window.filter` instead

--- hs.window:focusWindowNorth(candidateWindows, frontmost, strict)
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
---  * None
---
--- Notes:
---  * If you don't pass `candidateWindows`, Hammerspoon will query for the list of all visible windows
---    every time this method is called; this can be slow, consider using the equivalent methods in
---    `hs.window.filter` instead

--- hs.window:focusWindowSouth(candidateWindows, frontmost, strict)
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
---  * None
---
--- Notes:
---  * If you don't pass `candidateWindows`, Hammerspoon will query for the list of all visible windows
---    every time this method is called; this can be slow, consider using the equivalent methods in
---    `hs.window.filter` instead

--- hs.window:moveToUnit(rect[, duration]) -> window
--- Method
--- Moves and resizes the window to occupy a given fraction of the screen
---
--- Parameters:
---  * rect - A unit-rect-table where each value is between 0.0 and 1.0
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
---
--- Notes:
--   * An example, which would make a window fill the top-left quarter of the screen: `win:moveToUnit({x=0, y=0, w=0.5, h=0.5})`
function window:moveToUnit(unit, duration)
  local screenrect = self:screen():frame()
  self:setFrame({
    x = screenrect.x + (unit.x * screenrect.w),
    y = screenrect.y + (unit.y * screenrect.h),
    w = unit.w * screenrect.w,
    h = unit.h * screenrect.h,
  }, duration)
  return self
end

--- hs.window:moveToScreen(screen[, duration]) -> window
--- Method
--- Moves the window to a given screen, retaining its relative position and size
---
--- Parameters:
---  * screen - An `hs.screen` object representing the screen to move the window to
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function window:moveToScreen(nextScreen, duration)
  local currentFrame = self:frame()
  local screenFrame = self:screen():frame()
  local nextScreenFrame = nextScreen:frame()
  self:setFrame({
    x = ((((currentFrame.x - screenFrame.x) / screenFrame.w) * nextScreenFrame.w) + nextScreenFrame.x),
    y = ((((currentFrame.y - screenFrame.y) / screenFrame.h) * nextScreenFrame.h) + nextScreenFrame.y),
    h = ((currentFrame.h / screenFrame.h) * nextScreenFrame.h),
    w = ((currentFrame.w / screenFrame.w) * nextScreenFrame.w)
  }, duration)
  return self
end

--- hs.window:moveOneScreenWest([duration]) -> window
--- Method
--- Moves the window one screen west (i.e. left)
---
--- Parameters:
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function window:moveOneScreenWest(duration)
  local dst = self:screen():toWest()
  if dst ~= nil then
    self:moveToScreen(dst, duration)
  end
  return self
end

--- hs.window:moveOneScreenEast([duration]) -> window
--- Method
--- Moves the window one screen east (i.e. right)
---
--- Parameters:
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function window:moveOneScreenEast(duration)
  local dst = self:screen():toEast()
  if dst ~= nil then
    self:moveToScreen(dst, duration)
  end
  return self
end

--- hs.window:moveOneScreenNorth([duration]) -> window
--- Method
--- Moves the window one screen north (i.e. up)
---
--- Parameters:
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function window:moveOneScreenNorth(duration)
  local dst = self:screen():toNorth()
  if dst ~= nil then
    self:moveToScreen(dst, duration)
  end
  return self
end

--- hs.window:moveOneScreenSouth([duration]) -> window
--- Method
--- Moves the window one screen south (i.e. down)
---
--- Parameters:
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function window:moveOneScreenSouth(duration)
  local dst = self:screen():toSouth()
  if dst ~= nil then
    self:moveToScreen(dst, duration)
  end
  return self
end

--- hs.window:ensureIsInScreenBounds([duration]) -> window
--- Method
--- Movies and resizes the window to ensure it is inside the screen
---
--- Parameters:
---  * duration - An optional number containing the number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function window:ensureIsInScreenBounds(duration)
  local frame = self:frame()
  local screenFrame = self:screen():frame()
  if frame.x < screenFrame.x then frame.x = screenFrame.x end
  if frame.y < screenFrame.y then frame.y = screenFrame.y end
  if frame.w > screenFrame.w then frame.w = screenFrame.w end
  if frame.h > screenFrame.h then frame.h = screenFrame.h end
  if frame.x + frame.w > screenFrame.x + screenFrame.w then
    frame.x = (screenFrame.x + screenFrame.w) - frame.w
  end
  if frame.y + frame.h > screenFrame.y + screenFrame.h then
    frame.y = (screenFrame.y + screenFrame.h) - frame.h
  end
  if frame ~= self:frame() then self:setFrame(frame, duration) end
  return self
end

package.loaded[...]=window
window.filter = require "hs.window.filter"
--window.layout = require "hs.window.layout"
do
  local mt=getmetatable(window)
  if not mt.__call then mt.__call=function(t,...)if t.find then return t.find(...) else error('cannot call uielement',2) end end end
end

--getmetatable(window).__call=function(_,...)return window.find(...)end
return window
