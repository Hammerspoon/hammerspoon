--- === hs.window.switcher ===
---
--- Window-based cmd-tab replacement
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

--FIXME usage above

local next,type,ipairs,pairs=next,type,ipairs,pairs
local min,max=math.min,math.max
local geom=require'hs.geometry'
local drawing,image=require'hs.drawing',require'hs.image'
local window,screen=require'hs.window',require'hs.screen'
local windowfilter=require'hs.window.filter'
local application,spaces=require'hs.application',require'hs.spaces'
--local eventtap,timer,hotkey=require'hs.eventtap',require'hs.timer',require'hs.hotkey'
local timer=require'hs.timer'
local checkMods=require'hs.eventtap'.checkKeyboardModifiers
local logger=require'hs.logger'
local log=logger.new'wswitcher'
local switcher={setLogLevel=log.setLogLevel,getLogLevel=log.getLogLevel} -- module

local UNAVAILABLE=image.imageFromName'NSStopProgressTemplate'
local snapshots=setmetatable({},{__mode='kv'})
local SNAPSHOT_EXPIRY=60 --1m
local function getSnapshot(id)
  local sn,now=snapshots[id],timer.secondsSinceEpoch()
  if not sn or sn[2]+SNAPSHOT_EXPIRY<now then snapshots[id]={window.snapshotForID(id) or UNAVAILABLE,now} end
  return snapshots[id][1]
end

local icons=setmetatable({},{__mode='kv'})
local function getIcon(bundle)
  if not icons[bundle] then icons[bundle]=image.imageFromAppBundle(bundle) or UNAVAILABLE end
  return icons[bundle]
end

local uiGlobal = {
  backgroundColor={0.3,0.3,0.3,0.95},
  highlightColor={0.8,0.5,0,0.8},
  showThumbnails=true,
  thumbnailSize=128,
  showTitles=true,
  showSelectedThumbnail=true,
  showSelectedTitle=true,
  selectedThumbnailSize=768,
  --  selectedThumbnailSize=1024,
  showExtraKeys=true,

  textColor={0,0,0},
  textColor={1,1,1},
  fontName='Lucida Grande',
  textSize=16,
  titleBackgroundColor={1,1,1,0.8},
  titleBackgroundColor={0,0,0},

  highlightTextColor={1,1,1,1},
  fadeTextColor={0.2,0.2,0.2},
  highlightHintColor={0.2,0.1,0},
  fadeHintColor={0.1,0.1,0.1},

  closeModeBackgroundColor={0.7,0.1,0.1,0.95},
  minimizeModeBackgroundColor={0.1,0.3,0.6,0.95},
  minimizedStripPosition='bottom',
  minimizedStripBackgroundColor={0.15,0.15,0.15,0.95},
  minimizedStripWidth=200,

  fadeColor={0,0,0,0.8},
  fadeStrokeColor={0,0,0},
  highlightStrokeColor={0.8,0.5,0,0.8},
  strokeWidth=10,


  closeModeModifier = 'shift',
  minimizeModeModifier = 'alt',

}
local function getColor(t) if type(t)~='table' or t.red or not t[1] then return t else return {red=t[1] or 0,green=t[2] or 0,blue=t[3] or 0,alpha=t[4] or 1} end end

switcher.ui=setmetatable({},{
  __newindex=function(t,k,v) uiGlobal[k]=getColor(v) end,
  __index=function(t,k)return getColor(uiGlobal[k])end,
})


local function setFrames(nwindows,drawings,ui)
  local haveThumbs,haveTitles=ui.showThumbnails,ui.showTitles
  local titleHeight=ui.titleHeight
  local screenFrame=drawings.screenFrame
  if not drawings.screenFrame then drawings.screenFrame=screen.primaryScreen():frame() screenFrame=drawings.screenFrame end
  local padding=ui.thumbnailSize*0.1
  local size=min(ui.thumbnailSize,(screenFrame.w-padding*(nwindows+1))/nwindows)
  padding=size*0.1
  local titlePadding=haveTitles and padding or 0

  local selSize=ui.selectedThumbnailSize
  local selPadding=ui.selectedPadding
  local selTitleHeight=ui.selectedTitleHeight
  local selHeight=selSize+selPadding*2+selTitleHeight
  local bgframe=geom(0,0,(size+padding)*nwindows+padding,size+padding+titleHeight+titlePadding):setcenter(screenFrame.center)
  bgframe:move(0,max(0,screenFrame.y+selHeight-bgframe.y))
  drawings.background:setFrame(bgframe):setRoundedRectRadii(padding,padding)
  for i=1,nwindows do
    local dr=drawings[i]
    local thumbFrame=geom(bgframe.x,bgframe.y,size,size):move(padding+(size+padding)*(i-1),padding/2+titleHeight+titlePadding)
    local iconFrame=geom.copy(thumbFrame)
    if haveThumbs then
      dr.thumb:setFrame(thumbFrame)
      iconFrame:setw(size/2):seth(size/2):move(size/4,size/2)
    end
    dr.icon:setFrame(iconFrame)
    if haveTitles then
      dr.titleFrame=geom.copy(thumbFrame):seth(titleHeight):move(0,-titlePadding-titleHeight)
    end
    local selFrame=geom.copy(thumbFrame):setw(selSize+selPadding*2):seth(selSize+selPadding*2+selTitleHeight)
      :setcenter(thumbFrame.center):move(0,-selSize/2-size/2-padding*1.5-selPadding-selTitleHeight)
    if selFrame.x<screenFrame.x then selFrame.x=screenFrame.x
    elseif selFrame.x2>screenFrame.x2 then selFrame.x=screenFrame.x2-selFrame.w end
    dr.selRectFrame=selFrame
    dr.selThumbFrame=geom.copy(selFrame):setw(selSize):seth(selSize):move(selPadding,selPadding+selTitleHeight)
    dr.highlightFrame=geom.copy(thumbFrame):move(-padding/2,-padding/2-titleHeight-titlePadding)
      :setw(size+padding):seth(size+padding+titleHeight+titlePadding)
    dr.selTitleFrame=geom.copy(selFrame):seth(selTitleHeight)
  end
  drawings.size=size
end


local function draw(windows,drawings,ui)
  drawings.selRect:show()
  if ui.showSelectedThumbnail then drawings.selThumb:show() end
  if ui.showSelectedTitle then
    drawings.selTitleRect:show() drawings.selTitleText:show()
  end
  local haveThumbs,haveTitles=ui.showThumbnails,ui.showTitles
  drawings.background:show()
  drawings.highlightRect:show()
  local size=drawings.size
  for i=1,#windows do
    local win,dr=windows[i],drawings[i]
    if haveThumbs then dr.thumb:setImage(getSnapshot(win:id())):show() end
    dr.icon:setImage(getIcon(win:application():bundleID())):show()
    if haveTitles then
      local title=win:title() or ' '
      local titleFrame=dr.titleFrame
      local titleWidth=drawing.getTextDrawingSize(title,ui.titleTextStyle).w*1.1
      if titleWidth<titleFrame.w then titleFrame:setw(titleWidth):move((size-titleWidth)/2,0) end
      dr.titleRect:setFrame(titleFrame):show()
      dr.titleText:setFrame(titleFrame):setText(title):show()
    end
  end
end


local function showSelected(selected,windows,drawings,ui)
  local win,dr=windows[selected],drawings[selected]
  local title=win:title() or ' '
  drawings.highlightRect:setFrame(dr.highlightFrame)
  drawings.selRect:setFrame(dr.selRectFrame)
  if ui.showSelectedThumbnail then
    drawings.selThumb:setImage(getSnapshot(win:id())):setFrame(dr.selThumbFrame)
  end
  if ui.showSelectedTitle then
    drawings.selTitleRect:setFrame(dr.selTitleFrame)
    drawings.selTitleText:setText(title):setFrame(dr.selTitleFrame)
  end
end

local function exit(self)
  local selected=self.selected
  log.d('exited',selected)
  local windows,drawings,ui=self.windows,self.drawings,self.ui
  self.windows=nil
  self.selected=nil
  self.modsTimer=nil
  if not selected then return end
  local haveThumbs,haveTitles=ui.showThumbnails,ui.showTitles
  drawings.background:hide()
  drawings.highlightRect:hide()
  for i=1,#windows do
    local dr=drawings[i]
    dr.icon:hide()
    if haveThumbs then dr.thumb:hide() end
    if haveTitles then dr.titleRect:hide() dr.titleText:hide() end
  end
  drawings.selRect:hide()
  if ui.showSelectedThumbnail then drawings.selThumb:hide() end
  if ui.showSelectedTitle then drawings.selTitleRect:hide() drawings.selTitleText:hide() end
  timer.doAfter(0.15,function()windows[selected]:focus()end) -- el cap bugs out (finder "floats" on top) if done directly
end


local MODS_INTERVAL=0.1 -- recheck for (lack of) mod keys after this interval
local function modsPressed() return checkMods(true)._raw>0 end
local function show(self,dir)
  local windows,drawings,ui=self.windows,self.drawings,self.ui
  if not windows then
    windows=self.wf:getWindows(windowfilter.sortByFocusedLast)
    self.windows=windows
  end
  local nwindows=#windows or 0
  if nwindows==0 then self.log.i('no windows') return end
  local selected=self.selected
  if not selected then -- fresh invocation, prep everything
    local _
    if nwindows>#drawings then -- need new drawings
      self.log.vf('found %d new windows',nwindows-#drawings)
      local tempframe=geom(0,0,1,1)
      for n=#drawings+1,nwindows do
        local t={icon=drawing.image(tempframe,UNAVAILABLE)}
        if ui.showThumbnails then t.thumb=drawing.image(tempframe,UNAVAILABLE) end
        if ui.showTitles then
          t.titleRect=drawing.rectangle(tempframe):setRoundedRectRadii(ui.titleRectRadius,ui.titleRectRadius)
            :setFillColor(ui.titleBackgroundColor):setStroke(false)
          t.titleText=drawing.text(tempframe,' '):setTextStyle(ui.titleTextStyle)
        end
        drawings[n]=t
      end
    end
    if nwindows~=drawings.lastn then -- they all must move
      setFrames(nwindows,drawings,ui)
      drawings.lastn=nwindows
    end
    draw(windows,drawings,ui)
    self.modsTimer=timer.waitWhile(modsPressed,function()exit(self)end,MODS_INTERVAL)
    selected=1
    self.log.df('activated, %d windows',nwindows)
  end
  -- now also for subsequent invocations
  selected=selected+dir
  if selected<=0 then selected=nwindows
  elseif selected>nwindows then selected=1 end
  self.log.vf('window #%d selected',selected)
  self.selected=selected
  showSelected(selected,windows,drawings,ui)
end


--TODO docs: needs a hotkey! bind to repeatfn as well!
function switcher:next(...) return show(self,1) end
function switcher:previous(...) return show(self,-1) end


local inUiPrefs --recursion avoidance semaphore
local function setUiPrefs(self)
  inUiPrefs=true
  local ui=self.ui
  if ui.showTitles then
    ui.titleTextStyle={font=ui.fontName,size=ui.textSize,color=ui.textColor,lineBreak='truncateTail'}
    ui.titleRectRadius=ui.textSize/4
    ui.titleHeight=drawing.getTextDrawingSize('O',ui.titleTextStyle).h
  else ui.titleHeight=0 end
  local selectedRectRadius=0
  local selectedTitleTextStyle={font=ui.fontName,size=math.floor(ui.textSize*2),color=ui.textColor,lineBreak='truncateTail',alignment='center'}
  if ui.showSelectedTitle then
    ui.selectedTitleHeight=drawing.getTextDrawingSize('O',selectedTitleTextStyle).h
    selectedRectRadius=selectedTitleTextStyle.size/4
  else ui.selectedTitleHeight=0 end
  if ui.showSelectedThumbnail then
    ui.selectedPadding=ui.selectedThumbnailSize/10
  else ui.selectedThumbnailSize,ui.selectedPadding=0,0 end

  ui.selectedHeight=ui.selectedThumbnailSize+ui.selectedPadding*2+ui.selectedTitleHeight
  self.ui=ui

  local tempframe=geom.new(-5,0,1,1)
  local drawings=self.drawings
  if drawings.background then
    drawings.background:delete()   drawings.highlightRect:delete()
    drawings.selRect:delete()      drawings.selThumb:delete()
    drawings.setTitleRect:delete() drawings.selTitleText:delete()
  end
  drawings.background=drawing.rectangle(tempframe):setFillColor(ui.backgroundColor):setStroke(false)
  drawings.highlightRect=drawing.rectangle(tempframe):setFillColor(ui.highlightColor):setStroke(false)
  drawings.selRect=drawing.rectangle(tempframe):setRoundedRectRadii(selectedRectRadius,selectedRectRadius)
    :setStroke(false):setFillColor(ui.backgroundColor)
  drawings.selThumb=drawing.image(tempframe,UNAVAILABLE)
  drawings.selTitleRect=drawing.rectangle(tempframe):setFillColor(ui.titleBackgroundColor):setStroke(false)
    :setRoundedRectRadii(selectedRectRadius,selectedRectRadius)
  drawings.selTitleText=drawing.text(tempframe,' '):setTextStyle(selectedTitleTextStyle)
  inUiPrefs=nil
end

local function gc(self)
  self.log.i('stopping windowswitcher instance')
  self.screenWatcher:stop()
end

function switcher.new(wf,uiPrefs,logname,loglevel)
  if type(uiPrefs)=='string' then loglevel=logname logname=uiPrefs uiPrefs={} end
  if uiPrefs==nil then uiPrefs={} end
  if type(uiPrefs)~='table' then error('uiPrefs must be a table',2) end
  local self = setmetatable({drawings={}},{__index=switcher,__gc=gc})
  self.log=logname and logger.new(logname,loglevel) or log
  self.setLogLevel=self.log.setLogLevel self.getLogLevel=self.log.getLogLevel
  if wf==nil then self.log.i('New windowswitcher instance, using default windowfilter') self.wf=windowfilter.default
  else self.log.i('New windowswitcher instance using windowfilter instance') self.wf=windowfilter.new(wf) end
  --uiPrefs
  self.ui=setmetatable({},{
    __newindex=function(t,k,v)rawset(self.ui,k,getColor(v)) return not inUiPrefs and setUiPrefs(self)end,
    __index=function(t,k)return getColor(uiGlobal[k]) end,
  })
  for k,v in pairs(uiPrefs) do rawset(self.ui,k,getColor(v)) end setUiPrefs(self)
  self.screenWatcher=screen.watcher.new(function() self.drawings.lastn=-1 self.drawings.screenFrame=nil end):start()
  return self
end

return switcher
  

