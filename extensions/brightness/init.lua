--- === hs.brightness ===
---
--- Inspect/manipulate display brightness
---
--- Home: https://github.com/asmagill/mjolnir_asm.sys
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).
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
-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

bri.ddcctl=nil--'/usr/local/bin/ddcctl'
bri.DDCautoSmoothness=0.8
bri.DDCautoDisableWindowfilter=nil
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
      local p=ilerp(lux,v1.lux,v2.lux)
      return lerpr(p,v1.bri,v2.bri),lerpr(p,v1.con,v2.con)
    end
  end
end

local forcedLux,prevLux
local function getAmbient()
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
  --  print(actualLux^0.5,abs(lux-actualLux))
  --  print(max(0,20*actualLux^0.5/(1+(abs(lux-actualLux)))))
  local nextt=max(1,min(30,20*(bri.DDCautoSmoothness+0.1)*actualLux^0.5/(1+(abs(lux-actualLux)))))
  log.vf('next readout in %.2fs',nextt)
  tmr:start(nextt)
end
--function bri.force(lux) forcedLux=lux getAmbient()end
tmr=timer.delayed.new(30,getAmbient)
local wfDisable,modulewfDisable
local function pause() forcedLux=100000 getAmbient() end
local function resume() forcedLux=nil prevLux=nil getAmbient() end
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
      args.lastBri=settings.get(SETTING_DDCSET..id..'.bri') or 50--floor((args.minBri+args.maxBri)/2)
      args.lastCon=settings.get(SETTING_DDCSET..id..'.con') or 50--floor((args.minCon+args.maxCon)/2)
      t[id]=args
      if not autoScreens[id] then log.f('autobrightness started for screen %s',args.screenName or '???') end
      autoScreens[id]=nil
    end
  end
  for id,args in pairs(autoScreens) do
    log.f('autobrightness stopped for screen %s',args.screenName or '???')
  end
  autoScreens=t
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
function bri.DDCauto(scr,args)
  local _=screen.find(scr) -- check argument
  if args then
    if type(args)~='table' then error('settings must be a table',2) end
    log.f('DDCauto enabled for %s',scr)
    for _,values in ipairs(args) do
      if type(values)~='table' or not values.bri or not values.con then error('invalid entry in settings',2) end
      if type(values.lux)~='number' or values.lux<0 or values.lux>10000 then error('invalid lux value in settings',2) end
      log.df('@ %dlux: bri:%d, con:%d%s',values.lux,values.bri,values.con,values.invert and ', invert' or '')
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
function bri.oldDDCauto(scr,minLux,minBri,minCon,maxLux,maxBri,maxCon)--,customArg,noRead)
  if minLux then log.f('DDCauto enabled for %s: %d/%d @ %dlux, %d/%d at %dlux',scr,minBri,minCon,minLux,maxBri,maxCon,maxLux)
  else log.f('DDCauto disabled for %s',scr) end
  autoScreensRequested[scr]=minLux and
    {minLux=minLux,minBri=minBri,minCon=minCon,maxLux=maxLux,maxBri=maxBri,maxCon=maxCon,} or nil
  --      lastBri=floor((minBri+maxBri)/2),lastCon=floor((minCon+maxCon)/2)} or nil
  getScreens()
  if next(autoScreensRequested) then
    if not screenWatcher then screenWatcher=screen.watcher.new(function()tmr:stop()tmrScreens:start()end):start() end
  else
    if screenWatcher then screenWatcher:stop() screenWatcher=nil end
  end
end
-- Return Module Object --------------------------------------------------

return bri



