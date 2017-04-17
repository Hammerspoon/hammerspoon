--- === hs.delayed ===
---
--- Simple helper for delayed, cancellable callbacks

-- * Needs a native gettime(): https://developer.apple.com/library/mac/documentation/Cocoa/Reference/Foundation/Classes/NSDate_Class/index.html#//apple_ref/occ/instp/NSDate/timeIntervalSince1970
-- * Debugging can get difficult; ideally this should be fixed (either via explicit params, or better via debug.getinfo)

local gettime=require'socket'.gettime --FIXME need a native hook

local pairs,next,type,tinsert,tunpack,max,min = pairs,next,type,table.insert,table.unpack,math.max,math.min
local delayed = {} -- module
local log = require'hs.logger'.new('delayed')
delayed.setLogLevel=function(lvl)log.setLogLevel(lvl) return delayed end
local newtimer=require'hs.timer'.new

local TOLERANCE=0.05

local pending = {}
local toAdd = {}  -- avoid issues when calling .doAfter from a callback
local timer
local timetick,lasttime = 3600,0
local timerfn

timerfn=function()
  for d in pairs(toAdd) do
    pending[d] = true
  end
  toAdd = {}
  local ctime = gettime()
  --  log.vf('timerfn at %.3f',math.fmod(ctime,10))
  local dtime = ctime-lasttime
  lasttime=ctime
  local mindelta = 3600
  local pendingTotal=0
  for d in pairs(pending) do
    d.time = d.time - dtime
    if d.time<=TOLERANCE then
      pending[d] = nil
      log.vf('Running pending callback, %.2fs late',-d.time)
      d.fn(tunpack(d.args))
      return timerfn() -- rerun through the list for better precision, in case fn took a while
    else
      mindelta=min(mindelta,d.time)
      pendingTotal=pendingTotal+1
    end
  end
  if not next(pending) and not next(toAdd) then
    timer:stop()
    log.d('No more pending callbacks; stopping timer')
  else
    for d in pairs(toAdd) do
      mindelta=min(mindelta,d.time)
      pendingTotal=pendingTotal+1
    end
    log.vf('%d callbacks still pending',pendingTotal)
    local dtick = mindelta-timetick
    if dtick<-TOLERANCE or dtick>0.5 then
      log.df('Adjusting timer tick from %.2f to %.2f',timetick,mindelta)
      timer:stop()
      timetick=mindelta
      timer=newtimer(timetick,timerfn)
      lasttime = gettime()
      timer:start()
    end
  end
end

--- hs.delayed.doAfter(previous_id, delay, fn, ...) -> id
--- Function
--- Schedules a function for delayed execution
---
--- Parameters:
---  * previous_id - (optional) if provided, `hs.delayed.cancel(previous_id)` will be called before scheduling the new callback
---  * delay - callback delay in seconds
---  * fn - callback function
---  * ... - arguments to the callback function
---
--- Returns:
---  * id - a callback id that can be used to cancel this scheduled callback
---
--- Usage:
--- local coalescedCallback
--- local function callbackForIncomingDelugeOfEvents(event)
---   coalescedCallback = hs.delayed.doAfter(coalescedCallback, 1, doStuff, event)
---   -- will only process the last event, after there have been no new incoming events for 1 second
--- end

function delayed.doAfter(prev,delay,fn,...)
  local args = {...}
  if type(prev)=='number' then
    tinsert(args,1,fn)
    fn=delay
    delay=prev
  elseif type(prev)=='table' then pending[prev] = nil toAdd[prev] = nil
  end
  if type(fn)~='function' then error('fn must be a function',2) end
  if type(delay)~='number' then error('delay must be a number',2)end

  delay=max(delay,0.01)
  local d = {time = delay, fn = fn, args = args}
  local ctime=gettime()
  --  log.vf('doAfter at %.3f',math.fmod(ctime,10))
  log.vf('Adding callback with %.2f delay',delay)
  if not next(pending) and not next(toAdd) then
    log.vf('Starting timer, tick %.2f',delay)
    if timer then timer:stop() end
    lasttime=ctime
    timetick=delay
    timer=newtimer(timetick,timerfn)
    timer:start()
  elseif lasttime+timetick>ctime+delay+TOLERANCE then
    log.df('Adjusting timer tick from %.2f to %.2f',timetick,delay)
    timer:stop()
    timetick=delay
    timer=newtimer(timetick,timerfn)
    timer:start()
  end
  toAdd[d] = true
  return d
end

--- hs.delayed.cancel(id)
--- Function
--- Cancels a previously scheduled callback, if it hasn't yet fired
---
--- Parameters:
---  * id - id of the callback to cancel
---
--- Returns:
---  * None
---
--- Notes:
---  * `id` can be invalid (e.g. when the callback has already fired); if so this function will just return

function delayed.cancel(prev)
  if not prev or (not pending[prev] and not toAdd[prev]) then return end
  log.d('Cancelling callback')
  pending[prev] = nil toAdd[prev] = nil
  if not next(pending) and not next(toAdd) then
    if timer then timer:stop() timer=nil end
    log.d('No more pending callbacks; stopping timer')
  end
end

--- hs.delayed.stop()
--- Function
--- Cancels all scheduled callbacks
---
--- Parameters:
---  * None
---
--- Returns:
---  * None

function delayed.stop()
  if timer then timer:stop() end
  pending = {} toAdd = {}
  log.i('Stopped')
end

return delayed
