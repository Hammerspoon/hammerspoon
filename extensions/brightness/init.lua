--- === hs.brightness ===
---
--- Inspect/manipulate display brightness
---
--- The functions `hs.brightness.set()` and `hs.brightness.get()` should work on Apple-made screens (including
--- laptop screens).
---
--- If you have external non-Apple screens, you can use the `hs.brightness.DDCset()` and `hs.brightness.DDCget()`
--- functions; these (along with `hs.brightness.DDCauto()`) require an external utility called `ddcctl`
--- (https://github.com/kfix/ddcctl).
--- **WARNING:** before trying to use the `DDC\*` functions, make sure you understand the caveats listed in the
--- ddcctl project page; namely: **your Mac might crash and/or your screen might freeze or just not work with ddcctl**.
--- Make sure that your screens work properly with ddcctl *before* attempting to use the `DDC\*` functions in this module.

local screen=require'hs.screen'
local timer=require'hs.timer'
local windowfilter=require'hs.window.filter'
local redshift=require'hs.redshift'
local settings=require'hs.settings'
local SETTING_DDCSET='hs.brightness.ddcset.'
local bri = require("hs.brightness.internal")
local log=require'hs.logger'.new('brightness')
bri.setLogLevel=log.setLogLevel
local type,next,ipairs,pairs,tonumber,min,max,floor,abs=type,next,ipairs,pairs,tonumber,math.min,math.max,math.floor,math.abs
local tinsert,tsort,sformat,sfind,ssub,exec=table.insert,table.sort,string.format,string.find,string.sub,hs.execute

--- hs.brightness.ddcctl
--- Variable
--- In order to use the `hs.brightness.DDC\*` functions, set this to the full path of the `ddcctl` utility (e.g. "/usr/local/bin/ddcctl")
bri.ddcctl=nil
--- hs.brightness.DDCautoSmoothness
--- Variable
--- A number from 0 to 0.95 indicating the smoothness for brightness/contrast changes by `hs.brighntess.DDCauto()`;
--- if 0, changes will be abrupt; default value is 0.8
bri.DDCautoSmoothness=0.8
--- hs.brightness.DDCautoDisableWindowfilter
--- Variable
--- An `hs.window.filter` object that will disable automatic brightness/contrast control - i.e., set brightness and contrast
--- to the maximum values provided - whenever any window is allowed; alternatively, you can set this to a list of application
--- names (typically media apps and/or apps for color-sensitive work) and a windowfilter will be created
--- for you that disables brightness/contrast control whenever one of these apps is focused
bri.DDCautoDisableWindowfilter=nil
--- hs.brightness.DDCautoInvertBelowLux
--- Variable
--- A number indicating the ambient light intensity in lux (as returned by `hs.brightness.ambient()`) below which
--- `hs.brightness.DDCauto()` will apply color inversion (on all screens) via `hs.redshift`; default value is 0 (disabled)
---
--- Notes:
---  * color inversion requires `hs.redshift` to be started
bri.DDCautoInvertBelowLux=0

local screenCache={}
local function getScreenIndex(scr)
  if screenCache[scr] then return screenCache[scr] end
  scr=screen.find(scr)
  for i,s in ipairs(screen.allScreens()) do
    if s==scr then
      screenCache[scr]=i
      return i
    end
  end
end

local function ddcctl(scr,args)
  if not bri.ddcctl then error('hs.brightness.ddcctl is not set',3) end
  local i=getScreenIndex(scr)
  if not i then log.wf('cannot find screen %s',scr) return end
  local cmd=sformat('%s -d %d %s',bri.ddcctl,i,args)..' 2>&1'
  local s,ok=exec(cmd)
  if not ok then log.ef('ddcctl error: %s',s) return end
  if sfind(s,'DDC send command failed!',1,true) then log.ef('ddcctl error: %s',s) return end
  return s
end

--- hs.brightness.DDCget(screen) -> number, number
--- Function
--- Returns the current brightness and contrast of the given external screen
---
--- Parameters:
---  * screen - an `hs.screen` object, or argument for `hs.screen.find()`, indicating which screen to query
---
--- Returns
---  * the current brightness and contrast of the screen, or nil if an error occurred
function bri.DDCget(scr)
  local s=ddcctl(scr,'-b \\? -c \\?')
  if not s then return end
  local bri,con
  local _,ns=sfind(s,'#16 = current: ',1,true)
  if ns then
    local ne=sfind(s,',',ns,true)
    if ne then bri=tonumber(ssub(s,ns,ne-1)) end
  end
  _,ns=sfind(s,'#18 = current: ',1,true)
  if ns then
    local ne=sfind(s,',',ns,true)
    if ne then con=tonumber(ssub(s,ns,ne-1)) end
  end
  if not bri and not con then log.ef('cannot parse ddcctl output: %s',s) end
  return bri,con
end

--- hs.brightness.DDCset(screen,brightness,contrast) -> boolean
--- Function
--- Sets the brightness and/or contrast of the given external screen
---
--- Parameters:
---  * screen - an `hs.screen` object, or argument for `hs.screen.find()`, indicating which screen to affect
---  * brightness - a number between 0 and 100 indicating the desired brightness; if nil, brightness won't be changed
---  * contrast - a number between 0 and 100 indicating the desired contrast; if nil, contrast won't be changed
---
--- Returns
---  * true if the operation succeeded, false otherwise
function bri.DDCset(scr,bri,con)
  if type(bri)~='number' or bri<0 or bri>100 then bri=nil end
  if type(con)~='number' or con<0 or con>100 then con=nil end
  if not bri and not con then error('brightness, contrast must be numbers 0..100',2) end
  local s=ddcctl(scr,(bri and '-b '..bri or '')..(con and ' -c '..con or ''))
  if s then log.vf('DDC set screen %s bri:%d con:%d',screen.find(scr):name(),bri,con) end
  return s and true or false
end

local autoScreens,autoScreensRequested={},{}
local tmr,screenWatcher

local function ilerp(v,s,e) return min(1,max(0,(v-s)/(e-s))) end
local function lerpr(p,a,b) return floor(0.5+a*(1-p)+b*p) end
local function getValuesForLux(lux,args)
  for i=2,#args do
    local v2=args[i]
    if lux<=v2.lux then
      local v1=args[i-1]
      --TODO this probably needs to be logarithmic
      local p=ilerp(lux,v1.lux,v2.lux)
      return lerpr(p,v1.bri,v2.bri),lerpr(p,v1.con,v2.con)
    end
  end
end

local forcedLux,prevLux
local function getAmbient()
  if not next(autoScreens) then return end
  local actualLux=forcedLux or bri.ambient()
  if not prevLux then prevLux=actualLux end
  prevLux=forcedLux or prevLux
  if not actualLux or actualLux<0 then log.e('cannot get ambient light reading') return end
  local lux=prevLux*bri.DDCautoSmoothness+actualLux*(1-bri.DDCautoSmoothness)
  if floor(lux)~=floor(prevLux) then
    log.df('ambient light: %.0f lux (smoothed %.0f lux)',actualLux,lux)
  end
  prevLux=lux
  redshift.requestInvert('brightness.DDCauto',lux<=bri.DDCautoInvertBelowLux)
  --  local maxDiff=0
  for id,args in pairs(autoScreens) do
    local newbri,newcon=getValuesForLux(lux,args)
    local curbri,curcon=args.lastBri,args.lastCon
    --    maxDiff=max(maxDiff,max(abs(curbri-newbri),abs(curcon-newcon)))
    if newbri~=curbri or curcon~=newcon then
      log.df('screen %s ->bri:%d,con:%d',args.screenName,newbri,newcon)
      if bri.DDCset(args.screen,newbri,newcon) then
        args.lastBri=newbri args.lastCon=newcon
        settings.set(SETTING_DDCSET..id..'.bri',newbri)
        settings.set(SETTING_DDCSET..id..'.con',newcon)
      end
    end
  end
  local nextt=max(1,min(30,20*(bri.DDCautoSmoothness+0.1)*actualLux^0.5/(1+(abs(lux-actualLux)))))
  log.vf('next readout in %.2fs',nextt)
  tmr:start(nextt)
end

tmr=timer.delayed.new(30,getAmbient)
local wfDisable,modulewfDisable
local function pause() log.i('DDCauto paused')forcedLux=100000 getAmbient() tmr:stop() end
local function resume() log.i('DDCauto resumed')forcedLux=nil prevLux=nil getAmbient() end
local function getScreens()
  local t={}
  for scr,args in pairs(autoScreensRequested) do
    local s=screen.find(scr)
    if s then
      local minv,maxv
      for _,v in ipairs(args) do
        if not minv or v.lux<minv.lux then minv=v end
        if not maxv or v.lux>maxv.lux then maxv=v end
      end
      minv={lux=0,bri=minv.bri,con=minv.con} maxv={lux=100000,bri=maxv.bri,con=maxv.con}
      tinsert(args,minv) tinsert(args,maxv)
      tsort(args,function(a,b)return a.lux<b.lux end)

      local id=s:id()
      args.screen=s
      args.screenName=s:name()
      args.lastBri=settings.get(SETTING_DDCSET..id..'.bri') or floor((minv.bri+maxv.bri)/2)
      args.lastCon=settings.get(SETTING_DDCSET..id..'.con') or floor((minv.con+maxv.con)/2)
      t[id]=args
      if not autoScreens[id] then log.f('DDCauto started for screen %s',args.screenName or '???') end
      autoScreens[id]=nil
    end
  end
  for id,args in pairs(autoScreens) do
    log.f('DDCauto stopped for screen %s',args.screenName or '???')
  end
  autoScreens=t
  --  running=next(autoScreens) and true or false
  if next(autoScreens) then if not tmr:running() then
    log.i('start reading ambient light sensor')
    prevLux=nil
    local wf=bri.DDCautoDisableWindowfilter
    if wf~=nil then
      if windowfilter.iswf(wf) then wfDisable=wf
      else
        wfDisable=windowfilter.new(wf,'wf-DDCauto',log.getLogLevel())
        modulewfDisable=wfDisable
        if type(wf=='table') then
          local isAppList=true
          for k,v in pairs(wf) do if type(k)~='number' or type(v)~='string' then isAppList=false break end end
          if isAppList then wfDisable:setOverrideFilter{focused=true} end
        end
      end
      wfDisable:subscribe(windowfilter.hasWindow,pause,true):subscribe(windowfilter.hasNoWindows,resume)
    end
    tmr:start(1)
  end
  elseif tmr:running() then
    tmr:stop()
    log.i('stop reading ambient light sensor')
    if wfDisable then
      if modulewfDisable then modulewfDisable:delete() modulewfDisable=nil
      else wfDisable:unsubscribe({pause,resume}) end
      wfDisable=nil
    end
  end
end
local tmrScreens=timer.delayed.new(8,getScreens)

--- hs.brightness.toggleDDCauto()
--- Function
--- Pauses or resumes automatic control of brightness/contrast for all screens
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * You should bind this function to a hotkey: `hs.hotkey.bind(HYPER,'f2','Auto Brightness',hs.brightness.toggleDDCauto)`
function bri.toggleDDCauto()
  if tmr:running() then return pause() else return resume() end
end

--- hs.brightness.DDCauto(screen,values)
--- Function
--- Starts or stops automatic control of brightness/contrast for the given external screen
---
--- Parameters:
---  * screen - an `hs.screen` object, or argument for `hs.screen.find()`, indicating which screen to affect
---  * values - if false or nil, stops automatic control for the screen; otherwise it must be a list of
---    (at least two) entries; each entry must be a table with the following keys/values:
---    * lux - ambient light intensity in lux (0 to 10000) (as returned by `hs.brightness.ambient()`)
---    * bri - desired brightness value (0 to 100) at the given lux
---    * con - desired contrast value (0 to 100) at the given lux
---
--- Returns:
---  * None
---
--- Notes:
---  * Automatic brightness/contrast control requires a functional ambient light sensor; make sure that
---    `hs.brightness.ambient()` returns correct values before using this function
---  * You don't need to worry about whether the screen is currently connected when calling this function;
---    automatic control will be started/stopped as needed as the screen is connected/disconnected
---  * When automatic control is started for at least one screen, this module will query the ambient
---    light sensor periodically, and apply appropriate brightness/contrast to the screen by interpolating
---    among the entries in `values`
---
--- Usage:
--- ```
--- hs.brightness.ddcctl = '/path/to/ddcctl'
--- hs.brightness.DDCautoInvertBelowLux = 10
--- hs.brightness.DDCautoDisableWindowfilter = {'VLC','Plex'}
--- hs.brightness.DDCauto('phl',{{lux=1,bri=10,con=20},{lux=14,bri=20,con=20},{lux=120,bri=70,con=40},{lux=200,bri=100,con=50}})
--- hs.brightness.DDCauto('dell',{{lux=1,bri=10,con=40},{lux=14,bri=20,con=40},{lux=120,bri=70,con=70},{lux=200,bri=100,con=75}})
--- ```
function bri.DDCauto(scr,args)
  local _=screen.find(scr) -- check argument
  if args then
    if type(args)~='table' or #args<2 then error('values must be a list of at least two entries',2) end
    log.f('DDCauto enabled for %s',scr)
    for _,values in ipairs(args) do
      if type(values)~='table' or not values.bri or not values.con then error('invalid entry in values',2) end
      if type(values.lux)~='number' or values.lux<0 or values.lux>10000 then error('invalid lux value in values',2) end
      if type(values.bri)~='number' or values.bri<0 or values.bri>100 then error('invalid bri value in values',2) end
      if type(values.con)~='number' or values.con<0 or values.con>100 then error('invalid con value in values',2) end
      log.df('@ %dlux: bri:%d, con:%d',values.lux,values.bri,values.con)
    end
  else log.i('DDCauto disabled for %s',scr) end
  autoScreensRequested[scr]=args or nil
  getScreens()
  if next(autoScreensRequested) then
    if not screenWatcher then screenWatcher=screen.watcher.new(function()tmr:stop()tmrScreens:start()end):start() end
  else
    if screenWatcher then screenWatcher:stop() screenWatcher=nil end
  end
end

return bri
