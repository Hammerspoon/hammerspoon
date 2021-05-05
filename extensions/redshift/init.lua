--- === hs.redshift ===
---
--- Inverts and/or lowers the color temperature of the screen(s) on a schedule, for a more pleasant experience at night
---
--- Usage:
--- ```
--- -- make a windowfilterDisable for redshift: VLC, Photos and screensaver/login window will disable color adjustment and inversion
--- local wfRedshift=hs.window.filter.new({VLC={focused=true},Photos={focused=true},loginwindow={visible=true,allowRoles='*'}},'wf-redshift')
--- -- start redshift: 2800K + inverted from 21 to 7, very long transition duration (19->23 and 5->9)
--- hs.redshift.start(2800,'21:00','7:00','4h',true,wfRedshift)
--- -- allow manual control of inverted colors
--- hs.hotkey.bind(HYPER,'f1','Invert',hs.redshift.toggleInvert)
--- ```
---
--- Note:
---  * As of macOS 10.12.4, Apple provides "Night Shift", which implements a simple red-shift effect, as part of the OS. It seems unlikely that `hs.redshift` will see significant future development.

local screen=require'hs.screen'
local timer=require'hs.timer'
local windowfilter=require'hs.window.filter'
local settings=require'hs.settings'
local log=require'hs.logger'.new('redshift')
local redshift={setLogLevel=log.setLogLevel} -- module

local type,ipairs,pairs,next,floor,abs,min,max,sformat=type,ipairs,pairs,next,math.floor,math.abs,math.min,math.max,string.format

local SETTING_INVERTED_OVERRIDE='hs.redshift.inverted.override'
local SETTING_DISABLED_OVERRIDE='hs.redshift.disabled.override'
--local BLACKPOINT = {red=0.00000001,green=0.00000001,blue=0.00000001}
local BLACKPOINT = {red=0,green=0,blue=0}
--local COLORRAMP

local running,nightStart,nightEnd,dayStart,dayEnd,nightTemp,dayTemp
local tmr,tmrNext,applyGamma,screenWatcher
local invertRequests,invertCallbacks,invertAtNight,invertUser,prevInvert={},{}
local disableRequests,disableUser={}
local wfDisable,modulewfDisable

local function round(v) return floor(0.5+v) end
local function lerprgb(p,a,b) return {red=a[1]*(1-p)+b[1]*p,green=a[2]*(1-p)+b[2]*p,blue=a[3]*(1-p)+b[3]*p} end
local function ilerp(v,s,e,a,b)
  if s>e then
    if v<e then v=v+86400 end
    e=e+86400
  end
  local p=(v-s)/(e-s)
  return a*(1-p)+b*p
end
local function getGamma(temp)
  local R,lb,ub=redshift.COLORRAMP
  for k,_ in pairs(R) do
    if k<=temp then lb=max(lb or 0,k) else ub=min(ub or 10000,k) end
  end
  if lb==nil or ub==nil then local t=R[ub or lb] return {red=t[1],green=t[2],blue=t[3]} end
  local p=(temp-lb)/(ub-lb)
  return lerprgb(p,R[lb],R[ub])
    --  local idx=floor(temp/100)-9
    --  local p=(temp%100)/100
    --  return lerprgb(p,COLORRAMP[idx],COLORRAMP[idx+1])
end
local function between(v,s,e)
  if s<=e then return v>=s and v<=e else return v>=s or v<=e end
end

local function isInverted()
  if not running then return false end
  if invertUser~=nil then return invertUser and 'user'
  else return next(invertRequests) or false end
end
local function isDisabled()
  if not running then return true end
  if disableUser~=nil then return disableUser and 'user'
  else return next(disableRequests) or false end
end

-- core fn
applyGamma=function()
  if tmrNext then tmrNext:stop() tmrNext=nil end
  local now=timer.localTime()
  local temp,timeNext,invertReq
  if isDisabled() then temp=6500 timeNext=now-1 log.i('disabled')
  elseif between(now,nightStart,nightEnd) then temp=ilerp(now,nightStart,nightEnd,dayTemp,nightTemp) --dusk
  elseif between(now,dayStart,dayEnd) then temp=ilerp(now,dayStart,dayEnd,nightTemp,dayTemp) --dawn
  elseif between(now,dayEnd,nightStart) then temp=dayTemp timeNext=nightStart log.i('daytime')--day
  elseif between(now,nightEnd,dayStart) then invertReq=invertAtNight temp=nightTemp timeNext=dayStart log.i('nighttime')--night
  else error('wtf') end
  redshift.requestInvert('redshift-night',invertReq)
  local invert=isInverted()
  local gamma=getGamma(temp)
  log.df('set color temperature %dK (gamma %d,%d,%d)%s',floor(temp),round(gamma.red*100),
    round(gamma.green*100),round(gamma.blue*100),invert and (' - inverted by '..invert) or '')
  for _,scr in ipairs(screen.allScreens()) do
    scr:setGamma(invert and BLACKPOINT or gamma,invert and gamma or BLACKPOINT)
  end
  if invert~=prevInvert then
    log.i('inverted status changed',next(invertCallbacks) and '- notifying callbacks' or '')
    for _,fn in pairs(invertCallbacks) do fn(invert) end
    prevInvert=invert
  end
  if timeNext then
    tmrNext=timer.doAt(timeNext,applyGamma)
  else
    tmr:start()
  end
end

--- hs.redshift.invertSubscribe([id,]fn)
--- Function
--- Subscribes a callback to be notified when the color inversion status changes
---
--- Parameters:
---  * id - (optional) a string identifying the requester (usually the module name); if omitted, `fn` itself will be the identifier; this identifier must be passed to `hs.redshift.invertUnsubscribe()`
---  * fn - a function that will be called whenever color inversion status changes; it must accept a single parameter, a string or false as per the return value of `hs.redshift.isInverted()`
---
--- Returns:
---  * None
---
--- Notes:
---  * You can use this to dynamically adjust the UI colors in your modules or configuration, if appropriate.
function redshift.invertSubscribe(key,fn)
  if type(key)=='function' then fn=key end
  if type(key)~='string' and type(key)~='function' then error('invalid key',2) end
  if type(fn)~='function' then error('invalid callback',2) end
  invertCallbacks[key]=fn
  log.i('add invert callback',key)
  return running and fn(isInverted())
end
--- hs.redshift.invertUnsubscribe(id)
--- Function
--- Unsubscribes a previously subscribed color inversion change callback
---
--- Parameters:
---  * id - a string identifying the requester or the callback function itself, depending on how you
---    called `hs.redshift.invertSubscribe()`
---
--- Returns:
---  * None
function redshift.invertUnsubscribe(key)
  if not invertCallbacks[key] then return end
  log.i('remove invert callback',key)
  invertCallbacks[key]=nil
end

--- hs.redshift.isInverted() -> string or false
--- Function
--- Checks if the colors are currently inverted
---
--- Parameters:
---  * None
---
--- Returns:
---  * false if the colors are not currently inverted; otherwise, a string indicating the reason, one of:
---    * "user" for the user override (see `hs.redshift.toggleInvert()`)
---    * "redshift-night" if `hs.redshift.start()` was called with `invertAtNight` set to true,
---      and it's currently night time
---    * the ID string (usually the module name) provided to `hs.redshift.requestInvert()`, if another module requested color inversion
redshift.isInverted=isInverted

redshift.isDisabled=isDisabled

--- hs.redshift.requestInvert(id,v)
--- Function
--- Sets or clears a request for color inversion
---
--- Parameters:
---  * id - a string identifying the requester (usually the module name)
---  * v - a boolean indicating whether to invert the colors (if true) or clear any previous requests (if false or nil)
---
--- Returns:
---  * None
---
--- Notes:
---  * you can use this function e.g. to automatically invert colors if the ambient light sensor reading drops below
---    a certain threshold (`hs.brightness.DDCauto()` can optionally do exactly that)
---  * if the user's configuration doesn't explicitly start the redshift module, calling this will have no effect

local function request(t,k,v)
  if type(k)~='string' then error('key must be a string',3) end
  if v==false then v=nil end
  if t[k]~=v then t[k]=v return true end
end
function redshift.requestInvert(key,v)
  if request(invertRequests,key,v) then
    log.f('invert request from %s %s',key,v and '' or 'canceled')
    return running and applyGamma()
  end
end
function redshift.requestDisable(key,v)
  if request(disableRequests,key,v) then
    log.f('disable color adjustment request from %s %s',key,v and '' or 'canceled')
    return running and applyGamma()
  end
end

--- hs.redshift.toggleInvert([v])
--- Function
--- Sets or clears the user override for color inversion.
---
--- Parameters:
---  * v - (optional) a boolean; if true, the override will invert the colors no matter what; if false, the override will disable color inversion no matter what; if omitted or nil, it will toggle the override, i.e. clear it if it's currently enforced, or set it to the opposite of the current color inversion status otherwise.
---
--- Returns:
---  * None
---
--- Notes:
---  * This function should be bound to a hotkey, e.g.: `hs.hotkey.bind('ctrl-cmd','=','Invert',hs.redshift.toggleInvert)`
function redshift.toggleInvert(v)
  if not running then return end
  if v==nil and invertUser==nil then v=not isInverted() end
  if v~=nil and type(v)~='boolean' then error ('v must be a boolean or nil',2) end
  log.f('invert user override%s',v==true and ': inverted' or (v==false and ': not inverted' or ' cancelled'))
  if v==nil then settings.clear(SETTING_INVERTED_OVERRIDE)
  else settings.set(SETTING_INVERTED_OVERRIDE,v) end
  invertUser=v
  return applyGamma()
end

--- hs.redshift.toggle([v])
--- Function
--- Sets or clears the user override for color temperature adjustment.
---
--- Parameters:
---  * v - (optional) a boolean; if true, the override will enable color temperature adjustment on the given schedule; if false, the override will disable color temperature adjustment; if omitted or nil, it will toggle the override, i.e. clear it if it's currently enforced, or set it to the opposite of the current color temperature adjustment status otherwise.
---
--- Returns:
---  * None
---
--- Notes:
---  * This function should be bound to a hotkey, e.g.: `hs.hotkey.bind('ctrl-cmd','-','Redshift',hs.redshift.toggle)`
function redshift.toggle(v)
  if not running then return end
  if v==nil then
    if disableUser==nil then v=not isDisabled() end
  elseif type(v)~='boolean' then error ('v must be a boolean or nil',2)
  else v=not v end
  log.f('color adjustment user override%s',v==true and ': disabled' or (v==false and ': enabled' or ' cancelled'))
  if v==nil then settings.clear(SETTING_DISABLED_OVERRIDE)
  else settings.set(SETTING_DISABLED_OVERRIDE,v) end
  disableUser=v
  return applyGamma()
end

--- hs.redshift.stop()
--- Function
--- Stops the module and disables color adjustment and color inversion
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function redshift.stop()
  if not running then return end
  log.i('stopped')
  tmr:stop()
  screen.restoreGamma()
  if wfDisable then
    if modulewfDisable then modulewfDisable:delete() modulewfDisable=nil
    else wfDisable:unsubscribe(redshift.wfsubs) end
    wfDisable=nil
  end
  if tmrNext then tmrNext:stop() tmrNext=nil end
  screenWatcher:stop() screenWatcher=nil
  running=nil
end
local function gc(t) return t.stop()end

local function stime(time)
  return sformat('%02d:%02d:%02d',floor(time/3600),floor(time/60)%60,floor(time%60))
end

tmr=timer.delayed.new(10,applyGamma)
--- hs.redshift.start(colorTemp,nightStart,nightEnd[,transition[,invertAtNight[,windowfilterDisable[,dayColorTemp]]]])
--- Function
--- Sets the schedule and (re)starts the module
---
--- Parameters:
---  * colorTemp - a number indicating the desired color temperature (Kelvin) during the night cycle;
---    the recommended range is between 3600K and 1400K; lower values (minimum 1000K) result in a more pronounced adjustment
---  * nightStart - a string in the format "HH:MM" (24-hour clock) or number of seconds after midnight
---    (see `hs.timer.seconds()`) indicating when the night cycle should start
---  * nightEnd - a string in the format "HH:MM" (24-hour clock) or number of seconds after midnight
---    (see `hs.timer.seconds()`) indicating when the night cycle should end
---  * transition - (optional) a string or number of seconds (see `hs.timer.seconds()`) indicating the duration of
---    the transition to the night color temperature and back; if omitted, defaults to 1 hour
---  * invertAtNight - (optional) a boolean indicating whether the colors should be inverted (in addition to
---    the color temperature shift) during the night; if omitted, defaults to false
---  * windowfilterDisable - (optional) an `hs.window.filter` instance that will disable color adjustment
---    (and color inversion) whenever any window is allowed; alternatively, you can just provide a list of application
---    names (typically media apps and/or apps for color-sensitive work) and a windowfilter will be created
---    for you that disables color adjustment whenever one of these apps is focused
---  * dayColorTemp - (optional) a number indicating the desired color temperature (in Kelvin) during the day cycle;
---    you can use this to maintain some degree of "redshift" during the day as well, or, if desired, you can
---    specify a value higher than 6500K (up to 10000K) for more bluish colors, although that's not recommended;
---    if omitted, defaults to 6500K, which disables color adjustment and restores your screens' original color profiles
---
--- Returns:
---  * None
function redshift.start(nTemp,nStart,nEnd,dur,invert,wf,dTemp)
  if not dTemp then dTemp=6500 end
  if nTemp<1000 or nTemp>10000 or dTemp<1000 or dTemp>10000 then error('invalid color temperature',2) end
  nStart,nEnd=timer.seconds(nStart),timer.seconds(nEnd)
  dur=timer.seconds(dur or 3600)
  if dur>14400 then error('max transition time is 4h',2) end
  if abs(nStart-nEnd)<dur or abs(nStart-nEnd+86400)<dur
    or abs(nStart-nEnd-86400)<dur then error('nightTime too close to dayTime',2) end
  nightTemp,dayTemp=floor(nTemp),floor(dTemp)
  redshift.stop()

  invertAtNight=invert
  nightStart,nightEnd=(nStart-dur/2)%86400,(nStart+dur/2)%86400
  dayStart,dayEnd=(nEnd-dur/2)%86400,(nEnd+dur/2)%86400
  log.f('started: %dK @ %s -> %dK @ %s,%s %dK @ %s -> %dK @ %s',
    dayTemp,stime(nightStart),nightTemp,stime(nightEnd),invert and ' inverted,' or '',nightTemp,stime(dayStart),dayTemp,stime(dayEnd))
  running=true
  tmr:setDelay(max(1,dur/200))
  screenWatcher=screen.watcher.new(function()tmr:start(5)end):start()
  invertUser=settings.get(SETTING_INVERTED_OVERRIDE)
  disableUser=settings.get(SETTING_DISABLED_OVERRIDE)
  applyGamma()
  if wf~=nil then
    if windowfilter.iswf(wf) then wfDisable=wf
    else
      wfDisable=windowfilter.new(wf,'wf-redshift',log.getLogLevel())
      modulewfDisable=wfDisable
      if type(wf=='table') then
        local isAppList=true
        for k,v in pairs(wf) do
          if type(k)~='number' or type(v)~='string' then isAppList=false break end
        end
        if isAppList then wfDisable:setOverrideFilter{focused=true} end
      end
    end
    redshift.wfsubs={
      [windowfilter.hasWindow]=function()redshift.requestDisable('wf-redshift',true)end,
      [windowfilter.hasNoWindows]=function()redshift.requestDisable('wf-redshift')end,
    }
    wfDisable:subscribe(redshift.wfsubs,true)
  end
end

--- hs.redshift.COLORRAMP
--- Variable
--- A table holding the gamma values for given color temperatures; each key must be a color temperature number in K (useful values are between
--- 1400 and 6500), and each value must be a list of 3 gamma numbers between 0 and 1 for red, green and blue respectively.
--- The table must have at least two entries (a lower and upper bound); the actual gamma values used for a given color temperature
--- are linearly interpolated between the two closest entries; linear interpolation isn't particularly precise for this use case,
--- so you should provide as many values as possible.
---
--- Notes:
---  * `hs.inspect(hs.redshift.COLORRAMP)` from the console will show you how the table is built
---  * the default ramp has entries from 1000K to 10000K every 100K
redshift.COLORRAMP={ -- from https://github.com/jonls/redshift/blob/master/src/colorramp.c
  [1000]={1.00000000,  0.18172716,  0.00000000}, -- 1000K
  [1100]={1.00000000,  0.25503671,  0.00000000}, -- 1100K
  [1200]={1.00000000,  0.30942099,  0.00000000}, -- 1200K
  [1300]={1.00000000,  0.35357379,  0.00000000}, -- ...
  [1400]={1.00000000,  0.39091524,  0.00000000},
  [1500]={1.00000000,  0.42322816,  0.00000000},
  [1600]={1.00000000,  0.45159884,  0.00000000},
  [1700]={1.00000000,  0.47675916,  0.00000000},
  [1800]={1.00000000,  0.49923747,  0.00000000},
  [1900]={1.00000000,  0.51943421,  0.00000000},
  [2000]={1.00000000,  0.54360078,  0.08679949},
  [2100]={1.00000000,  0.56618736,  0.14065513},
  [2200]={1.00000000,  0.58734976,  0.18362641},
  [2300]={1.00000000,  0.60724493,  0.22137978},
  [2400]={1.00000000,  0.62600248,  0.25591950},
  [2500]={1.00000000,  0.64373109,  0.28819679},
  [2600]={1.00000000,  0.66052319,  0.31873863},
  [2700]={1.00000000,  0.67645822,  0.34786758},
  [2800]={1.00000000,  0.69160518,  0.37579588},
  [2900]={1.00000000,  0.70602449,  0.40267128},
  [3000]={1.00000000,  0.71976951,  0.42860152},
  [3100]={1.00000000,  0.73288760,  0.45366838},
  [3200]={1.00000000,  0.74542112,  0.47793608},
  [3300]={1.00000000,  0.75740814,  0.50145662},
  [3400]={1.00000000,  0.76888303,  0.52427322},
  [3500]={1.00000000,  0.77987699,  0.54642268},
  [3600]={1.00000000,  0.79041843,  0.56793692},
  [3700]={1.00000000,  0.80053332,  0.58884417},
  [3800]={1.00000000,  0.81024551,  0.60916971},
  [3900]={1.00000000,  0.81957693,  0.62893653},
  [4000]={1.00000000,  0.82854786,  0.64816570},
  [4100]={1.00000000,  0.83717703,  0.66687674},
  [4200]={1.00000000,  0.84548188,  0.68508786},
  [4300]={1.00000000,  0.85347859,  0.70281616},
  [4400]={1.00000000,  0.86118227,  0.72007777},
  [4500]={1.00000000,  0.86860704,  0.73688797},
  [4600]={1.00000000,  0.87576611,  0.75326132},
  [4700]={1.00000000,  0.88267187,  0.76921169},
  [4800]={1.00000000,  0.88933596,  0.78475236},
  [4900]={1.00000000,  0.89576933,  0.79989606},
  [5000]={1.00000000,  0.90198230,  0.81465502},
  [5100]={1.00000000,  0.90963069,  0.82838210},
  [5200]={1.00000000,  0.91710889,  0.84190889},
  [5300]={1.00000000,  0.92441842,  0.85523742},
  [5400]={1.00000000,  0.93156127,  0.86836903},
  [5500]={1.00000000,  0.93853986,  0.88130458},
  [5600]={1.00000000,  0.94535695,  0.89404470},
  [5700]={1.00000000,  0.95201559,  0.90658983},
  [5800]={1.00000000,  0.95851906,  0.91894041},
  [5900]={1.00000000,  0.96487079,  0.93109690},
  [6000]={1.00000000,  0.97107439,  0.94305985},
  [6100]={1.00000000,  0.97713351,  0.95482993},
  [6200]={1.00000000,  0.98305189,  0.96640795},
  [6300]={1.00000000,  0.98883326,  0.97779486},
  [6400]={1.00000000,  0.99448139,  0.98899179},
  [6500]={1.00000000,  1.00000000,  1.00000000}, -- 6500K
  --  [6500]={0.99999997,  0.99999997,  0.99999997}, --6500K
  [6600]={0.98947904,  0.99348723,  1.00000000},
  [6700]={0.97940448,  0.98722715,  1.00000000},
  [6800]={0.96975025,  0.98120637,  1.00000000},
  [6900]={0.96049223,  0.97541240,  1.00000000},
  [7000]={0.95160805,  0.96983355,  1.00000000},
  [7100]={0.94303638,  0.96443333,  1.00000000},
  [7200]={0.93480451,  0.95923080,  1.00000000},
  [7300]={0.92689056,  0.95421394,  1.00000000},
  [7400]={0.91927697,  0.94937330,  1.00000000},
  [7500]={0.91194747,  0.94470005,  1.00000000},
  [7600]={0.90488690,  0.94018594,  1.00000000},
  [7700]={0.89808115,  0.93582323,  1.00000000},
  [7800]={0.89151710,  0.93160469,  1.00000000},
  [7900]={0.88518247,  0.92752354,  1.00000000},
  [8000]={0.87906581,  0.92357340,  1.00000000},
  [8100]={0.87315640,  0.91974827,  1.00000000},
  [8200]={0.86744421,  0.91604254,  1.00000000},
  [8300]={0.86191983,  0.91245088,  1.00000000},
  [8400]={0.85657444,  0.90896831,  1.00000000},
  [8500]={0.85139976,  0.90559011,  1.00000000},
  [8600]={0.84638799,  0.90231183,  1.00000000},
  [8700]={0.84153180,  0.89912926,  1.00000000},
  [8800]={0.83682430,  0.89603843,  1.00000000},
  [8900]={0.83225897,  0.89303558,  1.00000000},
  [9000]={0.82782969,  0.89011714,  1.00000000},
  [9100]={0.82353066,  0.88727974,  1.00000000},
  [9200]={0.81935641,  0.88452017,  1.00000000},
  [9300]={0.81530175,  0.88183541,  1.00000000},
  [9400]={0.81136180,  0.87922257,  1.00000000},
  [9500]={0.80753191,  0.87667891,  1.00000000},
  [9600]={0.80380769,  0.87420182,  1.00000000},
  [9700]={0.80018497,  0.87178882,  1.00000000},
  [9800]={0.79665980,  0.86943756,  1.00000000},
  [9900]={0.79322843,  0.86714579,  1.00000000},
  [10000]={0.78988728,  0.86491137,  1.00000000}, -- 10000K
}
return setmetatable(redshift,{__gc=gc})
