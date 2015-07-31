--- === hs.expose ===
---
--- **WARNING**: This module depends on the EXPERIMENTAL hs.windowfilter. It can undergo breaking API changes or *go away entirely* **at any point and without notice**.
--- (Should you encounter any issues, please feel free to report them on https://github.com/Hammerspoon/hammerspoon/issues
--- or #hammerspoon on irc.freenode.net)
---
--- Keyboard-driven expose replacement/enhancement
---
--- Usage:
--- -- set up your windowfilter
--- expose = hs.expose.new() -- default windowfilter: only visible windows, all Spaces
--- expose2 = hs.expose.new(hs.windowfilter.new():trackSpaces(true):setDefaultFilter()) -- include minimized/hidden windows, current Space only
--- expose_browsers = hs.expose.new{'Safari','Google Chrome'} -- specialized expose for your dozens of browser windows :)
---
--- -- then bind to a hotkey
--- hs.hotkey.bind('ctrl-cmd','e',function()expose:toggleShow()end)



--TODO /// hs.drawing:setClickCallback(fn) -> drawingObject
--TODO showExtraKeys


local expose={} --module


local drawing=require'hs.drawing'
local windowfilter=require'hs.windowfilter'
local window,screen=require'hs.window',require'hs.screen'
local spaces=require'hs.spaces'
local eventtap=require'hs.eventtap'
local log=require'hs.logger'.new('expose')
expose.setLogLevel=log.setLogLevel
local newmodal=require'hs.hotkey'.modal.new
local tinsert,tremove,min,max,ceil,abs,fmod,floor=table.insert,table.remove,math.min,math.max,math.ceil,math.abs,math.fmod,math.floor
local next,type,ipairs,pairs,setmetatable,sformat,supper,ssub,tostring=next,type,ipairs,pairs,setmetatable,string.format,string.upper,string.sub,tostring

local rect = {} -- a centered rect class (more handy for our use case)
rect.new = function(r)
  local o = setmetatable({},{__index=rect})
  o.x=r.x+r.w/2 o.y=r.y+r.h/2 o.w=r.w o.h=r.h
  return o
end
function rect:scale(factor)
  self.w=self.w*factor self.h=self.h*factor
end
function rect:move(dx,dy)
  self.x=self.x+dx self.y=self.y+dy
end
function rect:tohs()
  return {x=self.x-self.w/2,y=self.y-self.h/2,w=self.w,h=self.h}
end
function rect:intersect(r2)
  local r1,x,y,w,h=self
  if r1.x<r2.x then x=r2.x-r2.w/2 w=r1.x+r1.w/2-x
  else x=r1.x-r1.w/2 w=r2.x+r2.w/2-x end
  if r1.y<r2.y then y=r2.y-r2.h/2 h=r1.y+r1.h/2-y
  else y=r1.y-r1.h/2 h=r2.y+r2.h/2-y end
  return rect.new({x=x,y=y,w=w,h=h})
end
function rect:fit(frame)
  if self.w>frame.w then self:scale(frame.w/self.w) end
  if self.h>frame.h then self:scale(frame.h/self.h) end
  self.x=max(self.x,frame.x+self.w/2)
  self.x=min(self.x,frame.x+frame.w-self.w/2)
  self.y=max(self.y,frame.y+self.h/2)
  self.y=min(self.y,frame.y+frame.h-self.h/2)
end
function rect:toString()
  return sformat('%d,%d %dx%d',self.x,self.y,self.w,self.h)
end

local function isAreaEmpty(rect,windows,screenFrame)
  if rect.x-rect.w/2<screenFrame.x or rect.x+rect.w/2>screenFrame.w+screenFrame.x
    or rect.y-rect.h/2<screenFrame.y or rect.y+rect.h/2>screenFrame.h+screenFrame.y then return end
  for i,win in ipairs(windows) do
    local i = win.frame:intersect(rect)
    if i.w>0 and i.h>0 then return end
  end
  return true
end


local function fitWindows(windows,maxIterations,animate,alt_algo)
  local screenFrame = windows.frame
  local avgRatio = min(1,screenFrame.w*screenFrame.h/windows.area*2)
  log.vf('shrink %d windows to %.0f%%',#windows,avgRatio*100)
  for i,win in ipairs(windows) do
    win.frame:scale(avgRatio)
    win.frame:fit(screenFrame)
  end
  local didwork = true
  local iterations = 0
  local screenArea=screenFrame.w*screenFrame.h
  local screenCenter=rect.new(screenFrame)

  while didwork and iterations<maxIterations do
    didwork=false
    iterations=iterations+1
    local thisAnimate=animate and floor(math.sqrt(iterations))
    local totalOverlaps = 0
    local totalRatio=0
    for i,win in ipairs(windows) do
      local winRatio = win.frame.w*win.frame.h/win.area
      totalRatio=totalRatio+winRatio
      -- log.vf('processing %s - %s',win.appname,win.frame:toString())
      local overlapAreaTotal = 0
      local overlaps={}

      for j,win2 in ipairs(windows) do
        if j~=i then
          --log.vf('vs %s %s',win2.appname,win2.frame:toString())
          local intersection = win.frame:intersect(win2.frame)
          local area = intersection.w*intersection.h
          --log.vf('intersection %s [%d]',intersection:toString(),area)
          if intersection.w>1 and intersection.h>1 then
            --log.vf('vs %s intersection %s [%d]',win2.appname,intersection:toString(),area)
            overlapAreaTotal=overlapAreaTotal+area
            overlaps[#overlaps+1] = intersection
            if area*0.9>win.frame.w*win.frame.h then
              overlaps[#overlaps].x=(win.frame.x+win2.frame.x)/2
              overlaps[#overlaps].y=(win.frame.y+win2.frame.y)/2
            end
          end
        end
      end

      totalOverlaps=totalOverlaps+#overlaps
      -- find the overlap regions center
      if #overlaps>0 then
        didwork=true
        local ax,ay=0,0
        for _,ov in ipairs(overlaps) do
          local weight = ov.w*ov.h/overlapAreaTotal
          ax=ax+ weight*(ov.x)
          ay=ay+ weight*(ov.y)
        end
        ax=(win.frame.x-ax)*overlapAreaTotal/screenArea*3 ay=(win.frame.y-ay)*overlapAreaTotal/screenArea*3
        win.frame:move(ax,ay)
        if winRatio/avgRatio>0.8 then win.frame:scale(alt_algo and 0.95 or 0.98) end
        win.frame:fit(screenFrame)
      elseif alt_algo then
        -- scale back up
        win.frame:scale(1.05)
        win.frame:fit(screenFrame)
      end
      if totalOverlaps>0 and avgRatio<0.9 and not alt_algo then
        local DISPLACE=5
        for dx = -DISPLACE,DISPLACE,DISPLACE*2 do
          if win.frame.x>screenCenter.x then dx=-dx end
          local r = {x=win.frame.x+win.frame.w/(dx<0 and -2 or 2)+dx,y=win.frame.y,w=abs(dx)*2-1,h=win.frame.h}
          if isAreaEmpty(r,windows,screenFrame) then
            win.frame:move(dx,0)
            if winRatio/avgRatio<1.33 and winRatio<1 then win.frame:scale(1.01)end
            didwork=true
            break
          end
        end
        for dy = -DISPLACE,DISPLACE,DISPLACE*2 do
          if win.frame.y>screenCenter.y then dy=-dy end
          local r = {y=win.frame.y+win.frame.h/(dy<0 and -2 or 2)+dy,x=win.frame.x,h=abs(dy)*2-1,w=win.frame.w}
          if isAreaEmpty(r,windows,screenFrame) then
            win.frame:move(0,dy)
            if winRatio/avgRatio<1.33 and winRatio<1 then win.frame:scale(1.01)end
            didwork=true
            break
          end
        end
      end
      if thisAnimate and thisAnimate>animate then
        win.thumb:setFrame(win.frame:tohs())
      end
    end
    avgRatio=totalRatio/#windows
    local totalArea=0
    for i,win in ipairs(windows) do
      totalArea=totalArea+win.frame.w*win.frame.h
    end
    local halting=iterations==maxIterations
    if not didwork or halting then
      log.vf('%s (%d iterations): coverage %.2f%% (%d overlaps)',halting and 'halted' or 'optimal',iterations,totalArea/(screenFrame.w*screenFrame.h)*100,totalOverlaps)
    end
    animate=animate and thisAnimate
  end
end

local ui = {
  textColor={1,1,1},
  fontName='Lucida Grande',
  textSize=40,
  hintLetterWidth=35,

  backgroundColor={0.3,0.3,0.3,0.95},
  closeModeBackgroundColor={0.7,0.1,0.1,0.95},
  minimizeModeBackgroundColor={0.1,0.3,0.6,0.95},
  minimizedStripBackgroundColor={0.15,0.15,0.15,0.95},
  minimizedStripWidth=200,

  fadeColor={0,0,0,0.8},
  fadeStrokeColor={0,0,0},
  highlightColor={0.8,0.5,0,0.1},
  highlightStrokeColor={0.8,0.5,0,0.8},
  strokeWidth=10,

  showExtraKeys=true,

  closeModeModifier = 'shift',
  minimizeModeModifier = 'alt',

  maxHintLetters = 2,
}
--- === hs.expose.ui ===
---
--- Allows customization of the expose user interface
---
--- This table contains variables that you can change to customize the look of the UI. The default values are shown in the right hand side of the assignements below.
---
--- To represent color values, you can use:
---  * a table {red=redN, green=greenN, blue=blueN, alpha=alphaN}
---  * a table {redN,greenN,blueN[,alphaN]} - if omitted alphaN defaults to 1.0
--- where redN, greenN etc. are the desired value for the color component between 0.0 and 1.0
---
--- The following variables must be color values:
---  * `hs.expose.ui.backgroundColor = {0.3,0.3,0.3,0.95}`
---  * `hs.expose.ui.closeModeBackgroundColor = {0.7,0.1,0.1,0.95}`
---  * `hs.expose.ui.minimizeModeBackgroundColor = {0.1,0.3,0.6,0.95}`
---  * `hs.expose.ui.minimizedStripBackgroundColor = {0.15,0.15,0.15,0.95}` -- this is the strip alongside your dock that contains thumbnails for non-visible windows
---  * `hs.expose.ui.highlightColor = {0.8,0.5,0,0.1}` -- highlight candidate thumbnails when pressing a hint key
---  * `hs.expose.ui.highlightStrokeColor = {0.8,0.5,0,0.8}`
---  * `hs.expose.ui.fadeColor = {0,0,0,0.8}` -- fade excluded thumbnails when pressing a hint key
---  * `hs.expose.ui.fadeStrokeColor = {0,0,0}`
---  * `hs.expose.ui.textColor = {1,1,1}`
---
--- The following variables must be numbers (in screen points):
---  * `hs.expose.ui.textSize = 40`
---  * `hs.expose.ui.hintLetterWidth = 35` -- max width of a single letter; set accordingly if you change font or text size
---  * `hs.expose.ui.strokeWidth = 10`
---
--- The following variables must be strings:
---  * `hs.expose.ui.fontName = 'Lucida Grande'`
---
--- The following variables must be numbers:
---  * `hs.expose.ui.maxHintLetters = 2` -- if necessary, hints longer than this will be disambiguated with digits
---
--- The following variables must be strings, one of 'cmd', 'shift', 'ctrl' or 'alt':
---  * `hs.expose.ui.closeModeModifier = 'shift'`
---  * `hs.expose.ui.minimizeModeModifier = 'alt'`
---
--- The following variables must be booleans:
---  * `hs.expose.ui.showExtraKeys = true` -- show non-hint keybindings at the top of the screen
expose.ui=setmetatable({},{__newindex=function(t,k,v) ui[k]=v end,__index=ui})

local function getHints(screens)
  local function tlen(t)
    if not t then return 0 end
    local l=0 for _ in pairs(t) do l=l+1 end return l
  end
  local function hasSubHints(t)
    for k,v in pairs(t) do if type(k)=='string' and #k==1 then return true end end
  end
  local hints={apps={}}
  local reservedHint=1
  for _,screen in pairs(screens) do
    for _,w in ipairs(screen) do
      local appname=w.appname or ''
      while #appname<ui.maxHintLetters do
        appname=appname..tostring(reservedHint) reservedHint=reservedHint+1
      end
      hints[#hints+1]=w
      hints.apps[appname]=(hints.apps[appname] or 0)+1
      w.hint=''
    end
  end
  local function normalize(t,n) --change in place
    while #t>0 and tlen(t.apps)>0 do
      if n>ui.maxHintLetters or (tlen(t.apps)==1 and n>1 and not hasSubHints(t))  then
        -- last app remaining for this hint; give it digits
        local app=next(t.apps)
        t.apps={}
        if #t>1 then
          --fix so that accumulation is possible
          local total=#t
          for i,w in ipairs(t) do
            t[i]=nil
            local c=tostring(total<10 and i-(t.m1 and 1 or 0) or floor(i/10))
            t[c]=t[c] or {}
            tinsert(t[c],w)
            if #t[c]>1 then t[c].apps={app=#t[c]} t[c].m1=c~='0' end
            w.hint=w.hint..c
          end
        end
      else
        -- find the app with least #windows and add a hint to it
        local minfound,minapp=9999
        for appname,nwindows in pairs(t.apps) do
          if nwindows<minfound then minfound=nwindows minapp=appname end
        end
        t.apps[minapp]=nil
        local c=supper(ssub(minapp,n,n))
        --TODO what if not long enough
        t[c]=t[c] or {apps={}}
        t[c].apps[minapp]=minfound
        local i=1
        while i<=#t do
          if t[i].appname==minapp then
            local w=tremove(t,i)
            tinsert(t[c],w)
            w.hint=w.hint..c
          else i=i+1 end
        end
      end
  end
  for c,subt in pairs(t) do
    if type(c)=='string' and #c==1 then
      normalize(subt,n+1)
    end
  end
  end

  normalize(hints,1)
  return hints
end

local function getColor(t) if t.red then return t else return {red=t[1] or 0,green=t[2] or 0,blue=t[3] or 0,alpha=t[4] or 1} end end

local function updateHighlights(hints,subtree,show)
  for c,t in pairs(hints) do
    if t==subtree then
      updateHighlights(t,nil,true)
    elseif type(c)=='string' and #c==1 then
      if t[1] then t[1].highlight:setFillColor(getColor(show and ui.highlightColor or ui.fadeColor)):setStrokeColor(getColor(show and ui.highlightStrokeColor or ui.fadeStrokeColor))
      else updateHighlights(t,subtree,show) end
    end
  end
end

local screens,modals={},{}
local modes,activeInstance,tap={}

local function exitAll()
  log.d('exiting')
  while modals[#modals] do log.vf('exit modal for hint #%d',#modals) tremove(modals).modal:exit() end
  --cleanup
  for _,s in pairs(screens) do
    for _,w in ipairs(s) do
      if w.thumb then w.thumb:delete() end
      if w.icon then w.icon:delete() end
      if w.rect then w.rect:delete() end
      if w.ratio then w.ratio:delete() end
      w.highlight:delete()
      w.hinttext:delete() w.hintrect:delete()
    end
    s.bg:delete()
  end
  tap:stop()
  activeInstance=nil
end

local function setMode(k,mode)
  if modes[k]==mode then return end
  modes[k]=mode
  for s,screen in pairs(screens) do
    screen.bg:setFillColor(getColor(modes[k] and (k=='close' and ui.closeModeBackgroundColor or ui.minimizeModeBackgroundColor) or (s=='inv' and ui.minimizedStripBackgroundColor or ui.backgroundColor)))
  end
end

local enter,setThumb

local function exit()
  log.vf('exit modal for hint #%d',#modals)
  tremove(modals).modal:exit()
  if #modals==0 then return exitAll() end
  return enter()
end

enter=function(hints)
  if not hints then updateHighlights(modals[#modals].hints,nil,true) modals[#modals].modal:enter()
  elseif hints[1] then
    --got a hint
    local h,w=hints[1],hints[1].window
    local app,appname=w:application(),h.appname
    if modes.close then
      log.f('Closing window (%s)',appname)
      w:close()
      h.hintrect:delete() h.hinttext:delete() h.highlight:delete() h.thumb:delete() h.icon:delete()
      hints[1]=nil
      -- close app
      if app then
        if #app:allWindows()==0 then
          log.f('Quitting application %s',appname)
          app:kill()
        end
      end
      return enter()
    elseif modes.min then
      local newscreen
      log.f('Toggling window minimized/hidden (%s)',appname)
      if w:isMinimized() then w:unminimize() newscreen=w:screen():id()
      elseif app:isHidden() then app:unhide() newscreen=w:screen():id()
      else w:minimize() newscreen='inv' end
      h.frame:fit(screens[newscreen].frame)
      setThumb(h)
      return enter()
    else
      log.f('Focusing window (%s)',appname)
      if w:isMinimized() then w:unminimize() end
      w:focus()
      return exitAll()
    end
  else
    if modals[#modals] then log.vf('exit modal %d',#modals) modals[#modals].modal:exit() end
    local modal=newmodal()
    modals[#modals+1]={modal=modal,hints=hints}
    modal:bind({},'escape',exitAll)
    modal:bind({},'delete',exit)
    for c,t in pairs(hints) do
      if type(c)=='string' and #c==1 then
        modal:bind({},c,function()updateHighlights(hints,t) enter(t) end)
        modal:bind({ui.closeModeModifier},c,function()updateHighlights(hints,t) enter(t) end)
        modal:bind({ui.minimizeModeModifier},c,function()updateHighlights(hints,t) enter(t) end)
      end
    end
    log.vf('enter modal for hint #%d',#modals)
    modal:enter()
  end
end

local function spaceChanged()
  if not activeInstance then return end
  local tempinstance=activeInstance
  --  if tempinstance.wf.currentSpaceWindows then -- wf tracks spaces
  exitAll()
  tempinstance:show()
  --    windowfilter.switchedToSpace(space,function()tempinstance:expose()end)
  --  end
end
local spacesWatcher = spaces.watcher.new(spaceChanged)
spacesWatcher:start()

function expose:toggleShow()
  if activeInstance then return self:hide() else return self:show() end
end
function expose:hide()
  if activeInstance then return exitAll() end
end

setThumb=function(w)
  w.thumb:setFrame(w.frame:tohs()):orderAbove()
  w.highlight:setFrame(w.frame:tohs()):orderAbove()
  local hwidth=#w.hint*ui.hintLetterWidth
  local iconSize=ui.textSize*1.1
  local br={x=w.frame.x-hwidth/2-iconSize/2,y=w.frame.y-iconSize/2,w=hwidth+iconSize,h=iconSize}
  local tr={x=w.frame.x-hwidth/2+iconSize/2,y=w.frame.y-iconSize/2,w=hwidth,h=iconSize}
  local ir={x=w.frame.x-hwidth/2-iconSize/2,y=w.frame.y-iconSize/2,w=iconSize,h=iconSize}
  w.hintrect:setFrame(br):orderAbove()
  w.hinttext:setFrame(tr):orderAbove()
  w.icon:setFrame(ir):orderAbove()
end

--- hs.expose:show()
--- Method
--- Shows an expose-like screen with modal keyboard hints for switching to, closing or minimizing/unminimizing windows.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Completing a hint will exit the expose and focus the selected window.
---  * Pressing esc will exit the expose and with no action taken.
---  * If shift is being held when a hint is completed (the background will be red), the selected
---    window will be closed. If it's the last window of an application, the application will be closed.
---  * If alt is being held when a hint is completed (the background will be blue), the selected
---    window will be minimized (if visible) or unminimized/unhidden (if minimized or hidden).

--- hs.expose:hide()
--- Function
--- Hides the expose, if visible, and exits the modal mode.
--- Call this function if you need to make sure the modal is exited without waiting for the user to press `esc`.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None

--- hs.expose:toggleShow()
--- Function
--- Toggles the expose - see `hs.expose:show()` and `hs.expose:hide()`
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function expose:show(no_windowfilter,animate,iterations,alt_algo)
  -- no_windowfilter is for masochists (or testers): don't bother
  -- animate is waaay to slow: don't bother
  -- alt_algo sometimes performs better in terms of coverage, but (in the last half-broken implementation) always reaches maxIterations
  -- alt_algo TL;DR: much slower, don't bother
  if activeInstance then return end
  log.d('activated')
  activeInstance=self
  screens={}
  local mainscreen = screen.allScreens()[1]
  local wins = no_windowfilter and window.allWindows() or self.wf:getWindows()
  for i=#wins,1,-1 do
    local w = wins[i]
    local wid = w.id and w:id()
    local app = w:application()
    local appname,appbundle = app:title(),app:bundleID()
    local wsc = w.screen and w:screen()
    local scid = wsc and wsc:id()
    if not scid or not wid or not w:isVisible() then scid='inv' end
    if not screens[scid] then
      local frame = scid=='inv' and mainscreen:frame() or wsc:frame()
      local bg
      if scid~='inv' then
        bg=drawing.rectangle(frame):setFill(true):setFillColor(getColor(ui.backgroundColor)):show()
      end
      screens[scid]={frame=frame,bg=bg,area=0}
    end
    local frame=w:frame()
    screens[scid].area=screens[scid].area+frame.w*frame.h
    screens[scid][#screens[scid]+1] = {appname=appname,appbundle=appbundle,window=w,
      frame=rect.new(frame),originalFrame=frame,area=frame.w*frame.h,id=wid}
  end
  local invSize=ui.minimizedStripWidth
  do
    local msid=mainscreen:id()
    local f=screens[msid].frame
    local invf={x=f.x,y=f.y,w=f.w,h=f.h}
    if self.dock=='bottom' then f.h=f.h-invSize invf.y=f.y+f.h invf.h=invSize
    elseif self.dock=='left' then f.w=f.w-invSize f.x=f.x+invSize invf.w=invSize
    elseif self.dock=='right' then f.w=f.w-invSize invf.x=f.x+f.w invf.w=invSize end
    screens.inv=screens.inv or {area=0}
    screens.inv.frame=invf
    screens[msid].bg:setFrame(f)
    local bg=drawing.rectangle(invf):setFill(true):setFillColor(getColor(ui.minimizedStripBackgroundColor)):show()
    screens.inv.bg=bg
  end
  local hints=getHints(screens)
  for _,s in pairs(screens) do
    if animate then
      for _,w in ipairs(s) do
        w.thumb = drawing.image(w.originalFrame,window.snapshotFromID(w.id)):show() --FIXME gh#413
      end
    end
    fitWindows(s,iterations or 200,animate and 0 or nil,alt_algo)
    for _,w in ipairs(s) do
      --      if animate and w.thumb then w.thumb:delete() end
      if animate then
        w.thumb:setFrame(w.frame:tohs())
      else
        w.thumb = drawing.image(w.frame:tohs(),window.snapshotFromID(w.id)) --FIXME gh#413
      end
      --      w.ratio=drawing.text(w.frame:tohs(),sformat('%d%%',w.frame.w*w.frame.h*100/w.area)):setTextColor{red=1,green=0,blue=0,alpha=1}:show()
      local f=w.frame:tohs()
      w.highlight=drawing.rectangle(f):setFill(true):setFillColor(getColor(ui.highlightColor)):setStrokeWidth(ui.strokeWidth):setStrokeColor(getColor(ui.highlightStrokeColor))
      w.hintrect=drawing.rectangle(f):setFill(true):setFillColor(getColor(ui.backgroundColor)):setStroke(false):setRoundedRectRadii(ui.textSize/4,ui.textSize/4)
      w.hinttext=drawing.text(f,w.hint):setTextColor(getColor(ui.textColor)):setTextSize(ui.textSize):setTextFont(ui.fontName)
      w.icon = drawing.appImage(f,w.appbundle)
      setThumb(w)
      w.thumb:show() w.highlight:show() w.hintrect:show() w.hinttext:show() w.icon:show()
    end
  end
  enter(hints)
  tap=eventtap.new({eventtap.event.types.flagsChanged},function(e)
    local function hasOnly(t,mod)
      local n=next(t)
      if n~=mod then return end
      if not next(t,n) then return true end
    end
    setMode('close',hasOnly(e:getFlags(),ui.closeModeModifier))
    setMode('min',hasOnly(e:getFlags(),ui.minimizeModeModifier))
  end)
  tap:start()
end

--- hs.expose.new(windowfilter) -> hs.expose
--- Constructor
--- Creates a new hs.expose instance. It uses a windowfilter to determine which windows to show
---
--- Parameters:
---  * windowfilter - (optional) it can be:
---    * `nil` or omitted (as in `myexpose=hs.expose.new()`): the default windowfilter will be used
---    * an `hs.windowfilter` object
---    * otherwise all parameters are passed to `hs.windowfilter.new` to create a new instance
---
--- Returns:
---  * the new instance
---
--- Notes:
---   * The default windowfilter (or an unmodified copy) will allow the expose instance to be populated with windows from all
---     Mission Control Spaces (unlike the OSX expose); to limit to windows in the current Space only, use `:trackSpaces(true)`
---   * The default windowfilter (or an unmodified copy) will not track hidden windows; to let the expose instance also manage hidden windows,
---     use `:setDefaultFilter()` and/or other appropriate application-specific visiblity rules
function expose.new(wf,...)
  local dock = hs.execute'defaults read com.apple.dock "orientation"'
  local o = setmetatable({dock=dock:sub(1,-2)},{__index=expose})
  if wf==nil then log.i('New expose instance, using default windowfilter') o.wf=windowfilter.default
  elseif type(wf)=='table' and type(wf.isWindowAllowed)=='function' then
    log.i('New expose instance, using windowfilter instance') o.wf=wf
  else log.i('New expose instance, creating windowfilter') o.wf=windowfilter.new(wf,...)
    --    error('windowfilter must be nil or an hs.windowfilter object')
  end
  o.wf:keepActive()
  return o
end

return expose
