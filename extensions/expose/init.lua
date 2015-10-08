--- === hs.expose ===
---
--- **WARNING**: This module depends on the EXPERIMENTAL hs.window.filter. It can undergo breaking API changes or *go away entirely* **at any point and without notice**.
--- (Should you encounter any issues, please feel free to report them on https://github.com/Hammerspoon/hammerspoon/issues
--- or #hammerspoon on irc.freenode.net)
---
--- Keyboard-driven expose replacement/enhancement
---
--- Usage:
--- ```
--- -- set up your windowfilter
--- expose = hs.expose.new() -- default windowfilter: only visible windows, all Spaces
--- expose_space = hs.expose.new(hs.window.filter.new():setCurrentSpace(true):setDefaultFilter()) -- include minimized/hidden windows, current Space only
--- expose_browsers = hs.expose.new{'Safari','Google Chrome'} -- specialized expose for your dozens of browser windows :)
---
--- -- then bind to a hotkey
--- hs.hotkey.bind('ctrl-cmd','e','expose',function()expose:toggleShow()end)
---
--- -- alternatively, call .expose directly
--- hs.hotkey.bind('ctrl-alt','e','expose',expose.expose)
--- hs.hotkey.bind('ctrl-alt-shift','e','expose app',expose.exposeApplicationWindows)
--- ```

--TODO /// hs.drawing:setClickCallback(fn) -> drawingObject
--TODO showExtraKeys


local tinsert,tremove,min,max,ceil,abs,fmod,floor=table.insert,table.remove,math.min,math.max,math.ceil,math.abs,math.fmod,math.floor
local next,type,ipairs,pairs,setmetatable,sformat,supper,ssub,tostring=next,type,ipairs,pairs,setmetatable,string.format,string.upper,string.sub,tostring

local geom=require'hs.geometry'
local drawing,image=require'hs.drawing',require'hs.image'
local window,screen=require'hs.window',require'hs.screen'
local windowfilter=require'hs.window.filter'
local application,spaces=require'hs.application',require'hs.spaces'
local eventtap=require'hs.eventtap'
local newmodal=require'hs.hotkey'.modal.new
local log=require'hs.logger'.new('expose')

local expose={setLogLevel=log.setLogLevel,getLogLevel=log.getLogLevel} --module
local screens,modals={},{}
local modes,activeInstance,tap={}
local spacesWatcher


local function isAreaEmpty(rect,win,windows,screenFrame)
  if not rect:inside(screenFrame) then return end
  for _,w in ipairs(windows) do if w~=win and w.frame:intersect(rect).area>0 then return end end
  return true
end

local function fitWindows(windows,thumbnails,isInvisible,maxIterations,animate,alt_algo)
  local screenFrame = windows.frame
  local DISPLACE=floor(screenFrame.w/200)
  local avgRatio = min(1,screenFrame.area/windows.area*2)
  log.vf('shrink %d windows to %.0f%%',#windows,avgRatio*100)
  for i,win in ipairs(windows) do if not isInvisible then win.frame:scale(avgRatio) end win.frame:fit(screenFrame) end
  local didwork,iterations,screenArea = true,0,screenFrame.area

  while didwork and iterations<maxIterations do
    didwork=false
    iterations=iterations+1
    local thisAnimate=animate and floor(math.sqrt(iterations))
    local totalOverlaps,totalRatio,totalArea=0,0,0
    for i,win in ipairs(windows) do
      local wframe,winRatio = win.frame,win.frame.area/win.area
      totalRatio=totalRatio+winRatio
      -- log.vf('processing %s - %s',win.appname,win.frame)
      local overlapAreaTotal = 0
      local overlaps={}

      for j,win2 in ipairs(windows) do
        if j~=i then
          local intersection = wframe:intersect(win2.frame)
          local area=intersection.area
          if area>0 then
            --            log.vf('vs %s intersection [%.0f]',win2.hint,area)
            overlapAreaTotal=overlapAreaTotal+area
            overlaps[#overlaps+1] = intersection
            --            if area>wframe.area*0.9 then overlaps[#overlaps].center=(wframe.center+win2.frame.center)*0.5 end
          end
        end
      end

      totalOverlaps=totalOverlaps+#overlaps
      -- find the overlap regions center
      if #overlaps>0 then
        didwork=true
        local ac=geom.point(0,0)
        for _,ov in ipairs(overlaps) do
          local weight = ov.area/overlapAreaTotal
          ac=ac+ ov.center*weight
        end
        ac=(wframe.center-ac) * (overlapAreaTotal/screenArea*3)
        wframe:move(ac)
        if winRatio/avgRatio>0.8 then wframe:scale(alt_algo and 0.95 or 0.98) end
        wframe:fit(screenFrame)
      elseif alt_algo then
        -- scale back up
        wframe:scale(1.05):fit(screenFrame)
      end

      if totalOverlaps>0 and avgRatio<0.9 and not alt_algo then
        for dx = -DISPLACE,DISPLACE,DISPLACE*2 do
          if wframe.center.x>screenFrame.center.x then dx=-dx end
          local r=geom.copy(wframe):setx(dx>0 and wframe.x2 or (wframe.x+dx)):setw(abs(dx)*2-1)
          if isAreaEmpty(r,win,windows,screenFrame) then
            wframe:move(dx,0)
            if winRatio/avgRatio<1.33 and winRatio<1 then wframe:scale(1.01):fit(screenFrame) end
            didwork=true break
          end
        end
        for dy = -DISPLACE,DISPLACE,DISPLACE*2 do
          if wframe.center.y>screenFrame.center.y then dy=-dy end
          local r=geom.copy(wframe):sety(dy>0 and wframe.y2 or (wframe.y+dy)):seth(abs(dy)*2-1)
          --          if win.hint=='L' then print('testareaY'..dy..': '..r.string) end
          if isAreaEmpty(r,win,windows,screenFrame) then
            --            if win.hint=='L' then print(' empty  Y'..dy..': '..r.string) end
            wframe:move(0,dy)
            if winRatio/avgRatio<1.33 and winRatio<1 then wframe:scale(1.015):fit(screenFrame) end
            didwork=true break
          end
        end
      end
      if thisAnimate and thisAnimate>animate then win.thumb:setFrame(wframe) end
      win.frame=wframe
    end
    avgRatio=totalRatio/#windows
    for i,win in ipairs(windows) do totalArea=totalArea+win.frame.area end
    local halting=iterations==maxIterations
    if not didwork or halting then
      log.vf('%s (%d iterations): coverage %.2f%% (%d overlaps)',halting and 'halted' or 'optimal',iterations,totalArea/(screenFrame.area)*100,totalOverlaps)
    end
    animate=animate and thisAnimate
  end
end

local uiGlobal = {
  textColor={1,1,1,1},
  highlightTextColor={1,1,1,1},
  fadeTextColor={0.2,0.2,0.2},
  fontName='Lucida Grande',
  textSize=40,
  highlightHintColor={0.2,0.1,0},
  fadeHintColor={0.1,0.1,0.1},

  backgroundColor={0.3,0.3,0.3,0.95},
  closeModeBackgroundColor={0.7,0.1,0.1,0.95},
  minimizeModeBackgroundColor={0.1,0.3,0.6,0.95},
  minimizedStripPosition='bottom',
  minimizedStripBackgroundColor={0.15,0.15,0.15,0.95},
  minimizedStripWidth=200,

  fadeColor={0,0,0,0.8},
  fadeStrokeColor={0,0,0},
  highlightColor={0.8,0.5,0,0.1},
  highlightStrokeColor={0.8,0.5,0,0.8},
  strokeWidth=10,

  showExtraKeys=true,
  showThumbnails=true,
  showTitles=true,
  maxIterations=200,

  closeModeModifier = 'shift',
  minimizeModeModifier = 'alt',

  maxHintLetters = 2,
}

local function getColor(t) if t.red then return t else return {red=t[1] or 0,green=t[2] or 0,blue=t[3] or 0,alpha=t[4] or 1} end end

--- hs.expose.ui
--- Variable
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
---  * `hs.expose.ui.minimizedStripBackgroundColor = {0.15,0.15,0.15,0.95}` -- this is the strip that contains thumbnails for non-visible windows
---  * `hs.expose.ui.textColor = {1,1,1}`
---  * `hs.expose.ui.highlightTextColor = {1,1,1}` -- text color for hints of candidate windows
---  * `hs.expose.ui.highlightHintColor = {0.2,0.1,0}, -- hint background for candidate windows
---  * `hs.expose.ui.highlightColor = {0.8,0.5,0,0.1}` -- overlay for thumbnails of candidate windows
---  * `hs.expose.ui.highlightStrokeColor = {0.8,0.5,0,0.8}` -- frame for thumbnails of candidate windows
---  * `hs.expose.ui.fadeTextColor = {1,1,1}` -- text color for hints of excluded windows
---  * `hs.expose.ui.fadeHintColor = {0.2,0.1,0}, -- hint background for excluded windows
---  * `hs.expose.ui.fadeColor = {0,0,0,0.8}` -- overlay for thumbnails of excluded windows
---  * `hs.expose.ui.fadeStrokeColor = {0,0,0}` -- frame for thumbnails of excluded windows
---
--- The following variables must be numbers (in screen points):
---  * `hs.expose.ui.textSize = 40`
---  * `hs.expose.ui.strokeWidth = 10` -- for thumbnail frames
---
--- The following variables must be strings:
---  * `hs.expose.ui.fontName = 'Lucida Grande'`
---  * `hs.expose.ui.minimizedStripPosition = 'bottom'` -- set it to your Dock position ('bottom', 'left' or 'right')
---
--- The following variables must be numbers:
---  * `hs.expose.ui.maxHintLetters = 2` -- if necessary, hints longer than this will be disambiguated with digits
---
--- The following variables must be strings, one of 'cmd', 'shift', 'ctrl' or 'alt':
---  * `hs.expose.ui.closeModeModifier = 'shift'`
---  * `hs.expose.ui.minimizeModeModifier = 'alt'`
---
--- The following variables must be booleans:
---  * `hs.expose.ui.showThumbnails = true` -- show window thumbnails (slower)
---  * `hs.expose.ui.showTitles = true` -- show window titles (slower)
---  * `hs.expose.ui.showExtraKeys = true` -- show non-hint keybindings at the top of the screen
---
--- The following variables must be numbers (in screen points):
---  * `hs.expose.ui.maxIterations = 200` -- lower is faster, but higher chance of overlapping thumbnails
expose.ui=setmetatable({},{__newindex=function(t,k,v) uiGlobal[k]=v end,__index=uiGlobal})


local haveThumbs,haveTitles,ui -- cache ui prefs

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


local function updateHighlights(hints,subtree,show)
  for c,t in pairs(hints) do
    if t==subtree then
      updateHighlights(t,nil,true)
    elseif type(c)=='string' and #c==1 then
      if t[1] then
        if haveThumbs then
          t[1].highlight:setFillColor(show and ui.highlightColor or ui.fadeColor):setStrokeColor(show and ui.highlightStrokeColor or ui.fadeStrokeColor)
        end
        if haveTitles then
          t[1].titletext:setTextColor(show and ui.highlightTextColor or ui.fadeTextColor)
          t[1].titlerect:setFillColor(show and ui.highlightHintColor or ui.fadeHintColor)
        end
        t[1].hintrect:setFillColor(show and ui.highlightHintColor or ui.fadeHintColor)
        t[1].hinttext:setTextColor(show and ui.highlightTextColor or ui.fadeTextColor)
      else updateHighlights(t,subtree,show) end
    end
  end
end


local function exitAll()
  log.d('exiting')
  while modals[#modals] do log.vf('exit modal for hint #%d',#modals) tremove(modals).modal:exit() end
  --cleanup
  for _,s in pairs(screens) do
    for _,w in ipairs(s) do
      if haveThumbs then w.thumb:delete() w.highlight:delete() end
      if haveTitles then w.titletext:delete() w.titlerect:delete() end
      if w.icon then w.icon:delete() w.hinttext:delete() w.hintrect:delete() end
      --      if w.rect then w.rect:delete() end
      if w.ratio then w.ratio:delete() end
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
    screen.bg:setFillColor(modes[k] and (k=='close' and ui.closeModeBackgroundColor or ui.minimizeModeBackgroundColor) or (s=='inv' and ui.minimizedStripBackgroundColor or ui.backgroundColor))
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
      h.hintrect:delete() h.hinttext:delete() h.icon:delete()
      if haveThumbs then h.thumb:delete() h.highlight:delete() end
      if haveTitles then h.titletext:delete() h.titlerect:delete() end
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
      setThumb(h,screens[newscreen].frame)
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
  exitAll()
  return tempinstance()
end

setThumb=function(w,screenFrame)
  local wframe=w.frame
  if haveThumbs then
    w.thumb:setFrame(wframe):orderAbove()
    w.highlight:setFrame(wframe):orderAbove()
  end
  --  local hwidth=#w.hint*ui.hintLetterWidth
  local textWidth=drawing.getTextDrawingSize(w.hint,ui.textStyle).w
  local hintHeight=ui.hintHeight
  local padding=hintHeight*0.1
  local br=geom.copy(wframe):seth(hintHeight):setw(textWidth+hintHeight+padding*4):setcenter(wframe.center):fit(screenFrame)
  local tr=geom.copy(br):setw(textWidth+padding*2):move(hintHeight+padding*2,0)
  local ir=geom.copy(br):setw(hintHeight):move(padding,0)
  w.hintrect:setFrame(br):orderAbove()
  w.hinttext:setFrame(tr):orderAbove()
  w.icon:setFrame(w.appbundle and ir or {x=0,y=0,w=0,h=0}):orderAbove()
  if haveTitles then
    local textWidth=min(wframe.w,drawing.getTextDrawingSize(w.title,ui.titleTextStyle).w)
    local tr=geom.copy(wframe):seth(ui.titleHeight):setw(textWidth+8):setcenter(wframe.center):move(0,hintHeight):fit(screenFrame)
    w.titletext:setFrame(tr):orderAbove()
    w.titlerect:setFrame(tr):orderAbove()
  end
end


local UNAVAILABLE=image.imageFromName'NSStopProgressTemplate'

local function showExpose(wins,uiPrefs,animate,alt_algo)
  -- animate is waaay to slow: don't bother
  -- alt_algo sometimes performs better in terms of coverage, but (in the last half-broken implementation) always reaches maxIterations
  -- alt_algo TL;DR: much slower, don't bother
  log.d('activated')
  if uiPrefs==nil then uiPrefs={} end
  if type(uiPrefs)~='table' then error('uiPrefs must be a table',3) end
  ui={}
  for k,v in pairs(uiGlobal) do
    if ssub(k,-5)=='Color' then ui[k]=getColor(uiPrefs[k] or v)
    elseif uiPrefs[k]==nil then ui[k]=v else ui[k]=uiPrefs[k] end
  end
  haveThumbs,haveTitles=ui.showThumbnails,ui.showTitles
  ui.noThumbsFrameSide=ui.textSize*4
  ui.textStyle={font=ui.fontName,size=ui.textSize,color=ui.highlightTextColor}
  ui.titleTextStyle={font=ui.fontName,size=max(20,ui.textSize/2),color=ui.highlightTextColor,lineBreak='truncateTail'}
  ui.hintHeight,ui.titleHeight=drawing.getTextDrawingSize('O',ui.textStyle).h,drawing.getTextDrawingSize('O',ui.titleTextStyle).h

  if not spacesWatcher then spacesWatcher = spaces.watcher.new(spaceChanged):start() end

  screens={}
  local hsscreens = screen.allScreens()
  local mainscreen = hsscreens[1]
  for _,s in ipairs(hsscreens) do
    local id,frame=s:id(),s:frame()
    screens[id]={frame=frame,area=0,bg=drawing.rectangle(frame):setFill(true):setFillColor(ui.backgroundColor):show()}
  end
  do -- hidden windows strip
    local invSize=ui.minimizedStripWidth
    local msid=mainscreen:id()
    local f=screens[msid].frame
    local invf=geom.copy(f)
    --    local dock = execute'defaults read com.apple.dock "orientation"':sub(1,-2)
    -- calling execute takes 100ms every time, make this a ui preference instead
    local dock=ui.minimizedStripPosition
    if dock=='left' then f.w=f.w-invSize f.x=f.x+invSize invf.w=invSize
    elseif dock=='right' then f.w=f.w-invSize invf.x=f.x+f.w invf.w=invSize
    else f.h=f.h-invSize invf.y=f.y+f.h invf.h=invSize end --bottom
    screens.inv={area=0,frame=invf,bg=drawing.rectangle(invf):setFill(true):setFillColor(ui.minimizedStripBackgroundColor):show()}
    screens[msid].bg:setFrame(f)
  end
  for i=#wins,1,-1 do
    local w = wins[i]
    local wid,app = w.id and w:id(),w:application()
    local appname,appbundle = app and app:name(),app and app:bundleID()
    local wsc = w:screen()
    local scid = wsc and wsc:id()
    if not scid or not wid or not w:isVisible() then scid='inv' end
    local frame=w:frame()
    if not haveThumbs then frame.aspect=1 frame.area=ui.noThumbsFrameSide*ui.noThumbsFrameSide end
    screens[scid].area=screens[scid].area+frame.area
    screens[scid][#screens[scid]+1] = {appname=appname,appbundle=appbundle,window=w,
      frame=frame,originalFrame=frame,area=frame.area,id=wid,title=haveTitles and w:title() or ''}
  end
  local hints=getHints(screens)
  for sid,s in pairs(screens) do
    if animate and haveThumbs then for _,w in ipairs(s) do
      w.thumb = drawing.image(w.originalFrame,window.snapshotForID(w.id)):show()
    end end
    fitWindows(s,haveThumbs,sid=='inv',ui.maxIterations,animate and 0 or nil,alt_algo)
    for _,w in ipairs(s) do
      if animate then w.thumb:setFrame(w.frame)
      elseif haveThumbs then
        local thumb=w.id and window.snapshotForID(w.id) w.thumb=drawing.image(w.frame,thumb or UNAVAILABLE)
      end
      local f=w.frame
      if haveThumbs then
        w.highlight=drawing.rectangle(f):setFill(true):setFillColor(ui.highlightColor):setStrokeWidth(ui.strokeWidth):setStrokeColor(ui.highlightStrokeColor)
      end
      w.hintrect=drawing.rectangle(f):setFill(true):setFillColor(ui.highlightHintColor):setStroke(false):setRoundedRectRadii(ui.textSize/4,ui.textSize/4)
      w.hinttext=drawing.text(f,w.hint):setTextStyle(ui.textStyle)
      if haveTitles then
        w.titletext=drawing.text(f,w.title):setTextStyle(ui.titleTextStyle)
        w.titlerect=drawing.rectangle(f):setFill(true):setFillColor(ui.highlightHintColor):setStroke(false):setRoundedRectRadii(ui.textSize/8,ui.textSize/8)
      end
      local icon=w.appbundle and image.imageFromAppBundle(w.appbundle)
      w.icon = drawing.image(f,icon or UNAVAILABLE)
      setThumb(w,s.frame)
      if haveThumbs then w.thumb:show() w.highlight:show() end
      if haveTitles then w.titlerect:show() w.titletext:show() end
      w.hintrect:show() w.hinttext:show() w.icon:show()
      --      w.ratio=drawing.text(w.frame,sformat('%.0f%%',w.frame.area*100/w.area)):setTextColor{red=1,green=0,blue=0,alpha=1}:show()
    end
  end
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
  enter(hints)
end

--- hs.expose:toggleShow([applicationWindows][, uiPrefs])
--- Method
--- Toggles the expose - see `hs.expose:show()` and `hs.expose:hide()`
---
--- Parameters: see `hs.expose:show()`
---
--- Returns:
---  * None
function expose:toggleShow(...)
  if activeInstance then return self:hide() else return self:show(...) end
end
--- hs.expose:hide()
--- Method
--- Hides the expose, if visible, and exits the modal mode.
--- Call this function if you need to make sure the modal is exited without waiting for the user to press `esc`.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function expose:hide()
  if activeInstance then return exitAll() end
end
--- hs.expose:show([applicationWindows][, uiPrefs])
--- Method
--- Shows an expose-like screen with modal keyboard hints for switching to, closing or minimizing/unminimizing windows.
---
--- Parameters:
---  * applicationWindows - (optional) if true, only show windows of the active application (within the
---   scope of the instance windowfilter); otherwise show all windows allowed by the instance windowfilter
---  * uiPrefs - (optional) a table to override UI preferences for this invocation only; its keys and values
---    must follow the conventions described in `hs.expose.ui`
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

local function getApplicationWindows()
  local a=application.frontmostApplication()
  if not a then log.w('Cannot get active application') return end
  return a:allWindows()
end
function expose:show(currentApp,uiPrefs)
  if activeInstance then return end
  if type(currentApp)=='table' then uiPrefs=currentApp currentApp=nil end
  local wins=self.wf:getWindows()
  if currentApp then
    local allwins,appwins=wins,getApplicationWindows()
    if not appwins then return end
    wins={}
    for _,w in ipairs(allwins) do
      for __,appw in ipairs(appwins) do if appw:id()==w:id() then wins[#wins+1]=appw end end
    end
  end
  activeInstance=function()return self:show(currentApp,uiPrefs)end
  return showExpose(wins,uiPrefs)
end

--- hs.expose.expose([windows][, uiPrefs])
--- Function
--- Shows an expose-like screen with modal keyboard hints for switching to, closing or minimizing/unminimizing windows.
--- If an expose is already visible, calling this function will toggle it off.
---
--- Parameters:
---  * windows - a list of windows to expose; if omitted or nil, `hs.window.allWindows()` will be used
---  * uiPrefs - (optional) a table to override UI preferences for this invocation only; its keys and values
---    must follow the conventions described in `hs.expose.ui`
---
--- Returns:
---  * None
---
--- Notes:
---  * Due to OS X limitations, this function cannot show hidden applications or windows across
---    Mission Control Spaces; if you need these, you can create an instance with `hs.expose.new`
---    (set the windowfilter for your needs) and then use `:show()`
---  * Completing a hint will exit the expose and focus the selected window.
---  * Pressing esc will exit the expose and with no action taken.
---  * If shift is being held when a hint is completed (the background will be red), the selected
---    window will be closed. If it's the last window of an application, the application will be closed.
---  * If alt is being held when a hint is completed (the background will be blue), the selected
---    window will be minimized (if visible) or unminimized/unhidden (if minimized or hidden).
function expose.expose(wins,uiPrefs)
  if activeInstance then return exitAll() end
  if type(wins)=='table' and #wins==0 then uiPrefs=wins wins=nil end
  local origWins=wins
  if not wins then wins=window.orderedWindows() end
  if type(wins)~='table' then error('windows must be a table',2) end
  activeInstance=function()return expose.expose(origWins,uiPrefs)end
  return showExpose(wins,uiPrefs)
end

--- hs.expose.exposeApplicationWindows([uiPrefs])
--- Function
--- Shows an expose for the windows of the active application.
--- If an expose is already visible, calling this function will toggle it off.
---
--- Parameters:
---  * uiPrefs - (optional) a table to override UI preferences for this invocation only; its keys and values
---    must follow the conventions described in `hs.expose.ui`
---
--- Returns:
---  * None
---
--- Notes:
---  * This is just a convenience wrapper for `hs.expose.expose(hs.window.focusedWindow():application():allWindows())`
function expose.exposeApplicationWindows(uiPrefs)
  if activeInstance then return exitAll() end
  activeInstance=function()return expose.exposeApplicationWindows(uiPrefs)end
  local wins=getApplicationWindows()
  return wins and showExpose(wins,uiPrefs)
end

--- hs.expose.new(windowfilter) -> hs.expose
--- Constructor
--- Creates a new hs.expose instance. It uses a windowfilter to determine which windows to show
---
--- Parameters:
---  * windowfilter - (optional) if omitted, use the default windowfilter; otherwise it must be a windowfilter
---    instance or constructor argument(s)
---
--- Returns:
---  * the new instance
---
--- Notes:
---   * The default windowfilter (or an unmodified copy) will allow the expose instance to be populated with windows from all
---     Mission Control Spaces (unlike the OSX expose); to limit to windows in the current Space only, use `:setCurrentSpace(true)`
---   * The default windowfilter (or an unmodified copy) will not track hidden windows; to let the expose instance also manage hidden windows,
---     use `:setDefaultFilter()` and/or other appropriate application-specific visiblity rules
function expose.new(wf,...)
  local o = setmetatable({},{__index=expose})
  if wf==nil then log.i('New expose instance, using default windowfilter') o.wf=windowfilter.default
  else log.i('New expose instance using windowfilter instance') o.wf=windowfilter.new(wf,...) end
  o.wf:keepActive()
  return o
end

return expose
