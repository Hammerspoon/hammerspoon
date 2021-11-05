--- === hs.window.switcher ===
---
--- Window-based cmd-tab replacement
---
--- Usage:
--- ```
--- -- set up your windowfilter
--- switcher = hs.window.switcher.new() -- default windowfilter: only visible windows, all Spaces
--- switcher_space = hs.window.switcher.new(hs.window.filter.new():setCurrentSpace(true):setDefaultFilter{}) -- include minimized/hidden windows, current Space only
--- switcher_browsers = hs.window.switcher.new{'Safari','Google Chrome'} -- specialized switcher for your dozens of browser windows :)
---
--- -- bind to hotkeys; WARNING: at least one modifier key is required!
--- hs.hotkey.bind('alt','tab','Next window',function()switcher:next()end)
--- hs.hotkey.bind('alt-shift','tab','Prev window',function()switcher:previous()end)
---
--- -- alternatively, call .nextWindow() or .previousWindow() directly (same as hs.window.switcher.new():next())
--- hs.hotkey.bind('alt','tab','Next window',hs.window.switcher.nextWindow)
--- -- you can also bind to `repeatFn` for faster traversing
--- hs.hotkey.bind('alt-shift','tab','Prev window',hs.window.switcher.previousWindow,nil,hs.window.switcher.previousWindow)
--- ```

local type,pairs=type,pairs
local min,max=math.min,math.max
local geom=require'hs.geometry'
local drawing,image=require'hs.drawing',require'hs.image'
local window,screen=require'hs.window',require'hs.screen'
local windowfilter=require'hs.window.filter'
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
  if not id then return UNAVAILABLE end
  local sn,now=snapshots[id],timer.secondsSinceEpoch()
  if not sn or sn[2]+SNAPSHOT_EXPIRY<now then snapshots[id]={window.snapshotForID(id) or UNAVAILABLE,now} end
  return snapshots[id][1]
end

local icons=setmetatable({},{__mode='kv'})
local function getIcon(bundle)
  if not bundle then return UNAVAILABLE
  elseif not icons[bundle] then icons[bundle]=image.imageFromAppBundle(bundle) or UNAVAILABLE end
  return icons[bundle]
end


--- hs.window.switcher.ui
--- Variable
--- Allows customization of the switcher behaviour and user interface
---
--- This table contains variables that you can change to customize the behaviour of the switcher and the look of the UI.
--- To have multiple switcher instances with different behaviour/looks, use the `uiPrefs` parameter for the constructor;
--- the passed keys and values will override those in this table for that particular instance.
---
--- The default values are shown in the right hand side of the assignements below.
---
--- To represent color values, you can use:
---  * a table {red=redN, green=greenN, blue=blueN, alpha=alphaN}
---  * a table {redN,greenN,blueN[,alphaN]} - if omitted alphaN defaults to 1.0
--- where redN, greenN etc. are the desired value for the color component between 0.0 and 1.0
---
---  * `hs.window.switcher.ui.textColor = {0.9,0.9,0.9}`
---  * `hs.window.switcher.ui.fontName = 'Lucida Grande'`
---  * `hs.window.switcher.ui.textSize = 16` - in screen points
---  * `hs.window.switcher.ui.highlightColor = {0.8,0.5,0,0.8}` - highlight color for the selected window
---  * `hs.window.switcher.ui.backgroundColor = {0.3,0.3,0.3,1}`
---  * `hs.window.switcher.ui.onlyActiveApplication = false` -- only show windows of the active application
---  * `hs.window.switcher.ui.showTitles = true` - show window titles
---  * `hs.window.switcher.ui.titleBackgroundColor = {0,0,0}`
---  * `hs.window.switcher.ui.showThumbnails = true` - show window thumbnails
---  * `hs.window.switcher.ui.thumbnailSize = 128` - size of window thumbnails in screen points
---  * `hs.window.switcher.ui.showSelectedThumbnail = true` - show a larger thumbnail for the currently selected window
---  * `hs.window.switcher.ui.selectedThumbnailSize = 384`
---  * `hs.window.switcher.ui.showSelectedTitle = true` - show larger title for the currently selected window

--  * `hs.window.switcher.ui.closeModeModifier = 'shift'` - "close mode" engaged while pressed (or 'cmd','ctrl','alt')
--  * `hs.window.switcher.ui.closeModeBackgroundColor = {0.7,0.1,0.1,1}` - background color while "close mode" is engaged
--  * `hs.window.switcher.ui.minimizeModeModifier = 'alt'` - "minimize mode" engaged while pressed
--  * `hs.window.switcher.ui.minimizeModeBackgroundColor = {0.1,0.2,0.3,1}` - background color while "minimize mode" is engaged
local uiGlobal = {
  textColor={1,1,1},
  fontName='Lucida Grande',
  textSize=16,

  backgroundColor={0.3,0.3,0.3,1},
  highlightColor={0.8,0.5,0,0.8},

  showTitles=true,
  titleBackgroundColor={0,0,0},
  showThumbnails=true,
  thumbnailSize=128,

  showSelectedThumbnail=true,
  selectedThumbnailSize=384,
  showSelectedTitle=true,
  showExtraKeys=true,
}
local function getColor(t) if type(t)~='table' or t.red or not t[1] then return t else return {red=t[1] or 0,green=t[2] or 0,blue=t[3] or 0,alpha=t[4] or 1} end end

switcher.ui=setmetatable({},{
  __newindex=function(_,k,v) uiGlobal[k]=getColor(v) end,
  __index=function(_,k)return getColor(uiGlobal[k])end,
})


local function setFrames(nwindows,drawings,ui)
  local haveThumbs,haveTitles=ui.showThumbnails,ui.showTitles
  local titleHeight=ui.titleHeight
  local screenFrame=drawings.screenFrame
  if not drawings.screenFrame then drawings.screenFrame=screen.mainScreen():frame() screenFrame=drawings.screenFrame end
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
    dr.selIconFrame=geom.copy(dr.selThumbFrame):setw(selSize/2):seth(selSize/2):move(selSize/4,selSize/2+selPadding)
    dr.highlightFrame=geom.copy(thumbFrame):move(-padding/2,-padding/2-titleHeight-titlePadding)
      :setw(size+padding):seth(size+padding+titleHeight+titlePadding)
    dr.selTitleFrame=geom.copy(selFrame):seth(selTitleHeight)
  end
  drawings.size=size
end


local function draw(windows,drawings,ui)
  if ui.showSelectedThumbnail then
    drawings.selRect:show()
    drawings.selThumb:show()
    drawings.selIcon:show()
  end
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
    drawings.selIcon:setImage(getIcon(win:application():bundleID())):setFrame(dr.selIconFrame)
  end
  if ui.showSelectedTitle then
    drawings.selTitleRect:setFrame(dr.selTitleFrame)
    drawings.selTitleText:setText(title):setFrame(dr.selTitleFrame)
  end
end

--TODO esc to quit; w to close; m to minimize (needs eventtap, which should also replace the checkmods timer)

local function exit(self)
  local selected=self.selected
  local windows,drawings,ui=self.windows,self.drawings,self.ui
  self.windows=nil
  self.selected=nil
  self.modsTimer=nil
  if not selected then return end
  self.drawDelayed:stop()
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
  if ui.showSelectedThumbnail then drawings.selThumb:hide() drawings.selIcon:hide() end
  if ui.showSelectedTitle then drawings.selTitleRect:hide() drawings.selTitleText:hide() end
  log.i('focusing',windows[selected])
  windows[selected]:unminimize()
  --  if windows[selected]:application():bundleID()~='com.apple.finder' then
  --    windows[selected]:focus()
  --  else
  timer.doAfter(0.15,function()windows[selected]:focus()end) -- el cap bugs out (desktop "floats" on top) if done directly
  --  end
end

local MODS_INTERVAL=0.05 -- recheck for (lack of) mod keys after this interval
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
    self.drawDelayed=timer.doAfter(0.2,function()
      draw(windows,drawings,ui)
    end)
    self.modsTimer=timer.waitWhile(modsPressed,function()exit(self)end,MODS_INTERVAL)
    selected=1
    self.log.df('activated, %d windows',nwindows)

  elseif self.drawDelayed:running() then self.drawDelayed:stop() draw(windows,drawings,ui)
  end
  -- now also for subsequent invocations
  selected=selected+dir
  if selected<=0 then selected=nwindows
  elseif selected>nwindows then selected=1 end
  self.log.vf('window #%d selected',selected)
  self.selected=selected
  showSelected(selected,windows,drawings,ui)
end



--- hs.window.switcher:next()
--- Method
--- Shows the switcher instance (if not yet visible) and selects the next window
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * the switcher will be dismissed (and the selected window focused) when all modifier keys are released
function switcher:next() return show(self,1) end
--- hs.window.switcher:previous()
--- Method
--- Shows the switcher instance (if not yet visible) and selects the previous window
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * the switcher will be dismissed (and the selected window focused) when all modifier keys are released
function switcher:previous() return show(self,-1) end

local defaultSwitcher
local function makeDefault()
  defaultSwitcher=switcher.new(nil,nil,'wswtch-def')
  return defaultSwitcher
end

--- hs.window.switcher.nextWindow()
--- Function
--- Shows the switcher (if not yet visible) and selects the next window
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * the switcher will be dismissed (and the selected window focused) when all modifier keys are released
function switcher.nextWindow() return show(defaultSwitcher or makeDefault(),1) end
--- hs.window.switcher.previousWindow()
--- Function
--- Shows the switcher (if not yet visible) and selects the previous window
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * the switcher will be dismissed (and the selected window focused) when all modifier keys are released
function switcher.previousWindow() return show(defaultSwitcher or makeDefault(),-1) end

local function gc(self)
  self.log.i('windowswitcher instance deleted')
  self.screenWatcher:stop()
end


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
    drawings.selRect:delete()      drawings.selThumb:delete() drawings.selIcon:delete()
    drawings.selTitleRect:delete() drawings.selTitleText:delete()
  end
  drawings.background=drawing.rectangle(tempframe):setFillColor(ui.backgroundColor):setStroke(false)
  drawings.highlightRect=drawing.rectangle(tempframe):setFillColor(ui.highlightColor):setStroke(false)
  drawings.selRect=drawing.rectangle(tempframe):setRoundedRectRadii(selectedRectRadius,selectedRectRadius)
    :setStroke(false):setFillColor(ui.backgroundColor)
  drawings.selThumb=drawing.image(tempframe,UNAVAILABLE)
  drawings.selIcon=drawing.image(tempframe,UNAVAILABLE)
  drawings.selTitleRect=drawing.rectangle(tempframe):setFillColor(ui.titleBackgroundColor):setStroke(false)
    :setRoundedRectRadii(selectedRectRadius,selectedRectRadius)
  drawings.selTitleText=drawing.text(tempframe,' '):setTextStyle(selectedTitleTextStyle)
  inUiPrefs=nil
end


--- hs.window.switcher.new([windowfilter[, uiPrefs][, logname, [loglevel]]]) -> hs.window.switcher object
--- Constructor
--- Creates a new switcher instance; it can use a windowfilter to determine which windows to show
---
--- Parameters:
---  * windowfilter - (optional) if omitted or nil, use the default windowfilter; otherwise it must be a windowfilter
---    instance or constructor table
---  * uiPrefs - (optional) a table to override UI preferences for this instance; its keys and values
---    must follow the conventions described in `hs.window.switcher.ui`; this parameter allows you to have multiple
---    switcher instances with different behaviour (for example, with and without thumbnails and/or titles)
---    using different hotkeys
---  * logname - (optional) name of the `hs.logger` instance for the new switcher; if omitted, the class logger will be used
---  * loglevel - (optional) log level for the `hs.logger` instance for the new switcher
---
--- Returns:
---  * the new instance
function switcher.new(wf,uiPrefs,logname,loglevel)
  if type(uiPrefs)=='string' then loglevel=logname logname=uiPrefs uiPrefs={} end
  if uiPrefs==nil then uiPrefs={} end
  if type(uiPrefs)~='table' then error('uiPrefs must be a table',2) end
  local self = setmetatable({drawings={}},{__index=switcher,__gc=gc})
  self.log=logname and logger.new(logname,loglevel) or log
  self.setLogLevel=self.log.setLogLevel self.getLogLevel=self.log.getLogLevel
  if wf==nil then self.log.i('new windowswitcher instance, using default windowfilter') self.wf=windowfilter.default
  else self.log.i('new windowswitcher instance using windowfilter instance') self.wf=windowfilter.new(wf) end
  --uiPrefs
  self.ui=setmetatable({},{
    __newindex=function(_,k,v)rawset(self.ui,k,getColor(v)) return not inUiPrefs and setUiPrefs(self)end,
    __index=function(_,k)return getColor(uiGlobal[k]) end,
  })
  for k,v in pairs(uiPrefs) do rawset(self.ui,k,getColor(v)) end setUiPrefs(self)
  self.screenWatcher=screen.watcher.new(function() self.drawings.lastn=-1 self.drawings.screenFrame=nil end):start()
  return self
end

return switcher
