--- === hs.expose ===
---
--- Keyboard-driven expose replacement/enhancement
---
--- Warning: this module is still somewhat experimental.
--- Should you encounter any issues, please feel free to report them on https://github.com/Hammerspoon/hammerspoon/issues
--- or #hammerspoon on irc.freenode.net
---
--- With this module you can configure a hotkey to show thumbnails for open windows when invoked; each thumbnail will have
--- an associated keyboard "hint" (usually one or two characters) that you can type to quickly switch focus to that
--- window; in conjunction with keyboard modifiers, you can additionally minimize (`alt` by default) or close
--- (`shift` by default) any window without having to focus it first.
---
--- When used in combination with a windowfilter you can include or exclude specific apps, window titles, screens,
--- window roles, etc. Additionally, each expose instance can be customized to include or exclude minimized or hidden windows,
--- windows residing in other Mission Control Spaces, or only windows for the current application. You can further customize
--- hint length, colors, fonts and sizes, whether to show window thumbnails and/or titles, and more.
---
--- To improve responsiveness, this module will update its thumbnail layout in the background (so to speak), so that it
--- can show the expose without delay on invocation. Be aware that on particularly heavy Hammerspoon configurations
--- this could adversely affect overall performance; you can disable this behaviour with
--- `hs.expose.ui.fitWindowsInBackground=false`
---
--- Usage:
--- ```
--- -- set up your instance(s)
--- expose = hs.expose.new(nil,{showThumbnails=false}) -- default windowfilter, no thumbnails
--- expose_app = hs.expose.new(nil,{onlyActiveApplication=true}) -- show windows for the current application
--- expose_space = hs.expose.new(nil,{includeOtherSpaces=false}) -- only windows in the current Mission Control Space
--- expose_browsers = hs.expose.new{'Safari','Google Chrome'} -- specialized expose using a custom windowfilter
--- -- for your dozens of browser windows :)
---
--- -- then bind to a hotkey
--- hs.hotkey.bind('ctrl-cmd','e','Expose',function()expose:toggleShow()end)
--- hs.hotkey.bind('ctrl-cmd-shift','e','App Expose',function()expose_app:toggleShow()end)
--- ```

--TODO /// hs.drawing:setClickCallback(fn) -> drawingObject
--TODO showExtraKeys

--local print=function()end

local min,max,ceil,abs,fmod,floor,random=math.min,math.max,math.ceil,math.abs,math.fmod,math.floor,math.random
local next,type,ipairs,pairs,sformat,supper,ssub,tostring=next,type,ipairs,pairs,string.format,string.upper,string.sub,tostring
local tinsert,tremove,tsort,setmetatable,rawset=table.insert,table.remove,table.sort,setmetatable,rawset

local geom=require'hs.geometry'
local drawing,image=require'hs.drawing',require'hs.image'
local window,screen=require'hs.window',require'hs.screen'
local windowfilter=require'hs.window.filter'
local application,spaces=require'hs.application',require'hs.spaces'
local eventtap=require'hs.eventtap'
local newmodal=require'hs.hotkey'.modal.new
local asciiOnly=require'hs.utf8'.asciiOnly
local function stripUnicode(s)
  return asciiOnly(s):gsub('\\x[0-9A-F][0-9A-F]','')
end
local timer,logger=require'hs.timer',require'hs.logger'
local log=logger.new('expose')

local expose={setLogLevel=log.setLogLevel,getLogLevel=log.getLogLevel} --module
local activeInstances={} -- these are updated in the background
local modals={} -- modal hotkeys for selecting a hint; global state
local activeInstance,fnreactivate -- function to reactivate the current instance (only 1 possible) after a space switch
local modes,tap={} -- modes (minimize, close) for the current instance, and eventtap (glboals)
local spacesWatcher,screenWatcher,screensChangedTimer,bgFitTimer -- global watchers
local BG_FIT_INTERVAL=3
local BEHAVIOR=17

local function tlen(t)
  if not t then return 0 end
  local l=0 for _ in pairs(t) do l=l+1 end return l
end

local function isAreaEmpty(rect,w,windows,screenFrame)
  if not rect:inside(screenFrame) then return end
  for _,w2 in pairs(windows) do if w2~=w and w2.frame:intersect(rect).area>0 then return end end
  return true
end
local function sortedWindows(t,comp)
  local r={} for _,w in pairs(t) do r[#r+1]=w end
  tsort(r,comp) return r
end

local function fitWindows(self,screen,maxIterations)
  if not screen.dirty then return end
  local screenFrame=screen.frame
  local windows=screen.windows
  local nwindows=tlen(windows)
  if nwindows==0 then screen.dirty=nil return end
  local haveThumbs,isStrip=screen.thumbnails,screen.isStrip
  local optimalRatio=min(1,screenFrame.area/screen.totalOriginalArea)
  local accRatio=0

  local minWidth,minHeight=self.ui.minWidth,self.ui.minHeight
  local longSide=max(screenFrame.w,screenFrame.h)
  local maxDisplace=longSide/20
  local VEC00=geom.new(0,0)
  local edge=(isStrip and not haveThumbs) and screen.edge or VEC00

  if not haveThumbs then -- "fast" mode
    for _,w in pairs(windows) do
      if w.dirty then w.frame:setw(minWidth):seth(minHeight):setcenter(w.originalFrame.center):fit(screenFrame) w.ratio=1 end
      w.weight=1/nwindows
  end
  accRatio=1
  maxDisplace=max(minWidth,minHeight)*0.5
  else
    local isVertical=screen.pos=='left' or screen.pos=='right'
    local s=(longSide*0.7/nwindows)/(isVertical and minHeight or minWidth)
    if isStrip and s<1 then
      minWidth,minHeight=minWidth*s,minHeight*s
      local t=sortedWindows(windows,isVertical and
        function(w1,w2) return w1.frame.y<w2.frame.y end or
        function(w1,w2) return w1.frame.x<w2.frame.x end)
      local inc=longSide/nwindows
      for i,w in ipairs(t) do
        --        if w.dirty then w.frame=geom.new(inc*(i-1)+screenFrame.x,inc*(i-1)+screenFrame.y,minWidth,minHeight) end
        if w.dirty then w.frame:setx(inc*(i-1)+screenFrame.x):sety(inc*(i-1)+screenFrame.y):fit(screenFrame) end
        w.ratio=w.frame.area/w.originalFrame.area
        w.weight=w.originalFrame.area/screen.totalOriginalArea
        accRatio=accRatio+w.ratio*w.weight
      end
      maxDisplace=max(minWidth,minHeight)*0.5
    else
      for _,w in pairs(windows) do
        if w.dirty then w.frame=geom.copy(w.originalFrame):scale(min(1,optimalRatio*2)) w.ratio=min(1,optimalRatio*2)
        else w.ratio=w.frame.area/w.originalFrame.area end
        w.weight=w.originalFrame.area/screen.totalOriginalArea
        accRatio=accRatio+w.ratio*w.weight
      end
    end
  end
  local avgRatio=accRatio
  if nwindows==1 then maxIterations=1 end
  local didwork,iterations = true,0
  local TESTFRAMES={{S=1,s=1,weight=3},{S=1.08,s=1.02,weight=1},{S=1.4,s=1.1,weight=0.3},{S=2.5,s=1.5,weight=0.02}}
  local MAXTEST=haveThumbs and (isStrip and 3 or #TESTFRAMES) or 3
  while didwork and iterations<maxIterations do
    didwork,accRatio,iterations=false,0,iterations+1
    local totalOverlaps=0
    for _,w in pairs(windows) do
      local wframe,wratio=w.frame,w.ratio
      accRatio=accRatio+wratio*w.weight
      for i=MAXTEST,1,-1 do local test=TESTFRAMES[i]
        local ovs,tarea,weight={},0,test.weight
        for _,testframe in ipairs{geom.copy(wframe):scale(test.S,test.s),geom.copy(wframe):scale(test.s,test.S)} do
          for _,w2 in pairs(windows) do if w~=w2 then
            local intersection=testframe:intersect(w2.frame)
            local area=intersection.area
            if area>0 then
              tarea=tarea+area
              ovs[#ovs+1]=intersection
            end
          end end
        end
        if tarea>0 then
          local ac=geom.copy(VEC00)
          for _,ov in ipairs(ovs) do ac=ac+ov.center*(ov.area/tarea) end
          ac=(wframe.center-ac) * (tarea/wframe.area*weight*(isStrip and 3 or 3))
          if ac.length>maxDisplace then ac.length=maxDisplace
            --          else
            --            ac:move(random(-10,10)/20,random(-10,10)/20)
            --             end
          elseif ac:floor()==VEC00 then ac:move(random(-10,10)/20,random(-10,10)/20) end
          wframe:move(ac):fit(screenFrame)
          --          if i<=2 then didwork=true end
          if i==1 then
            totalOverlaps=totalOverlaps+1
            if haveThumbs then
              if wratio*1.25>avgRatio then --shrink
                wframe:scale(0.965)
                didwork=true
              else
                for _,w2 in pairs(windows) do w2.frame:scale(0.98) w2.ratio=w2.ratio*0.98 end
                accRatio=accRatio*0.98
              end
            end
          end
        elseif i==2 then
          if haveThumbs and wratio<avgRatio*1.25 and wratio<optimalRatio then -- grow
            wframe:scale(1.04)
            if not didwork and wframe.w<screenFrame.w and wframe.h<screenFrame.h then didwork=true end
          end
          break
        end
      end
      wframe:move(edge):fit(screenFrame)
      w.frame=wframe w.ratio=wframe.area/w.originalFrame.area
    end
    didwork=didwork or totalOverlaps>0
    local halting=iterations==maxIterations
    if not didwork or halting then
      local totalArea,totalRatio=0,0
      for _,win in pairs(windows) do
        totalArea=totalArea+win.frame.area
        totalRatio=totalRatio+win.ratio
        win.frames[screen]=geom.copy(win.frame)
        win.dirty=nil
      end
      self.log.vf('%s: %s (%d iter), coverage %.2f%%, ratio %.2f%%/%.2f%%, %d overlaps',screen.name,
        didwork and 'halted' or 'optimal',iterations,totalArea/(screenFrame.area)*100,totalRatio/nwindows*100,optimalRatio*100,totalOverlaps)
      if not didwork then screen.dirty=nil end
    else avgRatio=accRatio end
  end
end

local uiGlobal = {
  textColor={0.9,0.9,0.9,1},
  fontName='Lucida Grande',
  textSize=40,

  highlightColor={0.6,0.3,0.0,1},

  backgroundColor={0.03,0.03,0.03,1},
  closeModeModifier = 'shift',
  closeModeBackgroundColor={0.7,0.1,0.1,1},
  minimizeModeModifier = 'alt',
  minimizeModeBackgroundColor={0.1,0.2,0.3,1},
  onlyActiveApplication=false,
  includeNonVisible=true,
  nonVisibleStripPosition='bottom',
  nonVisibleStripBackgroundColor={0.03,0.1,0.15,1},
  nonVisibleStripWidth=0.1,
  includeOtherSpaces=true,
  otherSpacesStripBackgroundColor={0.1,0.1,0.1,1},
  otherSpacesStripWidth=0.2,
  otherSpacesStripPosition='top',

  showTitles=true,
  showThumbnails=true,
  thumbnailAlpha=0,
  highlightThumbnailAlpha=1,
  highlightThumbnailStrokeWidth=8,

  maxHintLetters = 2,

  fitWindowsMaxIterations=30,
  fitWindowsInBackground=false,
  fitWindowsInBackgroundMaxIterations=3,
  fitWindowsInBackgroundMaxRepeats=10,

  showExtraKeys=true,
}

local function getColor(t) if type(t)~='table' or t.red or not t[1] then return t else return {red=t[1] or 0,green=t[2] or 0,blue=t[3] or 0,alpha=t[4] or 1} end end

--- hs.expose.ui
--- Variable
--- Allows customization of the expose behaviour and user interface
---
--- This table contains variables that you can change to customize the behaviour of the expose and the look of the UI.
--- To have multiple expose instances with different behaviour/looks, use the `uiPrefs` parameter for the constructor;
--- the passed keys and values will override those in this table for that particular instance.
---
--- The default values are shown in the right hand side of the assignements below.
---
--- To represent color values, you can use:
---  * a table {red=redN, green=greenN, blue=blueN, alpha=alphaN}
---  * a table {redN,greenN,blueN[,alphaN]} - if omitted alphaN defaults to 1.0
--- where redN, greenN etc. are the desired value for the color component between 0.0 and 1.0
---
---  * `hs.expose.ui.textColor = {0.9,0.9,0.9}`
---  * `hs.expose.ui.fontName = 'Lucida Grande'`
---  * `hs.expose.ui.textSize = 40` - in screen points
---  * `hs.expose.ui.highlightColor = {0.8,0.5,0,0.1}` - highlight color for candidate windows
---  * `hs.expose.ui.backgroundColor = {0.30,0.03,0.03,1}`
---  * `hs.expose.ui.closeModeModifier = 'shift'` - "close mode" engaged while pressed (or 'cmd','ctrl','alt')
---  * `hs.expose.ui.closeModeBackgroundColor = {0.7,0.1,0.1,1}` - background color while "close mode" is engaged
---  * `hs.expose.ui.minimizeModeModifier = 'alt'` - "minimize mode" engaged while pressed
---  * `hs.expose.ui.minimizeModeBackgroundColor = {0.1,0.2,0.3,1}` - background color while "minimize mode" is engaged
---  * `hs.expose.ui.onlyActiveApplication = false` -- only show windows of the active application
---  * `hs.expose.ui.includeNonVisible = true` - include minimized and hidden windows
---  * `hs.expose.ui.nonVisibleStripBackgroundColor = {0.03,0.1,0.15,1}` - contains hints for non-visible windows
---  * `hs.expose.ui.nonVisibleStripPosition = 'bottom'` - set it to your Dock position ('bottom', 'left' or 'right')
---  * `hs.expose.ui.nonVisibleStripWidth = 0.1` - 0..0.5, width of the strip relative to the screen
---  * `hs.expose.ui.includeOtherSpaces = true` - include windows in other Mission Control Spaces
---  * `hs.expose.ui.otherSpacesStripBackgroundColor = {0.1,0.1,0.1,1}`
---  * `hs.expose.ui.otherSpacesStripPosition = 'top'`
---  * `hs.expose.ui.otherSpacesStripWidth = 0.2`
---  * `hs.expose.ui.showTitles = true` - show window titles
---  * `hs.expose.ui.showThumbnails = true` - show window thumbnails
---  * `hs.expose.ui.thumbnailAlpha = 0` - 0..1, opacity for thumbnails
---  * `hs.expose.ui.highlightThumbnailAlpha = 1` - 0..1, opacity for thumbnails of candidate windows
---  * `hs.expose.ui.highlightThumbnailStrokeWidth = 8` - thumbnail frame thickness for candidate windows
---  * `hs.expose.ui.maxHintLetters = 2` - if necessary, hints longer than this will be disambiguated with digits
---  * `hs.expose.ui.fitWindowsMaxIterations = 30` -- lower is faster, but higher chance of overlapping thumbnails
---  * `hs.expose.ui.fitWindowsInBackground = false` -- improves responsivenss, but can affect the rest of the config

-- TODO * `hs.expose.ui.fitWindowsMaxIterations = 3`
-- TODO * `hs.expose.ui.showExtraKeys = true` -- show non-hint keybindings at the top of the screen

expose.ui=setmetatable({},{
  __newindex=function(t,k,v) uiGlobal[k]=getColor(v) end,
  __index=function(t,k)return getColor(uiGlobal[k])end,
})



local function getHints(self,windows)
  local function hasSubHints(t)
    for k,v in pairs(t) do if type(k)=='string' and #k==1 then return true end end
  end
  local hints={apps={}}
  local reservedHint=1
  for _,screen in pairs(self.screens) do
    for id,w in pairs(screen.windows) do
      if not windows or windows[id] then
        local appname=stripUnicode(w.appname or '')
        while #appname<self.ui.maxHintLetters do
          appname=appname..tostring(reservedHint) reservedHint=reservedHint+1
        end
        w.appname=appname
        hints[#hints+1]=w
        hints.apps[appname]=(hints.apps[appname] or 0)+1
        w.hint=''
      end
    end
  end
  local function normalize(t,n) --change in place
    local _
    while #t>0 and tlen(t.apps)>0 do
      if n>self.ui.maxHintLetters or (tlen(t.apps)==1 and n>1 and not hasSubHints(t))  then
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

local function updateHighlights(ui,hints,subtree,entering,show)
  for c,t in pairs(hints) do
    if t==subtree then
      updateHighlights(ui,t,nil,entering,true)
    elseif type(c)=='string' and #c==1 then
      local w=t[1]
      if w then
        if ui.showThumbnails then
          if show then w.thumb:setAlpha(ui.highlightThumbnailAlpha) w.highlight:show()
          else w.thumb:setAlpha(ui.thumbnailAlpha) w.highlight:hide() end
        end
        if ui.showTitles then
          if show then w.titlerect:show() w.titletext:show()
          else w.titletext:hide() w.titlerect:hide() end
        end
        if show then
          w.hintrect:show()
          w.curhint=ssub('        ',1,#modals+(entering and 0 or -1))..ssub(w.hint,#modals+(entering and 1 or 0))
          w.hinttext:setText(w.curhint):show()
          w.icon:show()
        else
          w.hinttext:hide()
          w.hintrect:hide()
          w.icon:hide()
        end
        w.visible=show
      else updateHighlights(ui,t,subtree,entering,show) end
    end
  end
end

local function setMode(self,k,mode)
  if modes[k]==mode then return end
  modes[k]=mode
  for s,screen in pairs(self.screens) do
    if modes[k] then
      screen.bg:setFillColor(k=='close' and self.ui.closeModeBackgroundColor or self.ui.minimizeModeBackgroundColor)
    elseif s=='inv' then
      screen.bg:setFillColor(self.ui.nonVisibleStripBackgroundColor)
    elseif type(s)=='string' then
      screen.bg:setFillColor(self.ui.otherSpacesStripBackgroundColor)
    else
      screen.bg:setFillColor(self.ui.backgroundColor)
    end
  end
end

local enter--,setThumb

local function exit(self)
  self.log.vf('exit modal for hint #%d',#modals)
  tremove(modals).modal:exit()
  if #modals>0 then updateHighlights(self.ui,modals[#modals].hints,nil,false,true) return enter(self) end
  -- exit all
  local showThumbs,showTitles=self.ui.showThumbnails,self.ui.showTitles
  for _,s in pairs(self.screens) do
    for _,w in pairs(s.windows) do
      if showThumbs then w.thumb:hide() w.highlight:hide() end
      if showTitles then w.titletext:hide() w.titlerect:hide() end
      if w.icon then w.icon:hide() w.hinttext:hide() w.hintrect:hide() end
      --      if w.rect then w.rect:delete() end
      if w.textratio then w.textratio:hide() end
    end
    s.bg:hide()
  end
  tap:stop()
  fnreactivate,activeInstance=nil,nil
  --    return exitAll(self)
  --  end
  --  return enter(self)
end
local function exitAll(self,toFocus)
  self.log.d('exiting')
  while #modals>0 do exit(self) end
  if toFocus then
    self.log.i('focusing',toFocus)
    --    if toFocus:application():bundleID()~='com.apple.finder' then
    --    toFocus:focus()
    --    else
    timer.doAfter(0.25,function()toFocus:focus()end) -- el cap bugs out (desktop "floats" on top) if done directly
    --    end
  end
end

enter=function(self,hints)
  if not hints then modals[#modals].modal:enter()
  elseif hints[1] then
    --got a hint
    updateHighlights(self.ui,modals[#modals].hints,nil,false,true)
    local h,w=hints[1],hints[1].window
    local app,appname=w:application(),h.appname
    if modes.close then
      self.log.f('closing window (%s)',appname)
      w:close()
      hints[1]=nil
      -- close app
      if app then
        if #app:allWindows()==0 then
          self.log.f('quitting application %s',appname)
          app:kill()
        end
      end
      --      updateHighlights(self.ui,modals[#modals].hints,nil,false,true)
      return enter(self)
    elseif modes.min then
      self.log.f('toggling window minimized/hidden (%s)',appname)
      if w:isMinimized() then w:unminimize()
      elseif app:isHidden() then app:unhide()
      else w:minimize() end
      --      updateHighlights(self.ui,modals[#modals].hints,nil,false,true)
      return enter(self)
    else
      self.log.f('focusing window (%s)',appname)
      if w:isMinimized() then w:unminimize() end
      --      w:focus()
      return exitAll(self,w)
    end
  else
    if modals[#modals] then self.log.vf('exit modal %d',#modals) modals[#modals].modal:exit() end
    local modal=newmodal()
    modals[#modals+1]={modal=modal,hints=hints}
    modal:bind({},'escape',function()return exitAll(self)end)
    modal:bind({},'delete',function()return exit(self)end)
    for c,t in pairs(hints) do
      if type(c)=='string' and #c==1 then
        modal:bind({},c,function()updateHighlights(self.ui,hints,t,true) enter(self,t) end)
        modal:bind({self.ui.closeModeModifier},c,function()updateHighlights(self.ui,hints,t,true) enter(self,t) end)
        modal:bind({self.ui.minimizeModeModifier},c,function()updateHighlights(self.ui,hints,t,true) enter(self,t) end)
      end
    end
    self.log.vf('enter modal for hint #%d',#modals)
    modal:enter()
  end
end

local function spaceChanged()
  if not activeInstance then return end
  local temp=fnreactivate
  exitAll(activeInstance)
  return temp()
end

local function setThumbnail(w,screenFrame,thumbnails,titles,ui,bg)
  local wframe=w.frame
  if thumbnails then
    w.thumb:setFrame(wframe):orderAbove(bg)
    w.highlight:setFrame(wframe):orderAbove(w.thumb)
  end
  --  local hwidth=#w.hint*ui.hintLetterWidth
  local hintWidth=drawing.getTextDrawingSize(w.hint or '',ui.hintTextStyle).w
  local hintHeight=ui.hintHeight
  local padding=hintHeight*0.1
  local br=geom.copy(wframe):seth(hintHeight):setw(hintWidth+hintHeight+padding*4):setcenter(wframe.center):fit(screenFrame)
  local tr=geom.copy(br):setw(hintWidth+padding*2):move(hintHeight+padding*2,0)
  local ir=geom.copy(br):setw(hintHeight):move(padding,0)
  w.hintrect:setFrame(br):orderAbove(w.highlight or bg)
  w.hinttext:setFrame(tr):orderAbove(w.hintrect):setText(w.curhint or w.hint or ' ')
  w.icon:setFrame(ir):orderAbove(w.hintrect)

  if titles then
    local titleWidth=min(wframe.w,w.titleWidth)
    local tr=geom.copy(wframe):seth(ui.titleHeight):setw(titleWidth+8)
      :setcenter(wframe.center):move(0,ui.hintHeight):fit(screenFrame)
    w.titlerect:setFrame(tr):orderAbove(w.highlight or bg)
    w.titletext:setFrame(tr):orderAbove(w.titlerect)
  end
end


local UNAVAILABLE=image.imageFromName'NSStopProgressTemplate'

local function showExpose(self,windows,animate,alt_algo)
  -- animate is waaay to slow: don't bother
  -- alt_algo sometimes performs better in terms of coverage, but (in the last half-broken implementation) always reaches maxIterations
  -- alt_algo TL;DR: much slower, don't bother
  if not self.running then self.log.i('instance not running, cannot show expose') return end
  self.log.d('activated')
  local hints=getHints(self,windows)
  local ui=self.ui
  for sid,s in pairs(self.screens) do
    if animate and ui.showThumbnails then
      s.bg:show():orderBelow()
      for _,w in pairs(s.windows) do
        w.thumb = drawing.image(w.originalFrame,window.snapshotForID(w.id)):show() --FIXME
      end end
    fitWindows(self,s,ui.fitWindowsMaxIterations,animate and 0 or nil,alt_algo)
    local bg,screenFrame,thumbnails,titles=s.bg:show(),s.frame,s.thumbnails,ui.showTitles
    for id,w in pairs(s.windows) do
      if not windows or windows[id] then
        setThumbnail(w,screenFrame,thumbnails,titles,ui,bg)
        --      if showThumbs then w.thumb:show() w.highlight:show() end
        --      if showTitles then w.titlerect:show() w.titletext:show() end
        --      w.hintrect:show() w.hinttext:show() w.icon:show()
        if w.textratio then w.textratio:show() end
      end
    end
  end
  tap=eventtap.new({eventtap.event.types.flagsChanged},function(e)
    local function hasOnly(t,mod)
      local n=next(t)
      if n~=mod then return end
      if not next(t,n) then return true end
    end
    setMode(self,'close',hasOnly(e:getFlags(),self.ui.closeModeModifier))
    setMode(self,'min',hasOnly(e:getFlags(),self.ui.minimizeModeModifier))
  end)
  tap:start()
  enter(self,hints)
end

--- hs.expose:toggleShow([activeApplication])
--- Method
--- Toggles the expose - see `hs.expose:show()` and `hs.expose:hide()`
---
--- Parameters:
---  * activeApplication - (optional) if true, only show windows of the active application (within the scope of the instance windowfilter); otherwise show all windows allowed by the instance windowfilter
---
--- Returns:
---  * None
---
--- Notes:
---  * passing `true` for `activeApplication` will simply hide hints/thumbnails for applications other than the active one, without recalculating the hints layout; conversely, setting `onlyActiveApplication=true` for an expose instance's `ui` will calculate an optimal layout for the current active application's windows
---  * Completing a hint will exit the expose and focus the selected window.
---  * Pressing esc will exit the expose and with no action taken.
---  * If shift is being held when a hint is completed (the background will be red), the selected window will be closed. If it's the last window of an application, the application will be closed.
---  * If alt is being held when a hint is completed (the background will be blue), the selected  window will be minimized (if visible) or unminimized/unhidden (if minimized or hidden).
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
  if activeInstance then return exitAll(activeInstance) end
end
--- hs.expose:show([activeApplication])
--- Method
--- Shows an expose-like screen with modal keyboard hints for switching to, closing or minimizing/unminimizing windows.
---
--- Parameters:
---  * activeApplication - (optional) if true, only show windows of the active application (within the
---   scope of the instance windowfilter); otherwise show all windows allowed by the instance windowfilter
---
--- Returns:
---  * None
---
--- Notes:
---  * passing `true` for `activeApplication` will simply hide hints/thumbnails for applications other
---    than the active one, without recalculating the hints layout; conversely, setting `onlyActiveApplication=true`
---    for an expose instance's `ui` will calculate an optimal layout for the current active application's windows
---  * Completing a hint will exit the expose and focus the selected window.
---  * Pressing esc will exit the expose and with no action taken.
---  * If shift is being held when a hint is completed (the background will be red), the selected
---    window will be closed. If it's the last window of an application, the application will be closed.
---  * If alt is being held when a hint is completed (the background will be blue), the selected
---    window will be minimized (if visible) or unminimized/unhidden (if minimized or hidden).

local function getApplicationWindows()
  local a=application.frontmostApplication()
  if not a then log.w('cannot get active application') return end
  local r={}
  for _,w in ipairs(a:allWindows()) do r[w:id()]=w end
  return r
end

function expose:show(currentApp,...)
  if activeInstance then return end
  activeInstance=self
  fnreactivate=function()return self:show(currentApp)end
  return showExpose(self,currentApp and getApplicationWindows() or nil,...)
end

local bgRepeats=0
local function bgFitWindows()
  local rep
  for self in pairs(activeInstances) do
    local DEBUG,DEBUG_TIME=self.ui.DEBUG
    if DEBUG then DEBUG_TIME=timer.secondsSinceEpoch() end
    local iters=self.ui.fitWindowsInBackgroundMaxIterations --3--math.random(9)
    if self.dirty then
      for _,screen in pairs(self.screens) do
        if screen.dirty then fitWindows(self,screen,iters) rep=rep or screen.dirty end
        if activeInstance==self or DEBUG then
          for _,w in pairs(screen.windows) do
            if w.visible then setThumbnail(w,screen.frame,screen.thumbnails,self.ui.showTitles,self.ui,screen.bg) end
          end
        end
      end
    end
    if DEBUG then print(math.floor((timer.secondsSinceEpoch()-DEBUG_TIME)/iters*1000)..'ms per iteration - '..iters..' total') end
  end
  bgRepeats=bgRepeats-1
  if rep and bgRepeats>0 then bgFitTimer:start() end
end

function expose.STOP()
  bgFitTimer:stop()
  for i in pairs(activeInstances) do
    for _,s in pairs(i.screens) do
      for _,w in pairs(s.windows) do
        if w.thumb then w.thumb:hide() w.highlight:hide() end
        if w.titletext then w.titletext:hide() w.titlerect:hide() end
        if w.icon then w.icon:hide() w.hinttext:hide() w.hintrect:hide() end
        --      if w.rect then w.rect:delete() end
        if w.textratio then w.textratio:hide() end

      end
    end
  end
end
local function startBgFitWindows(ui)
  if activeInstance and not ui.fitWindowsInBackground then bgRepeats=2 return bgFitTimer:start(0.05) end
  bgRepeats=ui.fitWindowsInBackgroundMaxRepeats
  if bgRepeats>0 and ui.fitWindowsInBackground then
    bgFitTimer:start()
  end
end

local function windowRejected(self,win,appname,screen)
  local id=win:id()
  local w=self.windows[id]
  if not w then return end
  if screen.windows[id] then
    self.log.vf('window %s (%d) <- %s',appname,id,screen.name)
    screen.totalOriginalArea=screen.totalOriginalArea-w.originalFrame.area
    screen.windows[id]=nil
    screen.dirty=true
    return startBgFitWindows(self.ui)
  end
end

local function windowDestroyed(self,win,appname,screen)
  local id=win:id()
  local w=self.windows[id]
  if not w then return end
  windowRejected(self,win,appname,screen)
  if w.thumb then w.thumb:delete() w.highlight:delete() end
  if w.titletext then w.titletext:delete() w.titlerect:delete() end
  w.hintrect:delete() w.hinttext:delete() w.icon:delete()
  self.windows[id]=nil
  self.dirty=true
end

local function getTitle(self,w)
  local title=w.window:title() or ' '
  w.titleWidth=drawing.getTextDrawingSize(title,self.ui.titleTextStyle).w
  w.titletext:setText(title)
end
local function windowAllowed(self,win,appname,screen)
  --  print('addwindow '..appname..' to '..screen.name)
  local id=win:id()
  local w=self.windows[id]
  if w then
    local prevScreen=w.screen
    w.screen=screen -- set new screen
    windowRejected(self,win,appname,prevScreen) --remove from previous screen
    local cached=w.frames[screen]
    self.log.vf('window %s (%d) -> %s%s',appname,id,screen.name,cached and ' [CACHED]' or '')
    w.frame=geom.copy(cached or w.originalFrame)
    w.dirty=not cached
    screen.windows[id]=w
    screen.totalOriginalArea=screen.totalOriginalArea+w.originalFrame.area
    screen.dirty=screen.dirty or not cached or true
    return startBgFitWindows(self.ui)
  end

  self.log.df('window %s (%d) created',appname,id)
  local ui=self.ui
  local f=win:frame()
  --  if not screen.thumbnails then f.aspect=1 local side=ui.minWidth f.area=side*side end
  local w={window=win,appname=appname,originalFrame=geom.copy(f),frame=f,ratio=1,frames={},id=id,screen=screen}
  if ui.showThumbnails then
    w.thumb=drawing.image(f,window.snapshotForID(id) or UNAVAILABLE):setAlpha(ui.highlightThumbnailAlpha)
      :setBehavior(BEHAVIOR)
    w.highlight=drawing.rectangle(f):setFill(false)
      :setStrokeWidth(ui.highlightThumbnailStrokeWidth):setStrokeColor(ui.highlightColor):setBehavior(BEHAVIOR)
    --      :orderAbove(w.thumb)
  end
  if ui.showTitles then
    w.titlerect=drawing.rectangle(f):setFill(true):setFillColor(ui.highlightColor)
      :setStroke(false):setRoundedRectRadii(ui.textSize/8,ui.textSize/8):setBehavior(BEHAVIOR)
    --      :orderAbove(w.thumb)
    w.titletext=drawing.text(f,' '):setTextStyle(ui.titleTextStyle):setBehavior(BEHAVIOR)--:orderAbove(w.titlerect)
    getTitle(self,w)
  end
  w.hintrect=drawing.rectangle(f):setFill(true):setFillColor(ui.highlightColor)
    :setStroke(true):setStrokeWidth(min(ui.textSize/10,ui.highlightThumbnailStrokeWidth)):setStrokeColor(ui.highlightColor)
    :setRoundedRectRadii(ui.textSize/4,ui.textSize/4):setBehavior(BEHAVIOR)
  --    :orderAbove(w.thumb)
  w.hinttext=drawing.text(f,' '):setTextStyle(ui.hintTextStyle):setBehavior(BEHAVIOR)--:orderAbove(w.hintrect)
  local bid=win:application():bundleID()
  local icon=bid and image.imageFromAppBundle(bid) or UNAVAILABLE
  w.icon=drawing.image(f,icon):setBehavior(BEHAVIOR)--:orderAbove(w.hintrect)
  w.textratio=drawing.text(f,''):setTextColor{red=1,alpha=1,blue=0,green=0}
  w.dirty=true
  screen.totalOriginalArea=screen.totalOriginalArea+f.area
  screen.windows[id]=w
  self.windows[id]=w
  screen.dirty=true
  self.dirty=true
  return startBgFitWindows(ui)
end
local function getSnapshot(w,id)
  if w.thumb then w.thumb:setImage(window.snapshotForID(id) or UNAVAILABLE) end
end
local function windowUnfocused(self,win,appname,screen)
  local id=win:id()
  if screen.windows then
    local w=screen.windows[id]
    if w then return getSnapshot(w,id) end
  end
end
local function windowMoved(self,win,appname,screen)
  local id=win:id() local w=screen.windows[id]
  if not w then return end
  local frame=win:frame()
  w.frame=frame w.originalFrame=frame w.frames={}--[screen]=nil
  screen.dirty=true w.dirty=true
  getSnapshot(w,id)
  return startBgFitWindows(self.ui)
end


local function titleChanged(self,win,appname,screen)
  if not self.ui.showTitles then return end
  local id=win:id() local w=screen.windows[id]
  if w then return getTitle(self,w) end
end

local function resume(self)
  if not activeInstances[self] then self.log.i('instance stopped, ignoring resume') return self end
  -- subscribe
  for _,s in pairs(self.screens) do
    s.callbacks={
      [windowfilter.windowAllowed]=function(win,a)
        self.log.vf('%s: window %s allowed',s.name,a)
        return windowAllowed(self,win,a,s)
      end,
      [windowfilter.windowRejected]=function(win,a)
        self.log.vf('%s: window %s rejected',s.name,a)
        return windowRejected(self,win,a,s)
      end,
      [windowfilter.windowDestroyed]=function(win,a)
        self.log.vf('%s: window %s destroyed',s.name,a)
        return windowDestroyed(self,win,a,s)
      end,
      [windowfilter.windowMoved]=function(win,a)
        self.log.vf('%s: window %s moved',s.name,a)
        return windowMoved(self,win,a,s)
      end,
      [windowfilter.windowUnfocused]=function(win,a)
        return windowUnfocused(self,win,a,s)
      end,
      [windowfilter.windowTitleChanged]=function(win,a)
        return titleChanged(self,win,a,s)
      end,
    }
    s.wf:subscribe(s.callbacks)
    for _,w in ipairs(s.wf:getWindows()) do
      windowAllowed(self,w,w:application():name(),s)
    end
  end
  self.running=true
  self.log.i'instance resumed'
  return self
end

local function pause(self)
  if not activeInstances[self] then self.log.i('instance stopped, ignoring pause') return self end
  -- unsubscribe
  if activeInstance==self then exitAll(self) end
  for _,s in pairs(self.screens) do
    s.wf:unsubscribe(s.callbacks)
  end
  self.running=nil
  self.log.i'instance paused'
  return self
end

local function deleteScreens(self)
  for id,s in pairs(self.screens) do
    s.wf:delete() -- remove previous wfilters
    s.bg:delete()
  end
  self.screens={}
  for id,w in pairs(self.windows) do
    if w.thumb then w.thumb:delete() w.highlight:delete() end
    if w.titletext then w.titletext:delete() w.titlerect:delete() end
    w.hintrect:delete() w.hinttext:delete() w.icon:delete()
  end
  self.windows={}
end

local function makeScreens(self)
  self.log.i'populating screens'
  local wfLogLevel=windowfilter.getLogLevel()
  deleteScreens(self)
  windowfilter.setLogLevel('warning')
  -- gather screens
  local activeApplication=self.ui.onlyActiveApplication and true or nil
  local hsscreens=screen.allScreens()
  local screens={}
  for _,scr in ipairs(hsscreens) do -- populate current screens
    local sid,sname,sframe=scr:id(),scr:name(),scr:frame()
    if sid and sname then
      local wf=windowfilter.copy(self.wf,'wf-'..self.__name..'-'..sid):setDefaultFilter{}
        :setOverrideFilter{visible=true,currentSpace=true,allowScreens=sid,activeApplication=activeApplication}:keepActive()
      screens[sid]={name=sname,wf=wf,windows={},frame=sframe,totalOriginalArea=0,thumbnails=self.ui.showThumbnails,edge=geom.new(0,0),
        bg=drawing.rectangle(sframe):setFill(true):setFillColor(self.ui.backgroundColor):setBehavior(BEHAVIOR)}
      self.log.df('screen %s',scr:name())
    end
  end
  if not next(screens) then self.log.w'no valid screens found' windowfilter.setLogLevel(wfLogLevel) return end
  if self.ui.includeNonVisible then
    do -- hidden windows strip
      local msid=hsscreens[1]:id()
      local f=screens[msid].frame
      local pos=self.ui.nonVisibleStripPosition
      local width=self.ui.nonVisibleStripWidth
      local swidth=f[(pos=='left' or pos=='right') and 'w' or 'h']
      if width<1 then width=swidth*width end
      local thumbnails=self.ui.showThumbnails and width/swidth>=0.1
      local invf,edge=geom.copy(f),geom.new(0,0)
      --    local dock = execute'defaults read com.apple.dock "orientation"':sub(1,-2)
      -- calling execute takes 100ms every time, make this a ui preference instead
      if pos=='left' then f.w=f.w-width f.x=f.x+width invf.w=width edge:move(-200,0)
      elseif pos=='right' then f.w=f.w-width invf.x=f.x+f.w invf.w=width edge:move(200,0)
      else pos='bottom' f.h=f.h-width invf.y=f.y+f.h invf.h=width edge:move(0,200) end --bottom
      local wf=windowfilter.copy(self.wf,'wf-'..self.__name..'-invisible'):setDefaultFilter{}
        :setOverrideFilter{visible=false,activeApplication=activeApplication}:keepActive()
      screens.inv={name='invisibleWindows',isStrip=true,wf=wf,windows={},totalOriginalArea=0,frame=invf,thumbnails=thumbnails,edge=edge,pos=pos,
        bg=drawing.rectangle(invf):setFill(true):setFillColor(self.ui.nonVisibleStripBackgroundColor):setBehavior(BEHAVIOR)}
      screens[msid].bg:setFrame(f)
      self.log.d'invisible windows'
    end
  end
  if self.ui.includeOtherSpaces then
    for sid,screen in pairs(screens) do -- other spaces strip
      if not screen.isStrip then
        local f=screen.frame
        local othf,edge=geom.copy(f),geom.new(0,0)
        local pos=self.ui.otherSpacesStripPosition
        local width=self.ui.otherSpacesStripWidth
        local fwidth=f[(pos=='left' or pos=='right') and 'w' or 'h']
        if width<1 then width=fwidth*width end
        local thumbnails=self.ui.showThumbnails and width/fwidth>=0.1
        if pos=='left' then f.w=f.w-width f.x=f.x+width othf.w=width edge:move(-200,0)
        elseif pos=='right' then f.w=f.w-width othf.x=f.x+f.w othf.w=width edge:move(200,0)
        elseif pos=='bottom' then f.h=f.h-width othf.y=f.y+f.h othf.h=width edge:move(0,200)
        else pos='top' f.h=f.h-width othf.y=f.y othf.h=width f.y=f.y+width edge:move(0,-200) end -- top
        local wf=windowfilter.copy(self.wf,'wf-'..self.__name..'-o'..sid):setDefaultFilter{}
          :setOverrideFilter{visible=true,currentSpace=false,allowScreens=sid,activeApplication=activeApplication}:keepActive()
        local name='other/'..screen.name
        screens['o'..sid]={name=name,isStrip=true,wf=wf,windows={},totalOriginalArea=0,frame=othf,thumbnails=thumbnails,edge=edge,pos=pos,
          bg=drawing.rectangle(othf):setFill(true):setFillColor(self.ui.otherSpacesStripBackgroundColor):setBehavior(BEHAVIOR)}
        screen.bg:setFrame(f)
        self.log.df('screen %s',name)
    end
    end
  end
  for _,screen in pairs(screens) do
    screen.frame:move(10,10):setw(screen.frame.w-20):seth(screen.frame.h-20) -- margin
  end
  self.screens=screens
  windowfilter.setLogLevel(wfLogLevel)
end
local function processScreensChanged()
  for self in pairs(activeInstances) do makeScreens(self) end
  for self in pairs(activeInstances) do resume(self) end
end

expose.screensChangedDelay=10
local function screensChanged()
  log.d('screens changed, pausing active instances')
  for self in pairs(activeInstances) do pause(self) end
  screensChangedTimer:start()
end


local function start(self)
  if activeInstances[self] then self.log.i('instance already started, ignoring') return self end
  activeInstances[self]=true
  if not screenWatcher then
    log.i('starting global watchers')
    screenWatcher=screen.watcher.new(screensChanged):start()
    screensChangedTimer=timer.delayed.new(expose.screensChangedDelay,processScreensChanged)
    spacesWatcher=spaces.watcher.new(spaceChanged):start()
    bgFitTimer=timer.delayed.new(BG_FIT_INTERVAL,bgFitWindows)
  end
  self.log.i'instance started'
  makeScreens(self)
  return resume(self)
end

local function stop(self)
  if not activeInstances[self] then self.log.i('instance already stopped, ignoring') return self end
  pause(self)
  deleteScreens(self)
  activeInstances[self]=nil
  self.log.i'instance stopped'
  if not next(activeInstances) then
    if screenWatcher then
      log.i('stopping global watchers')
      screenWatcher:stop() screenWatcher=nil
      screensChangedTimer:stop() screensChangedTimer=nil
      spacesWatcher:stop() spacesWatcher=nil
      bgFitTimer:stop() bgFitTimer=nil
    end
  end
  return self
end

function expose.stop(self)
  if self then return stop(self) end
  for i in pairs(activeInstances) do
    stop(i)
  end
end
-- return onScreenWindows, invisibleWindows, otherSpacesWindows

local inUiPrefs -- avoid recursion
local function setUiPrefs(self)
  inUiPrefs=true
  local ui=self.ui
  ui.hintTextStyle={font=ui.fontName,size=ui.textSize,color=ui.textColor}
  ui.titleTextStyle={font=ui.fontName,size=max(10,ui.textSize/2),color=ui.textColor,lineBreak='truncateTail'}
  ui.hintHeight=drawing.getTextDrawingSize('O',ui.hintTextStyle).h
  ui.titleHeight=drawing.getTextDrawingSize('O',ui.titleTextStyle).h
  local hintWidth=drawing.getTextDrawingSize(ssub('MMMMMMM',1,ui.maxHintLetters+1),ui.hintTextStyle).w
  ui.minWidth=hintWidth+ui.hintHeight*1.4--+padding*4
  ui.minHeight=ui.hintHeight*2
  --  ui.noThumbsFrameSide=ui.minWidth-- ui.textSize*4
  inUiPrefs=nil
end

--- hs.expose.new([windowfilter[, uiPrefs][, logname, [loglevel]]]) -> hs.expose object
--- Constructor
--- Creates a new hs.expose instance; it can use a windowfilter to determine which windows to show
---
--- Parameters:
---  * windowfilter - (optional) if omitted or nil, use the default windowfilter; otherwise it must be a windowfilter
---    instance or constructor table
---  * uiPrefs - (optional) a table to override UI preferences for this instance; its keys and values
---    must follow the conventions described in `hs.expose.ui`; this parameter allows you to have multiple
---    expose instances with different behaviour (for example, with and without thumbnails and/or titles)
---    using different hotkeys
---  * logname - (optional) name of the `hs.logger` instance for the new expose; if omitted, the class logger will be used
---  * loglevel - (optional) log level for the `hs.logger` instance for the new expose
---
--- Returns:
---  * the new instance
---
--- Notes:
---   * by default expose will show invisible windows and (unlike the OSX expose) windows from other spaces; use
---     `hs.expose.ui` or the `uiPrefs` parameter to change these behaviours.
function expose.new(wf,uiPrefs,logname,loglevel)
  if type(uiPrefs)=='string' then loglevel=logname logname=uiPrefs uiPrefs={} end
  if uiPrefs==nil then uiPrefs={} end
  if type(uiPrefs)~='table' then error('uiPrefs must be a table',2) end
  local self = setmetatable({screens={},windows={},__name=logname or 'expose'},{__index=expose,__gc=stop})
  self.log=logname and logger.new(logname,loglevel) or log
  self.setLogLevel=self.log.setLogLevel self.getLogLevel=self.log.getLogLevel
  if wf==nil then self.log.i('new expose instance, using default windowfilter') wf=windowfilter.default
  else self.log.i('new expose instance using windowfilter instance') wf=windowfilter.new(wf) end
  --uiPrefs
  self.ui=setmetatable({},{
    __newindex=function(t,k,v)rawset(self.ui,k,getColor(v))if not inUiPrefs then return setUiPrefs(self)end end,
    __index=function(t,k)return getColor(uiGlobal[k]) end,
  })
  for k,v in pairs(uiPrefs) do rawset(self.ui,k,getColor(v)) end setUiPrefs(self)
  --  local wfLogLevel=windowfilter.getLogLevel()
  --  windowfilter.setLogLevel('warning')
  --  self.wf=windowfilter.copy(wf):setDefaultFilter{} -- all windows; include fullscreen and invisible even for default wf
  --  windowfilter.setLogLevel(wfLogLevel)
  self.wf=wf
  return start(self)
end

return expose
