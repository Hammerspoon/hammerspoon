
local screen=require'hs.screen'
local timer=require'hs.timer'
local windowfilter=require'hs.window.filter'
local settings=require'hs.settings'
local log=require'hs.logger'.new('redshift',5)
local redshift={setLogLevel=log.setLogLevel} -- module

local type,ipairs,floor,abs,max,sformat=type,ipairs,math.floor,math.abs,math.max,string.format

local SETTING_INVERTED='hs.redshift.inverted'
local BLACKPOINT = {red=0.00000001,green=0.00000001,blue=0.00000001}
--local WHITEPOINT = {red=0.9999999,green=0.9999999,blue=0.9999999}
local COLORRAMP

local running,nightStart,nightEnd,dayStart,dayEnd,nightTemp,dayTemp
local tmr,tmrNext,applyGamma,screenWatcher
local invertAtNight,invertManual
local wfDisable,modulewfDisable

local function lerprgb(p,a,b) return {red=a[1]*(1-p)+b[1]*p,green=a[2]*(1-p)+b[2]*p,blue=a[3]*(1-p)+b[3]*p} end
--local function lerp(p,a,b) return a*(1-p)+b*p end
local function ilerp(v,s,e,a,b)
  if s>e then
    if v<e then v=v+86400 end
    e=e+86400
  end
  local p=(v-s)/(e-s)
  return a*(1-p)+b*p
    --  return lerp(,a,b)
end
local function round(v) return floor(0.5+v) end

local function getGamma(temp)
  local idx=floor(temp/100)-9
  local p=(temp%100)/100
  return lerprgb(p,COLORRAMP[idx],COLORRAMP[idx+1])
end

local function between(v,s,e)
  if s<=e then return v>=s and v<=e
  else return v>=s or v<=e end
end
applyGamma=function(testtime)
  if tmrNext then tmrNext:stop() tmrNext=nil end
  local now=testtime and timer.seconds(testtime) or timer.localTime()
  local temp,next,invert
  if between(now,nightStart,nightEnd) then temp=ilerp(now,nightStart,nightEnd,dayTemp,nightTemp) --dusk
  elseif between(now,dayStart,dayEnd) then temp=ilerp(now,dayStart,dayEnd,nightTemp,dayTemp) --dawn
  elseif between(now,dayEnd,nightStart) then temp=dayTemp next=nightStart log.i('daytime')--day
  elseif between(now,nightEnd,dayStart) then invert=invertAtNight temp=nightTemp next=dayStart log.i('nighttime')--night
  else error('wtf') end
  if invertManual then invert=not invert end
  local gamma=getGamma(temp)
  log.vf('set color temperature %dK (gamma %d,%d,%d)%s',floor(temp),round(gamma.red*100),round(gamma.green*100),round(gamma.blue*100),
    invert and ' - inverted' or '')
  for _,scr in ipairs(screen.allScreens()) do
    --    scr:setGamma(gamma,BLACKPOINT)
    scr:setGamma(invert and BLACKPOINT or gamma,invert and gamma or BLACKPOINT)
  end
  if next then
    tmrNext=timer.doAt(next,applyGamma)
  else
    tmr:start()
  end
end

tmr=timer.delayed.new(10,applyGamma)

function redshift.toggleInvert()
  if not running then return end
  invertManual=not invertManual
  settings.set(SETTING_INVERTED,invertManual)
  tmr:start(0.1)
end

local function pause()
  log.i('paused')
  screen.restoreGamma()
  tmr:stop()
end
local function resume()
  log.i('resumed')
  tmr:start(0.1)
end

function redshift.stop()
  if not running then return end
  pause()
  if wfDisable then
    if modulewfDisable then modulewfDisable:delete() modulewfDisable=nil
    else wfDisable:unsubscribe({pause,resume}) end
    wfDisable=nil
  end
  if tmrNext then tmrNext:stop() tmrNext=nil end
  screenWatcher:stop() screenWatcher=nil
  running=nil
end

local function stime(time)
  return sformat('%02d:%02d:%02d',floor(time/3600),floor(time/60)%60,floor(time%60))
end

function redshift.start(nightTime,pnightTemp,dayTime,pdayTemp,transition,invert,wf)
  transition=timer.seconds(transition)
  if transition>14400 then error('max transition time is 4h',2) end
  nightTime,dayTime=timer.seconds(nightTime),timer.seconds(dayTime)
  if abs(nightTime-dayTime)<transition or abs(nightTime-dayTime+86400)<transition or abs(nightTime-dayTime-86400)<transition then
    error('nightTime too close to dayTime',2) end
  if pnightTemp<1000 or pnightTemp>10000 or pdayTemp<1000 or pdayTemp>10000 then error('invalid color temperature',2) end
  nightTemp,dayTemp=floor(pnightTemp),floor(pdayTemp)
  redshift.stop()

  invertAtNight=invert
  nightStart,nightEnd=(nightTime-transition/2)%86400,(nightTime+transition/2)%86400
  dayStart,dayEnd=(dayTime-transition/2)%86400,(dayTime+transition/2)%86400
  log.f('started: %dK @ %s -> %dK @ %s, %dK @ %s -> %dK @ %s',
    dayTemp,stime(nightStart),nightTemp,stime(nightEnd),nightTemp,stime(dayStart),dayTemp,stime(dayEnd))
  running=true
  tmr:setDelay(max(1,transition/200))
  screenWatcher=screen.watcher.new(function()tmr:start(5)end):start()
  invertManual=settings.get(SETTING_INVERTED)
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
    wfDisable:subscribe(windowfilter.hasWindow,pause,true):subscribe(windowfilter.hasNoWindows,resume)
  end

end

COLORRAMP={ -- from https://github.com/jonls/redshift/blob/master/src/colorramp.c
  {1.00000000,  0.18172716,  0.00000000}, -- 1000K
  {1.00000000,  0.25503671,  0.00000000}, -- 1100K
  {1.00000000,  0.30942099,  0.00000000}, -- 1200K
  {1.00000000,  0.35357379,  0.00000000}, -- ...
  {1.00000000,  0.39091524,  0.00000000},
  {1.00000000,  0.42322816,  0.00000000},
  {1.00000000,  0.45159884,  0.00000000},
  {1.00000000,  0.47675916,  0.00000000},
  {1.00000000,  0.49923747,  0.00000000},
  {1.00000000,  0.51943421,  0.00000000},
  {1.00000000,  0.54360078,  0.08679949},
  {1.00000000,  0.56618736,  0.14065513},
  {1.00000000,  0.58734976,  0.18362641},
  {1.00000000,  0.60724493,  0.22137978},
  {1.00000000,  0.62600248,  0.25591950},
  {1.00000000,  0.64373109,  0.28819679},
  {1.00000000,  0.66052319,  0.31873863},
  {1.00000000,  0.67645822,  0.34786758},
  {1.00000000,  0.69160518,  0.37579588},
  {1.00000000,  0.70602449,  0.40267128},
  {1.00000000,  0.71976951,  0.42860152},
  {1.00000000,  0.73288760,  0.45366838},
  {1.00000000,  0.74542112,  0.47793608},
  {1.00000000,  0.75740814,  0.50145662},
  {1.00000000,  0.76888303,  0.52427322},
  {1.00000000,  0.77987699,  0.54642268},
  {1.00000000,  0.79041843,  0.56793692},
  {1.00000000,  0.80053332,  0.58884417},
  {1.00000000,  0.81024551,  0.60916971},
  {1.00000000,  0.81957693,  0.62893653},
  {1.00000000,  0.82854786,  0.64816570},
  {1.00000000,  0.83717703,  0.66687674},
  {1.00000000,  0.84548188,  0.68508786},
  {1.00000000,  0.85347859,  0.70281616},
  {1.00000000,  0.86118227,  0.72007777},
  {1.00000000,  0.86860704,  0.73688797},
  {1.00000000,  0.87576611,  0.75326132},
  {1.00000000,  0.88267187,  0.76921169},
  {1.00000000,  0.88933596,  0.78475236},
  {1.00000000,  0.89576933,  0.79989606},
  {1.00000000,  0.90198230,  0.81465502},
  {1.00000000,  0.90963069,  0.82838210},
  {1.00000000,  0.91710889,  0.84190889},
  {1.00000000,  0.92441842,  0.85523742},
  {1.00000000,  0.93156127,  0.86836903},
  {1.00000000,  0.93853986,  0.88130458},
  {1.00000000,  0.94535695,  0.89404470},
  {1.00000000,  0.95201559,  0.90658983},
  {1.00000000,  0.95851906,  0.91894041},
  {1.00000000,  0.96487079,  0.93109690},
  {1.00000000,  0.97107439,  0.94305985},
  {1.00000000,  0.97713351,  0.95482993},
  {1.00000000,  0.98305189,  0.96640795},
  {1.00000000,  0.98883326,  0.97779486},
  {1.00000000,  0.99448139,  0.98899179},
  --  {1.00000000,  1.00000000,  1.00000000}, -- 6500K
  {0.99999997,  0.99999997,  0.99999997}, --6500K
  {0.98947904,  0.99348723,  1.00000000},
  {0.97940448,  0.98722715,  1.00000000},
  {0.96975025,  0.98120637,  1.00000000},
  {0.96049223,  0.97541240,  1.00000000},
  {0.95160805,  0.96983355,  1.00000000},
  {0.94303638,  0.96443333,  1.00000000},
  {0.93480451,  0.95923080,  1.00000000},
  {0.92689056,  0.95421394,  1.00000000},
  {0.91927697,  0.94937330,  1.00000000},
  {0.91194747,  0.94470005,  1.00000000},
  {0.90488690,  0.94018594,  1.00000000},
  {0.89808115,  0.93582323,  1.00000000},
  {0.89151710,  0.93160469,  1.00000000},
  {0.88518247,  0.92752354,  1.00000000},
  {0.87906581,  0.92357340,  1.00000000},
  {0.87315640,  0.91974827,  1.00000000},
  {0.86744421,  0.91604254,  1.00000000},
  {0.86191983,  0.91245088,  1.00000000},
  {0.85657444,  0.90896831,  1.00000000},
  {0.85139976,  0.90559011,  1.00000000},
  {0.84638799,  0.90231183,  1.00000000},
  {0.84153180,  0.89912926,  1.00000000},
  {0.83682430,  0.89603843,  1.00000000},
  {0.83225897,  0.89303558,  1.00000000},
  {0.82782969,  0.89011714,  1.00000000},
  {0.82353066,  0.88727974,  1.00000000},
  {0.81935641,  0.88452017,  1.00000000},
  {0.81530175,  0.88183541,  1.00000000},
  {0.81136180,  0.87922257,  1.00000000},
  {0.80753191,  0.87667891,  1.00000000},
  {0.80380769,  0.87420182,  1.00000000},
  {0.80018497,  0.87178882,  1.00000000},
  {0.79665980,  0.86943756,  1.00000000},
  {0.79322843,  0.86714579,  1.00000000},
  {0.78988728,  0.86491137,  1.00000000}, -- 10000K
  {0.78663296,  0.86273225,  1.00000000},
}
return redshift
