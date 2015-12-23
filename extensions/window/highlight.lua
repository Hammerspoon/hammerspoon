--- highlight focused window
local screen=require'hs.screen'
local timer=require'hs.timer'
local window=require'hs.window'
local windowfilter=require'hs.window.filter'
local redshift=require'hs.redshift'
local log=hs.logger.new('highlight',3)
local drrect = hs.drawing.rectangle
local type,ipairs=type,ipairs

local highlight={setLogLevel=log.setLogLevel,getLogLevel=log.getLogLevel}

--local frames={} -- cached
local focusedWin,sf,frame,rt,rl,rb,rr,rflash
local BEHAVIOR=9

local uiGlobal = {
  strokeColor={0,0.6,1,0.5},
  strokeColorInvert={1,0.4,0,0.5},
  strokeWidth=10,
  overlayColor={0.2,0.05,0,0.25},
  overlayColorInvert={0.8,0.9,1,0.3},
  isolateColor={0,0,0,0.95},
  isolateColorInvert={1,1,1,0.95},
  windowShownFlashColor={0,1,0,0.8},
  windowHiddenFlashColor={1,0,0,0.8},
  windowShownFlashColorInvert={1,0,1,0.8},
  windowHiddenFlashColorInvert={0,1,1,0.8},
  flashDuration=0.3,
}
local function getColor(t) if type(t)~='table' or t.red or not t[1] then return t else return {red=t[1] or 0,green=t[2] or 0,blue=t[3] or 0,alpha=t[4] or 1} end end

local function getScreens()
  local screens=screen.allScreens()
  if #screens==0 then log.w('Cannot get current screens') return end
  sf=screens[1]:frame()
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

local function setUiPrefs()
  if frame then frame:delete() rt:delete() rl:delete() rb:delete() rr:delete() rflash:delete() end
  local ui=highlight.ui
  local f={x=-5,y=0,w=1,h=1}
  frame=drrect(f):setFill(false):setStrokeWidth(ui.strokeWidth):setStrokeColor(ui.strokeColor):setBehavior(BEHAVIOR)
  local function make() return drrect(f):setFill(true):setFillColor(ui.overlayColor):setStroke(false):setBehavior(BEHAVIOR) end
  rt,rl,rb,rr=make(),make(),make(),make()
  rflash=drrect(f):setFill(true):setStroke(false):setBehavior(BEHAVIOR)
  hasFrame=ui.strokeColor.alpha>0
  hasOverlay=ui.overlayColor.alpha>0
  hasFlash=ui.flashDuration>0 and (ui.windowShownFlashColor.alpha>0 or ui.windowHiddenFlashColor.alpha>0)
  if hasFlash then tflash:setDelay(ui.flashDuration) end
end
highlight.ui=setmetatable({},{
  __newindex=function(t,k,v) uiGlobal[k]=getColor(v) setUiPrefs() end,
  __index=function(t,k)return getColor(uiGlobal[k])end,
})

local function hideFrame()
  frame:hide() rt:hide() rl:hide() rb:hide() rr:hide()
  --  for _,r in ipairs{rt,rl,rb,rr} do if r then r:hide() end end
end

local invert,isolate
local function drawFrame() -- draw an overlay around a window
  if not focusedWin then return end
  local f=focusedWin:frame() -- frames[focusedWin:id()]=f
  if not isolate then frame:setFrame(f):show() end
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

local flashwf,focusedwf
local flashsubs={
  [windowfilter.windowVisible]=function(w)flash(w,true)  end,
  [windowfilter.windowNotVisible]=function(w)flash(w,false) end,
}
local focusedsubs={
  --  [hs.window.filter.windowFocused]=function(w)focusedWin=w drawTimer:start() end,
  --  [hs.window.filter.windowMoved]=function(w)focusedWin=w drawTimer:start() end,
  --  [hs.window.filter.windowUnfocused]=function()drawTimer:stop() focusedWin=nil return hideFrame() end,
  [windowfilter.windowFocused]=function(w)focusedWin=w return drawFrame() end,
  [windowfilter.windowMoved]=function(w)if w==focusedWin then return drawFrame() end end,
  [windowfilter.windowUnfocused]=function()focusedWin=nil return hideFrame() end,
}

local function setMode()
  hideFrame()
  local over,overinv=highlight.ui.overlayColor,highlight.ui.overlayColorInvert
  local isol,isolinv=highlight.ui.isolateColor,highlight.ui.isolateColorInvert
  for _,r in ipairs{rt,rl,rb,rr} do
    r:setFillColor(invert and (isolate and isolinv or overinv) or (isolate and isol or over))
  end
  frame:setStrokeColor(invert and highlight.ui.strokeColorInvert or highlight.ui.strokeColor)
  if isolate or hasOverlay then
    focusedwf:subscribe(focusedsubs)
    local w=window.focusedWindow()
    if w then focusedsubs[windowfilter.windowFocused](w) end
  else focusedwf:unsubscribe(focusedsubs) end
  if hasFlash then flashwf:subscribe(flashsubs)
  else flashwf:unsubscribe(flashsubs) end
end

local function setInvert(v)
  if invert~=v then log.f('inverted mode %s',v and 'on' or 'off') end
  invert=v return setMode()
end

local function setIsolate(v)
  if v==nil then v=not isolate end
  if isolate~=v then log.f('isolator mode %s',v and 'on' or 'off') end
  isolate=v return setMode()
end

local running
function highlight.toggleIsolate(v)
  if not running then return end
  if v==nil then v=not isolate end
  return setIsolate(v)
end


local screenWatcher
function highlight.start(wf)
  highlight.stop()
  running=true
  if wf==nil then log.i('window highlight started, using default windowfilter') wf=windowfilter.default
  else log.i('window highlight started using windowfilter instance') wf=windowfilter.new(wf) end

  screenWatcher=screen.watcher.new(getScreens):start()
  flashwf=wf
  focusedwf=windowfilter.copy(wf,'wf-highlight'):setOverrideFilter{focused=true}
  getScreens()
  setUiPrefs()
  setMode()
  redshift.invertSubscribe(setInvert)
end


function highlight.stop()
  if not running then return end
  log.i'stopped'
  running=nil
  focusedwf:unsubscribe(focusedsubs)
  flashwf:unsubscribe(flashsubs)
  redshift.invertUnsubscribe(setInvert)
  hideFrame()
  screenWatcher:stop()
  --  focusedwf:delete()
end
--return highlight
return setmetatable(highlight,{__gc=highlight.stop})


