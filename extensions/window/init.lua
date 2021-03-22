--- === hs.window ===
---
--- Inspect/manipulate windows
---
--- Notes:
---  * See `hs.screen` and `hs.geometry` for more information on how Hammerspoon uses window/screen frames and coordinates

local application = require "hs.application"
local window = require("hs.window.internal")
local geometry = require "hs.geometry"
local gtype=geometry.type
local screen = require "hs.screen"
local timer = require "hs.timer"
require "hs.image" -- make sure we know about HSImage userdata type
local pairs,ipairs,next,min,max,abs,cos,type = pairs,ipairs,next,math.min,math.max,math.abs,math.cos,type
local tinsert,tremove,tsort,tunpack,tpack = table.insert,table.remove,table.sort,table.unpack,table.pack

local USERDATA_TAG = "hs.window"
local objectMT     = hs.getObjectMetatable(USERDATA_TAG)

--- hs.window.animationDuration (number)
--- Variable
--- The default duration for animations, in seconds. Initial value is 0.2; set to 0 to disable animations.
---
--- Usage:
--- ```
--- hs.window.animationDuration = 0 -- disable animations
--- hs.window.animationDuration = 3 -- if you have time on your hands
--- ```
window.animationDuration = 0.2


--- hs.window.desktop() -> hs.window object
--- Function
--- Returns the desktop "window"
---
--- Parameters:
---  * None
---
--- Returns:
---  * An `hs.window` object representing the desktop, or nil if Finder is not running
---
--- Notes:
---  * The desktop belongs to Finder.app: when Finder is the active application, you can focus the desktop by cycling
---    through windows via cmd-`
---  * The desktop window has no id, a role of `AXScrollArea` and no subrole
---  * The desktop is filtered out from `hs.window.allWindows()` (and downstream uses)
function window.desktop()
  local finder = application.get('com.apple.finder')
  if not finder then return nil end
  for _,w in ipairs(finder:allWindows()) do if w:role()=='AXScrollArea' then return w end end
end

--- hs.window.allWindows() -> list of hs.window objects
--- Function
--- Returns all windows
---
--- Parameters:
---  * None
---
--- Returns:
---  * A list of `hs.window` objects representing all open windows
---
--- Notes:
---  * `visibleWindows()`, `orderedWindows()`, `get()`, `find()`, and several more functions and methods in this and other
---     modules make use of this function, so it is important to understand its limitations
---  * This function queries all applications for their windows every time it is invoked; if you need to call it a lot and
---    performance is not acceptable consider using the `hs.window.filter` module
---  * This function can only return windows in the current Mission Control Space; if you need to address windows across
---    different Spaces you can use the `hs.window.filter` module
---    - if `Displays have separate Spaces` is *on* (in System Preferences>Mission Control) the current Space is defined
---      as the union of all currently visible Spaces
---    - minimized windows and hidden windows (i.e. belonging to hidden apps, e.g. via cmd-h) are always considered
---      to be in the current Space
---  * This function filters out the desktop "window"; use `hs.window.desktop()` to address it. (Note however that
---    `hs.application.get'Finder':allWindows()` *will* include the desktop in the returned list)
---  * Beside the limitations discussed above, this function will return *all* windows as reported by OSX, including some
---    "windows" that one wouldn't expect: for example, every Google Chrome (actual) window has a companion window for its
---    status bar; therefore you might get unexpected results  - in the Chrome example, calling `hs.window.focusWindowSouth()`
---    from a Chrome window would end up "focusing" its status bar, and therefore the proper window itself, seemingly resulting
---    in a no-op. In order to avoid such surprises you can use the `hs.window.filter` module, and more specifically
---    the default windowfilter (`hs.window.filter.default`) which filters out known cases of not-actual-windows
---  * Some windows will not be reported by OSX - e.g. things that are on different Spaces, or things that are Full Screen
local SKIP_APPS={
  ['com.apple.WebKit.WebContent']=true,['com.apple.qtserver']=true,['com.google.Chrome.helper']=true,
  ['org.pqrs.Karabiner-AXNotifier']=true,['com.adobe.PDApp.AAMUpdatesNotifier']=true,
  ['com.adobe.csi.CS5.5ServiceManager']=true,['com.mcafee.McAfeeReporter']=true}
-- so apparently OSX enforces a 6s limit on apps to respond to AX queries;
-- Karabiner's AXNotifier and Adobe Update Notifier fail in that fashion
function window.allWindows()
  local r={}
  for _,app in ipairs(application.runningApplications()) do
    if app:kind()>=0 then
      local bid=app:bundleID() or 'N/A' --just for safety; universalaccessd has no bundleid (but it's kind()==-1 anyway)
      if bid=='com.apple.finder' then --exclude the desktop "window"
        -- check the role explicitly, instead of relying on absent :id() - sometimes minimized windows have no :id() (El Cap Notes.app)
        for _,w in ipairs(app:allWindows()) do if w:role()=='AXWindow' then r[#r+1]=w end end
      elseif not SKIP_APPS[bid] then
        for _,w in ipairs(app:allWindows()) do
          r[#r+1]=w
        end
      end
    end
  end
  return r
end

function window._timed_allWindows()
  local r={}
  for _,app in ipairs(application.runningApplications()) do
    local starttime=timer.secondsSinceEpoch()
    local _,bid=app:allWindows(),app:bundleID() or 'N/A'
    r[bid]=(r[bid] or 0) + timer.secondsSinceEpoch()-starttime
  end
  for app,time in pairs(r) do
    if time>0.05 then print(string.format('took %.2fs for %s',time,app)) end
  end
  --  print('known exclusions:') print(hs.inspect(SKIP_APPS))
  return r
end

--- hs.window.visibleWindows() -> list of hs.window objects
--- Function
--- Gets all visible windows
---
--- Parameters:
---  * None
---
--- Returns:
---  * A list containing `hs.window` objects representing all windows that are visible as per `hs.window:isVisible()`
function window.visibleWindows()
  local r={}
  for _,app in ipairs(application.runningApplications()) do
    if app:kind()>0 and not app:isHidden() then for _,w in ipairs(app:visibleWindows()) do r[#r+1]=w end end -- speedup by excluding hidden apps
  end
  return r
end

--- hs.window.invisibleWindows() -> list of hs.window objects
--- Function
--- Gets all invisible windows
---
--- Parameters:
---  * None
---
--- Returns:
---  * A list containing `hs.window` objects representing all windows that are not visible as per `hs.window:isVisible()`
function window.invisibleWindows()
  local r = {}
  for _, win in ipairs(window.allWindows()) do
    if not win:isVisible() then r[#r + 1] = win end
  end
  return r
end

--- hs.window.minimizedWindows() -> list of hs.window objects
--- Function
--- Gets all minimized windows
---
--- Parameters:
---  * None
---
--- Returns:
---  * A list containing `hs.window` objects representing all windows that are minimized as per `hs.window:isMinimized()`
function window.minimizedWindows()
  local r = {}
  for _, win in ipairs(window.allWindows()) do
    if win:isMinimized() then r[#r + 1] = win end
  end
  return r
end

--- hs.window.orderedWindows() -> list of hs.window objects
--- Function
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
--- ```
--- -- by id
--- hs.window(8812):title() --> Hammerspoon Console
--- -- by title
--- hs.window'bash':application():name() --> Terminal
--- ```
function window.find(hint,exact,wins)
  if hint==nil then return end
  local typ,r=type(hint),{}
  wins=wins or window.allWindows()
  if typ=='number' then for _,w in ipairs(wins) do if w:id()==hint then return w end end return
  elseif typ~='string' then error('hint must be a number or string',2) end
  if exact then for _,w in ipairs(wins) do if w:title()==hint then r[#r+1]=w end end
  else hint=hint:lower() for _,w in ipairs(wins) do local wtitle=w:title() if wtitle and wtitle:lower():find(hint) then r[#r+1]=w end end end
  if #r>0 then return tunpack(r) end
end

--- hs.window:isVisible() -> boolean
--- Method
--- Determines if a window is visible (i.e. not hidden and not minimized)
---
--- Parameters:
---  * None
---
--- Returns:
---  * `true` if the window is visible, otherwise `false`
---
--- Notes:
---  * This does not mean the user can see the window - it may be obscured by other windows, or it may be off the edge of the screen
function objectMT.isVisible(self)
  if getmetatable(self).__type ~= 'hs.window' then return end
  local parentApp = self:application()
  if not parentApp then return false end
  return not parentApp:isHidden() and not self:isMinimized()
end


local animations, animTimer = {}
local DISTANT_FUTURE=315360000 -- 10 years (roughly)
--[[ local function quad(x,s,len)
       local l=max(0,min(2,(x-s)*2/len))
       if l<1 then return l*l/2
       else l=2-l return 1-(l*l/2) end
     end --]]
local function quadOut(x,s,len)
  local l=1-max(0,min(1,(x-s)/len))
  return 1-l*l
end
local function animate()
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
  if not next(animations) then animTimer:setNextTrigger(DISTANT_FUTURE) end
end
animTimer = timer.new(0.017,animate)
animTimer:start() --keep this split

local function getAnimationFrame(win)
  local id = win:id()
  if animations[id] then return animations[id].endFrame end
end

local function stopAnimation(win,snap,id)
  if not id then id = win:id() end
  local anim = animations[id]
  if not anim then return end
  animations[id] = nil
  if not next(animations) then animTimer:setNextTrigger(DISTANT_FUTURE) end
  if snap then win:_setFrame(anim.endFrame) end
end

function objectMT._frame(self) -- get actual window frame right now
  return geometry(self:_topLeft(),self:_size())
end

function objectMT._setFrame(self, f) -- set window frame instantly
  self:_setSize(f) self:_setTopLeft(f) return self:_setSize(f)
end

local function setFrameAnimated(self,id,f,duration)
  local frame = self:_frame()
  if not animations[id] then animations[id] = {window=self} end
  local anim = animations[id]
  anim.time=timer.secondsSinceEpoch() anim.duration=duration
  anim.startFrame=frame anim.endFrame=f
  animTimer:setNextTrigger(0.01)
  return self
end

local function setFrameWithWorkarounds(self,f,duration)
  local originalFrame=geometry(self:_frame())
  local safeBounds=self:screen():frame()
  if duration>0 then -- if no animation, skip checking for possible trouble
    if not originalFrame:inside(safeBounds) then duration=0 -- window straddling screens or partially offscreen
    else
      local testSize=geometry.size(originalFrame.w-1,originalFrame.h-1)
      self:_setSize(testSize)
      -- find out if it's a terminal, or a window already shrunk to minimum, or a window on a 'sticky' edge
      local newSize=self:_size()
      if originalFrame.size==newSize -- terminal or minimum size
        or (testSize~=newSize and (abs(f.x2-originalFrame.x2)<100 or abs(f.y2-originalFrame.y2)<100)) then --sticky edge, and not going far enough
        duration=0 end -- don't animate troublesome windows
    end
  end
  local safeFrame=geometry.new(originalFrame.xy,f.size) --apply the desired size
  safeBounds:move(30,30) -- offset
  safeBounds.w=safeBounds.w-60 safeBounds.h=safeBounds.h-60 -- and shrink
  self:_setFrame(safeFrame:fit(safeBounds)) -- put it within a 'safe' area in the current screen, and insta-resize
  local actualSize=geometry(self:_size()) -- get the *actual* size the window resized to
  if actualSize.area>f.area then f.size=actualSize end -- if it's bigger apply it
  if duration==0 then
    self:_setSize(f.size) -- apply the final size while the window is still in the safe area
    self:_setTopLeft(f)
    return self:_setSize(f.size)
  end
  self:_setFrame(originalFrame) -- restore the original frame and start the animation
  return setFrameAnimated(self,self:id(),f,duration)
end

local function setFrame(self,f,duration,workarounds)
  if duration==nil then duration = window.animationDuration end
  if type(duration)~='number' then duration=0 end
  f=geometry(f):floor()
  if gtype(f)~='rect' then error('invalid rect: '..f.string,3) end
  local id=self:id()
  if id then stopAnimation(self,false,id) else duration=0 end
  if workarounds then return setFrameWithWorkarounds(self,f,duration)
  elseif duration<=0 then return self:_setFrame(f)
  else return setFrameAnimated(self,id,f,duration) end
end

--- hs.window:setFrame(rect[, duration]) -> hs.window object
--- Method
--- Sets the frame of the window in absolute coordinates
---
--- Parameters:
---  * rect - An hs.geometry rect, or constructor argument, describing the frame to be applied to the window
---  * duration - (optional) The number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function objectMT.setFrame(self, f, duration) return setFrame(self,f,duration,window.setFrameCorrectness) end

--- hs.window:setFrameWithWorkarounds(rect[, duration]) -> hs.window object
--- Method
--- Sets the frame of the window in absolute coordinates, using the additional workarounds described in `hs.window.setFrameCorrectness`
---
--- Parameters:
---  * rect - An hs.geometry rect, or constructor argument, describing the frame to be applied to the window
---  * duration - (optional) The number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function objectMT.setFrameWithWorkarounds(self, f, duration) return setFrame(self,f,duration,true) end

--- hs.window.setFrameCorrectness
--- Variable
--- Using `hs.window:setFrame()` in some cases does not work as expected: namely, the bottom (or Dock) edge, and edges between screens, might
--- exhibit some "stickiness"; consequently, trying to make a window abutting one of those edges just *slightly* smaller could
--- result in no change at all (you can verify this by trying to resize such a window with the mouse: at first it won't budge,
--- and, as you drag further away, suddenly snap to the new size); and similarly in some cases windows along screen edges
--- might erroneously end up partially on the adjacent screen after a move/resize.  Additionally some windows (no matter
--- their placement on screen) only allow being resized at "discrete" steps of several screen points; the typical example
--- is Terminal windows, which only resize to whole rows and columns. Both these OSX issues can cause incorrect behavior
--- when using `:setFrame()` directly or in downstream uses, such as `hs.window:move()` and the `hs.grid` and `hs.window.layout` modules.
---
--- Setting this variable to `true` will make `:setFrame()` perform additional checks and workarounds for these potential
--- issues. However, as a side effect the window might appear to jump around briefly before setting toward its destination
--- frame, and, in some cases, the move/resize animation (if requested) might be skipped entirely - these tradeoffs are
--- necessary to ensure the desired result.
---
--- The default value is `false`, in order to avoid the possibly annoying or distracting window wiggling; set to `true` if you see
--- incorrect results in `:setFrame()` or downstream modules and don't mind the the wiggling.
window.setFrameCorrectness = false

--- hs.window:setFrameInScreenBounds([rect][, duration]) -> hs.window object
--- Method
--- Sets the frame of the window in absolute coordinates, possibly adjusted to ensure it is fully inside the screen
---
--- Parameters:
---  * rect - An hs.geometry rect, or constructor argument, describing the frame to be applied to the window; if omitted,
---    the current window frame will be used
---  * duration - (optional) The number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function objectMT.setFrameInScreenBounds(self, f, duration)
  if type(f)=='number' then duration=f f=nil end
  f = f and geometry(f):floor() or self:frame()
  return self:setFrame(f:fit(screen.find(f):frame()),duration)
end
window.ensureIsInScreenBounds=window.setFrameInScreenBounds --backward compatible

--- hs.window:frame() -> hs.geometry rect
--- Method
--- Gets the frame of the window in absolute coordinates
---
--- Parameters:
---  * None
---
--- Returns:
---  * An hs.geometry rect containing the co-ordinates of the top left corner of the window and its width and height
function objectMT.frame(self) return getAnimationFrame(self) or self:_frame() end

-- wrapping these Lua-side for dealing with animations cache
function objectMT.size(self)
  local f=getAnimationFrame(self)
  return f and f.size or geometry(self:_size())
end
function objectMT.topLeft(self)
  local f=getAnimationFrame(self)
  return f and f.xy or geometry(self:_topLeft())
end
function objectMT.setSize(self, ...)
  stopAnimation(self,true)
  return self:_setSize(geometry.size(...))
end
function objectMT.setTopLeft(self, ...)
  stopAnimation(self,true)
  return self:_setTopLeft(geometry.point(...))
end
function objectMT.minimize(self)
  stopAnimation(self,true)
  return self:_minimize()
end
function objectMT.unminimize(self)
  stopAnimation(self,true)
  return self:_unminimize()
end
function objectMT.toggleZoom(self)
  stopAnimation(self,true)
  return self:_toggleZoom()
end
function objectMT.setFullScreen(self, v)
  stopAnimation(self,true)
  return self:_setFullScreen(v)
end
function objectMT.close(self)
  stopAnimation(self,true)
  return self:_close()
end

--- hs.window:otherWindowsSameScreen() -> list of hs.window objects
--- Method
--- Gets other windows on the same screen
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table of `hs.window` objects representing the visible windows other than this one that are on the same screen
function objectMT.otherWindowsSameScreen(self)
  local r=window.visibleWindows() for i=#r,1,-1 do if r[i]==self or r[i]:screen()~=self:screen() then tremove(r,i) end end
  return r
end

--- hs.window:otherWindowsAllScreens() -> list of hs.window objects
--- Method
--- Gets every window except this one
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table containing `hs.window` objects representing all visible windows other than this one
function objectMT.otherWindowsAllScreens(self)
  local r=window.visibleWindows() for i=#r,1,-1 do if r[i]==self then tremove(r,i) break end end
  return r
end

local desktopFocusWorkaroundTimer --workaround for the desktop taking over
--- hs.window:focus() -> hs.window object
--- Method
--- Focuses the window
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.window` object
function objectMT.focus(self)
  local app=self:application()
  if app then
    self:becomeMain()
    app:_bringtofront()
    if app:bundleID()=='com.apple.finder' then --workaround for the desktop taking over
      -- it may look like this should ideally go inside :becomeMain(), but the problem is actually
      -- triggered by :_bringtofront(), so the workaround belongs here
      if desktopFocusWorkaroundTimer then desktopFocusWorkaroundTimer:stop() end
      desktopFocusWorkaroundTimer=timer.doAfter(0.3,function()
        -- 0.3s comes from https://github.com/Hammerspoon/hammerspoon/issues/581
        -- it'd be slightly less ugly to use a "space change completed" callback (as per issue above) rather than
        -- a crude timer, althought that route is a lot more complicated
        self:becomeMain()
        desktopFocusWorkaroundTimer=nil --cleanup the timer
      end)
      self:becomeMain() --ensure space change actually takes place when necessary
    end
  end
  return self
end

--- hs.window:sendToBack() -> hs.window object
--- Method
--- Sends the window to the back
---
--- This method works by focusing all overlapping windows behind this one, front to back.
--- If called on the focused window, this method will switch focus to the topmost window under this one; otherwise, the
--- currently focused window will regain focus after this window has been sent to the back.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The `hs.window` object
---
--- Notes:
---  * Due to the way this method works and OSX limitations, calling this method when you have a lot of randomly overlapping
---   (as opposed to neatly tiled) windows might be visually jarring, and take a fair amount of time to complete.
---   So if you don't use orderly layouts, or if you have a lot of windows in general, you're probably better off using
---   `hs.application:hide()` (or simply `cmd-h`)
local WINDOW_ROLES={AXStandardWindow=true,AXDialog=true,AXSystemDialog=true}
function objectMT.sendToBack(self)
  local id,frame=self:id(),self:frame()
  local fw=window.focusedWindow()
  local wins=window.orderedWindows()
  for z=#wins,1,-1 do local w=wins[z] if id==w:id() or not WINDOW_ROLES[w:subrole()] then tremove(wins,z) end end
  local toRaise,topz,didwork={}
  repeat
    for z=#wins,1,-1 do
      didwork=nil
      local wf=wins[z]:frame()
      if frame:intersect(wf).area>0 then
        topz=z
        if not toRaise[z] then
          didwork=true
          toRaise[z]=true
          frame=frame:union(wf) break
        end
      end
    end
  until not didwork
  if topz then
    for z=#wins,1,-1 do if toRaise[z] then wins[z]:focus() timer.usleep(80000) end end
    wins[topz]:focus()
    if fw and fw:id()~=id then fw:focus() end
  end
  return self
end

--- hs.window:maximize([duration]) -> hs.window object
--- Method
--- Maximizes the window
---
--- Parameters:
---  * duration - (optional) The number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
---
--- Notes:
---  * The window will be resized as large as possible, without obscuring the dock/menu
function objectMT.maximize(self, duration)
  return self:setFrame(self:screen():frame(), duration)
end

--- hs.window:toggleFullScreen() -> hs.window object
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
function objectMT.toggleFullScreen(self)
  self:setFullScreen(not self:isFullScreen())
  return self
end
-- aliases
objectMT.toggleFullscreen=objectMT.toggleFullScreen
objectMT.isFullscreen=objectMT.isFullScreen
objectMT.setFullscreen=objectMT.setFullScreen

--- hs.window:screen() -> hs.screen object
--- Method
--- Gets the screen which the window is on
---
--- Parameters:
---  * None
---
--- Returns:
---  * An `hs.screen` object representing the screen which most contains the window (by area)
function objectMT.screen(self)
  return screen.find(self:frame())--findScreenForFrame(self:frame())
end

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
    if fromid==(w:id() or -2) then fromz=z --workaround the fact that userdata keep changing
    elseif not candidateWindows or w:isVisible() then winset[w]=z end --make a set, avoid inner loop (if using .orderedWindows skip the visible check as it's done upstream)
  end
  if frontmost then for w,z in pairs(winset) do if z>fromz and isFullyBehind(fromFrame,w) then winset[w]=nil end end end
  local p1,wins=fromFrame.center,{}
  for win,z in pairs(winset) do
    local frame=geometry(win:frame())
    local delta = p1:vector(frame.center:rotateCCW(p1,numRotations))
    if delta.x > (strict and abs(delta.y) or 0) then
      wins[#wins+1]={win=win,score=delta.length/cos(delta:angle()/2)+z,z=z,frame=frame}
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

--- hs.window:windowsToEast([candidateWindows[, frontmost[, strict]]]) -> list of hs.window objects
--- Method
--- Gets all windows to the east of this window
---
--- Parameters:
---  * candidateWindows - (optional) a list of candidate windows to consider; if nil, all visible windows to the east are candidates.
---  * frontmost - (optional) boolean, if true unoccluded windows will be placed before occluded ones in the result list
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the eastward axis
---
--- Returns:
---  * A list of `hs.window` objects representing all windows positioned east (i.e. right) of the window, in ascending order of distance
---
--- Notes:
---  * If you don't pass `candidateWindows`, Hammerspoon will query for the list of all visible windows every time this method is called; this can be slow, and some undesired "windows" could be included (see the notes for `hs.window.allWindows()`); consider using the equivalent methods in `hs.window.filter` instead

--- hs.window:windowsToWest([candidateWindows[, frontmost[, strict]]]) -> list of hs.window objects
--- Method
--- Gets all windows to the west of this window
---
--- Parameters:
---  * candidateWindows - (optional) a list of candidate windows to consider; if nil, all visible windows to the west are candidates.
---  * frontmost - (optional) boolean, if true unoccluded windows will be placed before occluded ones in the result list
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the westward axis
---
--- Returns:
---  * A list of `hs.window` objects representing all windows positioned west (i.e. left) of the window, in ascending order of distance
---
--- Notes:
---  * If you don't pass `candidateWindows`, Hammerspoon will query for the list of all visible windows every time this method is called; this can be slow, and some undesired "windows" could be included (see the notes for `hs.window.allWindows()`); consider using the equivalent methods in `hs.window.filter` instead

--- hs.window:windowsToNorth([candidateWindows[, frontmost[, strict]]]) -> list of hs.window objects
--- Method
--- Gets all windows to the north of this window
---
--- Parameters:
---  * candidateWindows - (optional) a list of candidate windows to consider; if nil, all visible windows to the north are candidates.
---  * frontmost - (optional) boolean, if true unoccluded windows will be placed before occluded ones in the result list
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the northward axis
---
--- Returns:
---  * A list of `hs.window` objects representing all windows positioned north (i.e. up) of the window, in ascending order of distance
---
--- Notes:
---  * If you don't pass `candidateWindows`, Hammerspoon will query for the list of all visible windows every time this method is called; this can be slow, and some undesired "windows" could be included (see the notes for `hs.window.allWindows()`); consider using the equivalent methods in `hs.window.filter` instead

--- hs.window:windowsToSouth([candidateWindows[, frontmost[, strict]]]) -> list of hs.window objects
--- Method
--- Gets all windows to the south of this window
---
--- Parameters:
---  * candidateWindows - (optional) a list of candidate windows to consider; if nil, all visible windows to the south are candidates.
---  * frontmost - (optional) boolean, if true unoccluded windows will be placed before occluded ones in the result list
---  * strict - (optional) boolean, if true only consider windows at an angle between 45° and -45° on the southward axis
---
--- Returns:
---  * A list of `hs.window` objects representing all windows positioned south (i.e. down) of the window, in ascending order of distance
---
--- Notes:
---  * If you don't pass `candidateWindows`, Hammerspoon will query for the list of all visible windows every time this method is called; this can be slow, and some undesired "windows" could be included (see the notes for `hs.window.allWindows()`); consider using the equivalent methods in `hs.window.filter` instead

--- hs.window.frontmostWindow() -> hs.window object
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
  for _,ww in ipairs(window.orderedWindows()) do
    local app=ww:application()
    if (app and app:title()~='Hammerspoon') or ww:subrole()~='AXUnknown' then return ww end
  end
end

for n,dir in pairs{['0']='East','North','West','South'}do
  objectMT['windowsTo'..dir]=function(self,...)
    self=self or window.frontmostWindow()
    return self and windowsInDirection(self,n,...)
  end
  objectMT['focusWindow'..dir]=function(self,wins,...)
    self=self or window.frontmostWindow()
    if not self then return end
    if wins==true then -- legacy sameApp parameter
      wins=self:application():visibleWindows()
    end
    return self and focus_first_valid_window(objectMT['windowsTo'..dir](self,wins,...))
  end
  objectMT['moveOneScreen'..dir]=function(self,...) local s=self:screen() return self:moveToScreen(s['to'..dir](s),...) end
end

--- hs.window:focusWindowEast([candidateWindows[, frontmost[, strict]]]) -> boolean
--- Method
--- Focuses the nearest possible window to the east (i.e. right)
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
---    every time this method is called; this can be slow, and some undesired "windows" could be included
---    (see the notes for `hs.window.allWindows()`); consider using the equivalent methods in
---    `hs.window.filter` instead

--- hs.window:focusWindowWest([candidateWindows[, frontmost[, strict]]]) -> boolean
--- Method
--- Focuses the nearest possible window to the west (i.e. left)
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
---    every time this method is called; this can be slow, and some undesired "windows" could be included
---    (see the notes for `hs.window.allWindows()`); consider using the equivalent methods in
---    `hs.window.filter` instead

--- hs.window:focusWindowNorth([candidateWindows[, frontmost[, strict]]]) -> boolean
--- Method
--- Focuses the nearest possible window to the north (i.e. up)
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
---    every time this method is called; this can be slow, and some undesired "windows" could be included
---    (see the notes for `hs.window.allWindows()`); consider using the equivalent methods in
---    `hs.window.filter` instead

--- hs.window:focusWindowSouth([candidateWindows[, frontmost[, strict]]]) -> boolean
--- Method
--- Focuses the nearest possible window to the south (i.e. down)
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
---    every time this method is called; this can be slow, and some undesired "windows" could be included
---    (see the notes for `hs.window.allWindows()`); consider using the equivalent methods in
---    `hs.window.filter` instead


--- hs.window:centerOnScreen([screen][, ensureInScreenBounds][, duration]) --> hs.window object
--- Method
--- Centers the window on a screen
---
--- Parameters:
---  * screen - (optional) An `hs.screen` object or argument for `hs.screen.find`; if nil, use the screen the window is currently on
---  * ensureInScreenBounds - (optional) if `true`, use `setFrameInScreenBounds()` to ensure the resulting window frame is fully contained within
---    the window's screen
---  * duration - (optional) The number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function objectMT.centerOnScreen(self, toScreen,inBounds,duration)
  if type(toScreen)=='boolean' then duration=inBounds inBounds=toScreen toScreen=nil
  elseif type(toScreen)=='number' then duration=toScreen inBounds=nil toScreen=nil end
  if type(inBounds)=='number' then duration=inBounds inBounds=nil end
  toScreen=screen.find(toScreen) or self:screen()
  local sf,wf=toScreen:fullFrame(),self:frame()
  local frame=geometry(toScreen:localToAbsolute((geometry(sf.w,sf.h)-geometry(wf.w,wf.h))*0.5),wf.size)
  if inBounds then return self:setFrameInScreenBounds(frame,duration)
  else return self:setFrame(frame,duration) end
end

--- hs.window:moveToUnit(unitrect[, duration]) -> hs.window object
--- Method
--- Moves and resizes the window to occupy a given fraction of the screen
---
--- Parameters:
---  * unitrect - An `hs.geometry` unit rect, or constructor argument to create one
---  * duration - (optional) The number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
---
--- Notes:
---  * An example, which would make a window fill the top-left quarter of the screen: `win:moveToUnit'[0,0,50,50]'`
function objectMT.moveToUnit(self, unit, duration)
  return self:setFrame(self:screen():fromUnitRect(unit),duration)
end

--- hs.window:moveToScreen(screen[, noResize, ensureInScreenBounds][, duration]) -> hs.window object
--- Method
--- Moves the window to a given screen, retaining its relative position and size
---
--- Parameters:
---  * screen - An `hs.screen` object, or an argument for `hs.screen.find()`, representing the screen to move the window to
---  * noResize - (optional) if `true`, maintain the window's absolute size
---  * ensureInScreenBounds - (optional) if `true`, use `setFrameInScreenBounds()` to ensure the resulting window frame is fully contained within
---    the window's screen
---  * duration - (optional) The number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function objectMT.moveToScreen(self, toScreen,noResize,inBounds,duration)
  if not toScreen then return end
  local theScreen=screen.find(toScreen)
  if not theScreen then print('window:moveToScreen(): screen not found: '..toScreen) return self end
  if type(noResize)=='number' then duration=noResize noResize=nil inBounds=nil end
  local frame=theScreen:fromUnitRect(self:screen():toUnitRect(self:frame()))
  if noResize then frame.size=self:size() end
  --    local frame=theScreen:localToAbsolute(self:screen():absoluteToLocal(self:frame()))
  if inBounds then return self:setFrameInScreenBounds(frame,duration)
  else return self:setFrame(frame,duration) end
  --  else return self:setFrame(theScreen:fromUnitRect(self:screen():toUnitRect(self:frame())),duration) end
end

--- hs.window:move(rect[, screen][, ensureInScreenBounds][, duration]) --> hs.window object
--- Method
--- Moves the window
---
--- Parameters:
---  * rect - It can be:
---    - an `hs.geometry` point, or argument to construct one; will move the screen by this delta, keeping its size constant; `screen` is ignored
---    - an `hs.geometry` rect, or argument to construct one; will set the window frame to this rect, in absolute coordinates; `screen` is ignored
---    - an `hs.geometry` unit rect, or argument to construct one; will set the window frame to this rect relative to the desired screen;
---      if `screen` is nil, use the screen the window is currently on
---  * screen - (optional) An `hs.screen` object or argument for `hs.screen.find`; only valid if `rect` is a unit rect
---  * ensureInScreenBounds - (optional) if `true`, use `setFrameInScreenBounds()` to ensure the resulting window frame is fully contained within
---    the window's screen
---  * duration - (optional) The number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object
function objectMT.move(self, rect,toScreen,inBounds,duration)
  if type(toScreen)=='boolean' then duration=inBounds inBounds=toScreen toScreen=nil
  elseif type(toScreen)=='number' then duration=toScreen inBounds=nil toScreen=nil end
  if type(inBounds)=='number' then duration=inBounds inBounds=nil end
  rect=geometry(rect)
  local rtype,frame=rect:type()
  if rtype=='point' then frame=geometry(self:frame()):move(rect)
    if type(toScreen)=='number' then inBounds=nil duration=toScreen end
  elseif rtype=='rect' then frame=rect
    if type(toScreen)=='number' then inBounds=nil duration=toScreen end
  elseif rtype=='unitrect' then
    local theScreen
    if toScreen then
      theScreen=screen.find(toScreen)
      if not theScreen then print('window:move(): screen not found: '..toScreen) return self end
    else theScreen=self:screen() end
    frame=rect:fromUnitRect(theScreen:frame())
  else error('rect must be a point, rect, or unit rect',2) end
  if inBounds then return self:setFrameInScreenBounds(frame,duration)
  else return self:setFrame(frame,duration) end
end

--- hs.window:moveOneScreenEast([noResize, ensureInScreenBounds][, duration]) -> hs.window object
--- Method
--- Moves the window one screen east (i.e. right)
---
--- Parameters:
---  * noResize - (optional) if `true`, maintain the window's absolute size
---  * ensureInScreenBounds - (optional) if `true`, use `setFrameInScreenBounds()` to ensure the resulting window frame is fully contained within
---    the window's screen
---  * duration - (optional) The number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object

--- hs.window:moveOneScreenWest([noResize, ensureInScreenBounds][, duration]) -> hs.window object
--- Method
--- Moves the window one screen west (i.e. left)
---
--- Parameters:
---  * noResize - (optional) if `true`, maintain the window's absolute size
---  * ensureInScreenBounds - (optional) if `true`, use `setFrameInScreenBounds()` to ensure the resulting window frame is fully contained within
---    the window's screen
---  * duration - (optional) The number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object

--- hs.window:moveOneScreenNorth([noResize, ensureInScreenBounds][, duration]) -> hs.window object
--- Method
--- Moves the window one screen north (i.e. up)
---
---
--- Parameters:
---  * noResize - (optional) if `true`, maintain the window's absolute size
---  * ensureInScreenBounds - (optional) if `true`, use `setFrameInScreenBounds()` to ensure the resulting window frame is fully contained within
---    the window's screen
---  * duration - (optional) The number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object

--- hs.window:moveOneScreenSouth([noResize, ensureInScreenBounds][, duration]) -> hs.window object
--- Method
--- Moves the window one screen south (i.e. down)
---
---
--- Parameters:
---  * noResize - (optional) if `true`, maintain the window's absolute size
---  * ensureInScreenBounds - (optional) if `true`, use `setFrameInScreenBounds()` to ensure the resulting window frame is fully contained within
---    the window's screen
---  * duration - (optional) The number of seconds to animate the transition. Defaults to the value of `hs.window.animationDuration`
---
--- Returns:
---  * The `hs.window` object

do
  local submodules={filter=true,layout=true,tiling=true,switcher=true,highlight=true}
  local function loadSubModule(k)
    print("-- Loading extensions: window."..k)
    window[k]=require('hs.window.'..k)
    return window[k]
  end
  local mt=getmetatable(window)
  --inject "lazy loading" for submodules
  mt.__index=function(_,k)
    if submodules[k] then
        return loadSubModule(k)
    else
        return nil -- if it's already in the module, __index is never called
    end
  end
  -- whoever gets it first (window vs application)
  if not mt.__call then mt.__call=function(t,...) return t.find(...) end end
end

return window
