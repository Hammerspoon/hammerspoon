--- === hs.window.highlight ===
---
--- Highlight the focused window
---
--- This module can be useful to spatially keep track of windows if you have large and/or multiple screens, and are
--- therefore likely to have several windows visible at any given time.
--- It highlights the currently focused window by covering other windows and the desktop with either a subtle
--- ("overlay" mode) or opaque ("isolate" mode) overlay; additionally it can highlight windows as they're shown
--- or hidden via a brief flash, to help determine their location intuitively (to avoid having to studiously scan
--- all your screens when, for example, you know you triggered a dialog but it didn't show up where you expected it).
---
--- By default, overlay mode is disabled - you can enable it with `hs.window.highlight.ui.overlay=true` - and so are
--- the window shown/hidden flashes - enable those with `hs.window.highlight.ui.flashDuration=0.3` (or whatever duration
--- you prefer). Isolate mode is always available and can be toggled manually via `hs.window.highlight.toggleIsolate()`
--- or automatically by passing an appropriate windowfilter (or a list of apps) to `hs.window.highlight.start()`.

local screen=require'hs.screen'
local timer=require'hs.timer'
local window=require'hs.window'
local windowfilter=require'hs.window.filter'
local redshift=require'hs.redshift'
local settings=require'hs.settings'
local log=hs.logger.new('highlight')
local drrect = hs.drawing.rectangle
local type,ipairs=type,ipairs

local highlight={setLogLevel=log.setLogLevel,getLogLevel=log.getLogLevel}

--local frames={} -- cached
local focusedWin,sf,frame,rt,rl,rb,rr,rflash
local BEHAVIOR=9
local SETTING_ISOLATE_OVERRIDE='hs.window.highlight.isolate.override'

--- hs.window.highlight.ui
--- Variable
--- Allows customization of the highlight overlays and behaviour.
---
--- The default values are shown in the right hand side of the assignements below.
---
--- To represent color values, you can use:
---  * a table {red=redN, green=greenN, blue=blueN, alpha=alphaN}
---  * a table {redN,greenN,blueN[,alphaN]} - if omitted alphaN defaults to 1.0
--- where redN, greenN etc. are the desired value for the color component between 0.0 and 1.0
---
--- Color inversion is governed by the module `hs.redshift`. See the relevant documentation for more information.
---
---  * `hs.window.highlight.ui.overlay = false` - draw overlay over the area of the screen(s) that isn't occupied by the focused window
---  * `hs.window.highlight.ui.overlayColor = {0.2,0.05,0,0.25}` - overlay color
---  * `hs.window.highlight.ui.overlayColorInverted = {0.8,0.9,1,0.3}` - overlay color when colors are inverted
---  * `hs.window.highlight.ui.isolateColor = {0,0,0,0.95}` - overlay color for isolate mode
---  * `hs.window.highlight.ui.isolateColorInverted = {1,1,1,0.95}` - overlay color for isolate mode when colors are inverted
---  * `hs.window.highlight.ui.frameWidth = 10` - draw a frame around the focused window in overlay mode; 0 to disable
---  * `hs.window.highlight.ui.frameColor = {0,0.6,1,0.5}` - frame color
---  * `hs.window.highlight.ui.frameColorInvert = {1,0.4,0,0.5}`
---  * `hs.window.highlight.ui.flashDuration = 0` - duration in seconds of a brief flash over windows as they're shown/hidden;
---    disabled if 0; if desired, 0.3 is a good value
---  * `hs.window.highlight.ui.windowShownFlashColor = {0,1,0,0.8}` - flash color when a window is shown (created or unhidden)
---  * `hs.window.highlight.ui.windowHiddenFlashColor = {1,0,0,0.8}` - flash color when a window is hidden (destroyed or hidden)
---  * `hs.window.highlight.ui.windowShownFlashColorInvert = {1,0,1,0.8}`
---  * `hs.window.highlight.ui.windowHiddenFlashColorInvert = {0,1,1,0.8}`
local uiGlobal = {
  frameColor={0,0.6,1,0.5},
  frameColorInvert={1,0.4,0,0.5},
  frameWidth=0,
  overlay=false, --disabled
  overlayColor={0.2,0.05,0,0.25},
  overlayColorInvert={0.8,0.9,1,0.3},
  isolateColor={0,0,0,0.95},
  isolateColorInvert={1,1,1,0.95},
  windowShownFlashColor={0,1,0,0.8},
  windowHiddenFlashColor={1,0,0,0.8},
  windowShownFlashColorInvert={1,0,1,0.8},
  windowHiddenFlashColorInvert={0,1,1,0.8},
  flashDuration=0, -- disabled
}
local function getColor(t) if type(t)~='table' or t.red or not t[1] then return t else return {red=t[1] or 0,green=t[2] or 0,blue=t[3] or 0,alpha=t[4] or 1} end end

local function getScreens()
  local screens=screen.allScreens()
  if #screens==0 then log.w('Cannot get current screens') return end
  sf=screens[1]:fullFrame()
  for i=2,#screens do
    local fr=screens[i]:frame()
    if fr.x<sf.x then sf.x=fr.x end
    if fr.y<sf.y then sf.y=fr.y end
    if fr.x2>sf.x2 then sf.x2=fr.x2 end
    if fr.y2>sf.y2 then sf.y2=fr.y2 end
  end
end

local hasFrame,hasOverlay,hasFlash

local tflash=timer.delayed.new(0.3,function()rflash:hide()end)


local function hideFrame()
  frame:hide() rt:hide() rl:hide() rb:hide() rr:hide()
  --  for _,r in ipairs{rt,rl,rb,rr} do if r then r:hide() end end
end

local invert,isolateAuto,isolateUser,isolate
local function drawFrame() -- draw an overlay around a window
  if not focusedWin then return end
  local f=focusedWin:frame() -- frames[focusedWin:id()]=f
  if not isolate and hasFrame then frame:setFrame(f):show() end
  -- decided against leaving a passive-aggressive comment mentioning the lack of
  -- hs.geometry wrapping for :setFrame(), because yay performance!
  rt:setFrame{x=sf.x,y=sf.y,w=f.x+f.w-sf.x,h=f.y-sf.y}:show()
  rl:setFrame{x=sf.x,y=f.y,w=f.x-sf.x,h=sf.h-f.y+sf.y}:show()
  rb:setFrame{x=f.x,y=f.y+f.h,w=sf.w-f.x,h=sf.h-f.y-f.h+sf.y}:show()
  rr:setFrame{x=f.x+f.w,y=sf.y,w=sf.w-f.x-f.w,h=f.y+f.h-sf.y}:show()
end

local function flash(win,shown)
  local k='window'..(shown and 'Shown' or 'Hidden')..'FlashColor'..(invert and 'Invert' or '')
  local f=win:frame()
  rflash:setFrame(f):setFillColor(highlight.ui[k]):show()
  tflash:start()
end

local wfFlash,wfOverlay,wfIsolate,modulewfIsolate
local flashsubs={
  [windowfilter.windowVisible]=function(w)flash(w,true)  end,
  [windowfilter.windowNotVisible]=function(w)flash(w,false) end,
}
local focusedsubs={
  [windowfilter.windowFocused]=function(w)focusedWin=w return drawFrame() end,
  [windowfilter.windowMoved]=function(w)if w==focusedWin then return drawFrame() end end,
  [windowfilter.windowUnfocused]=function()focusedWin=nil return hideFrame() end,
}
local running

local function setMode()
  if not running then return end
  hideFrame()
  local over,overinv=highlight.ui.overlayColor,highlight.ui.overlayColorInvert
  local isol,isolinv=highlight.ui.isolateColor,highlight.ui.isolateColorInvert
  for _,r in ipairs{rt,rl,rb,rr} do
    r:setFillColor(invert and (isolate and isolinv or overinv) or (isolate and isol or over))
  end
  frame:setStrokeColor(invert and highlight.ui.frameColorInvert or highlight.ui.frameColor)
  if isolate or hasOverlay then
    wfOverlay:subscribe(focusedsubs)
    local w=window.focusedWindow()
    if w then focusedsubs[windowfilter.windowFocused](w) end
  else wfOverlay:unsubscribe(focusedsubs) end
  if hasFlash then wfFlash:subscribe(flashsubs)
  else wfFlash:unsubscribe(flashsubs) end
end

local function setInvert(v)
  if invert~=v then log.f('inverted mode %s',v and 'on' or 'off') end
  invert=v return setMode()
end

local function setIsolate()
  local v=isolateUser
  if v==nil then v=isolateAuto end
  if isolate~=v then
    log.f('isolate mode %s',v and 'on' or 'off')
    isolate=v return setMode()
  end
end

local isolatesubs={
  [windowfilter.windowFocused]=function(w)focusedWin=w isolateAuto=true setIsolate() return drawFrame() end,
  [windowfilter.windowMoved]=function(w)if w==focusedWin then return drawFrame() end end,
  [windowfilter.windowUnfocused]=function()focusedWin=nil isolateAuto=nil setIsolate() return hideFrame() end,
}

local function setUiPrefs()
  local prevOverlay,prevFlash=hasOverlay,hasFlash
  if frame then
    if next(frame) ~= nil then
      frame:delete() rt:delete() rl:delete() rb:delete() rr:delete() rflash:delete()
    end
  end
  local ui=highlight.ui
  local f={x=-5,y=0,w=1,h=1}
  frame=drrect(f):setFill(false):setStroke(true):setStrokeWidth(ui.frameWidth):setBehavior(BEHAVIOR)
  local function make() return drrect(f):setFill(true):setStroke(false):setBehavior(BEHAVIOR) end
  rt,rl,rb,rr=make(),make(),make(),make()
  rflash=drrect(f):setFill(true):setStroke(false):setBehavior(BEHAVIOR)
  hasFrame=ui.frameColor.alpha>0 and ui.frameWidth>0
  hasOverlay=ui.overlay and ui.overlayColor.alpha>0
  hasFlash=ui.flashDuration>0 and (ui.windowShownFlashColor.alpha>0 or ui.windowHiddenFlashColor.alpha>0)
  if hasFlash then tflash:setDelay(ui.flashDuration) end
  if hasOverlay~=prevOverlay then log.i('overlay mode',hasOverlay and 'enabled' or 'disabled') end
  if hasFlash~=prevFlash then log.i('flash',hasFlash and 'enabled' or 'disabled') end
  return setMode()
end
highlight.ui=setmetatable({},{
  __newindex=function(_,k,v) uiGlobal[k]=getColor(v) setUiPrefs() end,
  __index=function(_,k)return getColor(uiGlobal[k])end,
})


--- hs.window.highlight.toggleIsolate([v])
--- Function
--- Sets or clears the user override for "isolate" mode.
---
--- Parameters:
---  * v - (optional) a boolean; if true, enable isolate mode; if false, disable isolate mode,
---    even when `windowfilterIsolate` passed to `.start()` would otherwise enable it; if omitted or nil,
---    toggle the override, i.e. clear it if it's currently enforced, or set it to the opposite of the current
---    isolate mode status otherwise.
---
--- Returns:
---  * None
---
--- Notes:
---  * This function should be bound to a hotkey, e.g.: `hs.hotkey.bind('ctrl-cmd','\','Isolate',hs.window.highlight.toggleIsolate)`
function highlight.toggleIsolate(v)
  if not running then return end
  if v==nil and isolateUser==nil then v=not isolate end
  isolateUser=v
  log.f('isolate user override%s',v==true and ': isolated' or (v==false and ': not isolated' or ' cancelled'))
  if v==nil then settings.clear(SETTING_ISOLATE_OVERRIDE)
  else settings.set(SETTING_ISOLATE_OVERRIDE,v) end
  return setIsolate()
end


local screenWatcher
--- hs.window.highlight.start([windowfilterIsolate[, windowfilterOverlay]])
--- Function
--- Starts the module
---
--- Parameters:
---  * windowfilterIsolate - (optional) an `hs.window.filter` instance that automatically enable "isolate" mode
---    whenever one of the allowed windows is focused; alternatively, you can just provide a list of application
---    names and a windowfilter will be created for you that enables isolate mode whenever one of these apps is focused;
---    if omitted or nil, isolate mode won't be toggled automatically, but you can still toggle it manually via
---    `hs.window.higlight.toggleIsolate()`
---  * windowfilterOverlay - (optional) an `hs.window.filter` instance that determines which windows to consider
---    for "overlay" mode when focused; if omitted or nil, the default windowfilter will be used
---
--- Returns:
---  * None
---
--- Notes:
---  * overlay mode is disabled by default - see `hs.window.highlight.ui.overlayColor`
function highlight.start(wfis,wfov)
  highlight.stop()
  running=true
  if wfov==nil then wfov=windowfilter.default else wfov=windowfilter.new(wfov) end

  wfFlash=wfov
  wfOverlay=windowfilter.copy(wfov,'wf-highlight'):setOverrideFilter{focused=true}
  screenWatcher=screen.watcher.new(getScreens):start()
  log.i'started'
  getScreens()
  isolateUser=settings.get(SETTING_ISOLATE_OVERRIDE)
  setIsolate()
  setUiPrefs()
  redshift.invertSubscribe(setInvert)
  if wfis~=nil then
    if windowfilter.iswf(wfis) then wfIsolate=wfis
    else
      wfIsolate=windowfilter.new(wfis,'wf-redshift-isolate',log.getLogLevel())
      modulewfIsolate=wfIsolate
      if type(wfis=='table') then
        local isAppList=true
        for k,v in pairs(wfis) do
          if type(k)~='number' or type(v)~='string' then isAppList=false break end
        end
        if isAppList then wfIsolate:setOverrideFilter{focused=true} end
      end
    end
    wfIsolate:subscribe(isolatesubs,true)
  end
end


--- hs.window.highlight.stop()
--- Function
--- Stops the module and disables focused window highlighting (both "overlay" and "isolate" mode)
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function highlight.stop()
  if not running then return end
  log.i'stopped'
  if frame then frame:delete() rt:delete() rl:delete() rb:delete() rr:delete() rflash:delete() end
  running=nil
  wfOverlay:delete() wfOverlay=nil
  wfFlash:unsubscribe(flashsubs)
  redshift.invertUnsubscribe(setInvert)

  if wfIsolate then
    if modulewfIsolate then modulewfIsolate:delete() modulewfIsolate=nil
    else wfIsolate:unsubscribe(isolatesubs) end
    wfIsolate=nil
  end

  screenWatcher:stop()
  --  focusedwf:delete()
end
--return highlight
return setmetatable(highlight,{__gc=highlight.stop})
