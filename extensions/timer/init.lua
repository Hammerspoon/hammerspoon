--- === hs.timer ===
---
--- Execute functions with various timing rules
---
--- **NOTE**: timers use NSTimer internally, which will be paused when computers sleep.
--- Especially, repeating timers won't be triggered at the specificed time when there are sleeps in between.
--- The workaround is to prevent system from sleeping, configured in Energy Saver in System Preferences.

local module = require("hs.timer.internal")
local log=require'hs.logger'.new('timer',3)
module.setLogLevel=log.setLogLevel
local type,ipairs,tonumber,floor,date=type,ipairs,tonumber,math.floor,os.date

-- private variables and methods -----------------------------------------

local TIME_PATTERNS={'-??:??:??-','-??:??--','??d??h---','-??h??m--','--??m??s-','??d----','-??h---','--??m--','---??s-','----????ms'}
-- ms unused, but it might be useful in the future
do
  for i,s in ipairs(TIME_PATTERNS) do
    TIME_PATTERNS[i]='^'..(s:gsub('%?%?%?%?','(%%d%%d?%%d?%%d?)'):gsub('%?%?','(%%d%%d?)'):gsub('%-','()'))..'$'
  end
end
local function timeStringToSeconds(time)
  if type(time)=='string' then
    local d,h,m,s,ms
    for _,pattern in ipairs(TIME_PATTERNS) do
      d,h,m,s,ms=time:match(pattern) if d then break end
    end
    if not d then error('invalid time string '..time,3) end
    if type(d)=='number' then d=0 end --remove "missing" captures
    if type(h)=='number' then h=0 end
    if type(m)=='number' then m=0 end
    if type(s)=='number' then s=0 end
    if type(ms)=='number' then ms=0 end
    d=tonumber(d) h=tonumber(h) m=tonumber(m) s=tonumber(s) ms=tonumber(ms)
    if h>=24 or m>=60 or s>=60 then error('invalid time string '..time,3) end
    time=d*86400+h*3600+m*60+s+(ms/1000)
  end
  if type(time)~='number' or time<0 then error('invalid time',3) end
  return time
end

-- Public interface ------------------------------------------------------

--- hs.timer.seconds(timeOrDuration) -> seconds
--- Function
--- Converts a string with a time of day or a duration into number of seconds
---
--- Parameters:
---  * timeOrDuration - a string that can have any of the following formats:
---    * "HH:MM:SS" or "HH:MM" - represents a time of day (24-hour clock), returns the number of seconds since midnight
---    * "DDdHHh", "HHhMMm", "MMmSSs", "DDd", "HHh", "MMm", "SSs", "NNNNms" - represents a duration in days, hours, minutes,
---      seconds and/or milliseconds
---
--- Returns:
---  * The number of seconds
function module.seconds(n) return timeStringToSeconds(n) end

--- hs.timer.minutes(n) -> seconds
--- Function
--- Converts minutes to seconds
---
--- Parameters:
---  * n - A number of minutes
---
--- Returns:
---  * The number of seconds in n minutes
function module.minutes(n) return 60 * n end

--- hs.timer.hours(n) -> seconds
--- Function
--- Converts hours to seconds
---
--- Parameters:
---  * n - A number of hours
---
--- Returns:
---  * The number of seconds in n hours
function module.hours(n)   return 60 * 60 * n end

--- hs.timer.days(n) -> sec
--- Function
--- Converts days to seconds
---
--- Parameters:
---  * n - A number of days
---
--- Returns:
---  * The number of seconds in n days
function module.days(n)    return 60 * 60 * 24 * n end

--- hs.timer.weeks(n) -> sec
--- Function
--- Converts weeks to seconds
---
--- Parameters:
---  * n - A number of weeks
---
--- Returns:
---  * The number of seconds in n weeks
function module.weeks(n)   return 60 * 60 * 24 * 7 * n end

--- hs.timer.waitUntil(predicateFn, actionFn[, checkInterval]) -> timer
--- Constructor
--- Creates and starts a timer which will perform `actionFn` when `predicateFn` returns true.  The timer is automatically stopped when `actionFn` is called.
---
--- Parameters:
---  * predicateFn - a function which determines when `actionFn` should be called.  This function takes no arguments, but should return true when it is time to call `actionFn`.
---  * actionFn - a function which performs the desired action.  This function may take a single argument, the timer itself.
---  * checkInterval - an optional parameter indicating how often to repeat the `predicateFn` check. Defaults to 1 second.
---
--- Returns:
---  * a timer object
---
--- Notes:
---  * The timer is stopped before `actionFn` is called, but the timer is passed as an argument to `actionFn` so that the actionFn may restart the timer to be called again the next time predicateFn returns true.
---  * See also `hs.timer.waitWhile`, which is essentially the opposite of this function
module.waitUntil = function(predicateFn, actionFn, checkInterval)
  checkInterval = checkInterval or 1

  local stopWatch
  stopWatch = module.new(checkInterval, function()
    if predicateFn() then
      stopWatch:stop()
      actionFn(stopWatch)
    end
  end):start()
  return stopWatch
end

--- hs.timer.doUntil(predicateFn, actionFn[, checkInterval]) -> timer
--- Constructor
--- Creates and starts a timer which will perform `actionFn` every `checkinterval` seconds until `predicateFn` returns true.  The timer is automatically stopped when `predicateFn` returns true.
---
--- Parameters:
---  * predicateFn - a function which determines when to stop calling `actionFn`.  This function takes no arguments, but should return true when it is time to stop calling `actionFn`.
---  * actionFn - a function which performs the desired action.  This function may take a single argument, the timer itself.
---  * checkInterval - an optional parameter indicating how often to repeat the `predicateFn` check. Defaults to 1 second.
---
--- Returns:
---  * a timer object
---
--- Notes:
---  * The timer is passed as an argument to `actionFn` so that it may stop the timer prematurely (i.e. before predicateFn returns true) if desired.
---  * See also `hs.timer.doWhile`, which is essentially the opposite of this function
module.doUntil = function(predicateFn, actionFn, checkInterval)
  checkInterval = checkInterval or 1
  local stopWatch
  stopWatch = module.new(checkInterval, function()
    if not predicateFn() then
      actionFn(stopWatch)
    else
      stopWatch:stop()
    end
  end):start()
  return stopWatch
end

--- hs.timer.doEvery(interval, fn) -> timer
--- Constructor
--- Repeats fn every interval seconds.
---
--- Parameters:
---  * interval - A number of seconds between triggers
---  * fn - A function to call every time the timer triggers
---
--- Returns:
---  * An `hs.timer` object
---
--- Notes:
---  * This function is a shorthand for `hs.timer.new(interval, fn):start()`
module.doEvery = function(...)
  return module.new(...):start()
end

--- hs.timer.waitWhile(predicateFn, actionFn[, checkInterval]) -> timer
--- Constructor
--- Creates and starts a timer which will perform `actionFn` when `predicateFn` returns false.  The timer is automatically stopped when `actionFn` is called.
---
--- Parameters:
---  * predicateFn - a function which determines when `actionFn` should be called.  This function takes no arguments, but should return false when it is time to call `actionFn`.
---  * actionFn - a function which performs the desired action.  This function may take a single argument, the timer itself.
---  * checkInterval - an optional parameter indicating how often to repeat the `predicateFn` check. Defaults to 1 second.
---
--- Returns:
---  * a timer object
---
--- Notes:
---  * The timer is stopped before `actionFn` is called, but the timer is passed as an argument to `actionFn` so that the actionFn may restart the timer to be called again the next time predicateFn returns false.
---  * See also `hs.timer.waitUntil`, which is essentially the opposite of this function
module.waitWhile = function(predicateFn, ...)
  return module.waitUntil(function() return not predicateFn() end, ...)
end

--- hs.timer.doWhile(predicateFn, actionFn[, checkInterval]) -> timer
--- Constructor
--- Creates and starts a timer which will perform `actionFn` every `checkinterval` seconds while `predicateFn` returns true.  The timer is automatically stopped when `predicateFn` returns false.
---
--- Parameters:
---  * predicateFn - a function which determines when to stop calling `actionFn`.  This function takes no arguments, but should return false when it is time to stop calling `actionFn`.
---  * actionFn - a function which performs the desired action.  This function may take a single argument, the timer itself.
---  * checkInterval - an optional parameter indicating how often to repeat the `predicateFn` check. Defaults to 1 second.
---
--- Returns:
---  * a timer object
---
--- Notes:
---  * The timer is passed as an argument to `actionFn` so that it may stop the timer prematurely (i.e. before predicateFn returns false) if desired.
---  * See also `hs.timer.doUntil`, which is essentially the opposite of this function
module.doWhile = function(predicateFn, ...)
  return module.doUntil(function() return not predicateFn() end, ...)
end


--- hs.timer.localTime() -> number
--- Function
--- Returns the number of seconds since local time midnight
---
--- Parameters:
---  * None
---
--- Returns:
---  * the number of seconds
module.localTime = function()
  local tnow=date('*t')
  return tnow.sec+tnow.min*60+tnow.hour*3600
end

--- hs.timer.doAt(time[, repeatInterval], fn[, continueOnError]) -> timer
--- Constructor
--- Creates and starts a timer which will perform `fn` at the given (local) `time` and then (optionally) repeat it every `interval`.
---
--- Parameters:
---  * time - number of seconds after (local) midnight, or a string in the format "HH:MM" (24-hour local time), indicating
---    the desired trigger time
---  * repeatInterval - (optional) number of seconds between triggers, or a string in the format
---    "DDd", "DDdHHh", "HHhMMm", "HHh" or "MMm" indicating days, hours and/or minutes between triggers; if omitted
---    or `0` the timer will trigger only once
---  * fn - a function to call every time the timer triggers
---  * continueOnError - an optional boolean flag, defaulting to false, which indicates that the timer should not be automatically stopped if the callback function results in an error.
---
--- Returns:
---  * a timer object
---
--- Notes:
---  * The timer can trigger up to 1 second early or late
---  * The first trigger will be set to the earliest occurrence given the `repeatInterval`; if that's omitted,
---    and `time` is earlier than the current time, the timer will trigger the next day. If the repeated interval
---    results in exactly 24 hours you can schedule regular jobs that will run at the expected time independently
---    of when Hammerspoon was restarted/reloaded. E.g.:
---    * If it's 19:00, `hs.timer.doAt("20:00",somefn)` will set the timer 1 hour from now
---    * If it's 21:00, `hs.timer.doAt("20:00",somefn)` will set the timer 23 hours from now
---    * If it's 21:00, `hs.timer.doAt("20:00","6h",somefn)` will set the timer 5 hours from now (at 02:00)
---    * To run a job every hour on the hour from 8:00 to 20:00: `for h=8,20 do hs.timer.doAt(h..":00","1d",runJob) end`
module.doAt = function(time,interval,fn,continueOnError)
  if type(interval)=='function' then continueOnError=fn fn=interval interval=0 end
  interval=timeStringToSeconds(interval)
  if interval~=0 and interval<60 then error('invalid interval',2) end -- degenerate use case for this function
  time=timeStringToSeconds(time)
  local now=module.localTime()
  while time<=now do
    time=time+(interval==0 and module.days(1) or interval)
  end
  local delta=time-now
  time=time%86400 -- for logging
  log.df('timer set for %02d:%02d:%02d, %dh%dm%ds from now',
    floor(time/3600),floor(time/60)%60,floor(time%60),floor(delta/3600),floor(delta/60)%60,floor(delta%60))
  return module.new(interval,fn,continueOnError):start():setNextTrigger(delta)
end

--- === hs.timer.delayed ===
---
--- Specialized timer objects to coalesce processing of unpredictable asynchronous events into a single callback

--- hs.timer.delayed:start([delay]) -> hs.timer.delayed object
--- Method
--- Starts or restarts the callback countdown
---
--- Parameters:
---  * delay - (optional) if provided, sets the countdown duration to this number of seconds for this time only; subsequent calls to `:start()` will revert to the original delay (or to the delay set with `:setDelay(delay)`)
---
--- Returns:
---  * the delayed timer object

--- hs.timer.delayed:stop() -> hs.timer.delayed object
--- Method
--- Cancels the callback countdown, if running; the callback will therefore not be triggered
---
--- Parameters:
---  * None
---
--- Returns:
---  * the delayed timer object

--- hs.timer.delayed:running() -> boolean
--- Method
--- Returns a boolean indicating whether the callback countdown is running
---
--- Parameters:
---  * None
---
--- Returns:
---  * a boolean

--- hs.timer.delayed:setDelay(delay) -> hs.timer.delayed object
--- Method
--- Changes the callback countdown duration
---
--- Parameters:
---  * None
---
--- Returns:
---  * the delayed timer object
---
--- Notes:
---  * if the callback countdown is running, calling this method will restart it

--- hs.timer.delayed:nextTrigger() -> number or nil
--- Method
--- Returns the time left in the callback countdown
---
--- Parameters:
---  * None
---
--- Returns:
---  * if the callback countdown is running, returns the number of seconds until it triggers; otherwise returns nil

--- hs.timer.delayed.new(delay, fn) -> hs.timer.delayed object
--- Constructor
--- Creates a new delayed timer.
---
--- Delayed timers have specialized methods that behave differently from regular timers.
--- When the `:start()` method is invoked, the timer will wait for `delay` seconds before calling `fn()`;
--- this is referred to as the callback countdown. If `:start()` is invoked again before `delay` has elapsed,
--- the countdown starts over again.
---
--- You can use a delayed timer to coalesce processing of unpredictable asynchronous events into a single
--- callback; for example, if you have an event stream that happens in "bursts" of dozens of events at once,
--- set an appropriate `delay` to wait for things to settle down, and then your callback will run just once.
---
--- Parameters:
---  * delay - number of seconds to wait for after a `:start()` invocation (the "callback countdown")
---  * fn - a function to call after `delay` has fully elapsed without any further `:start()` invocations
---
--- Returns:
---  * a new `hs.timer.delayed` object
---
--- Notes:
---  * these timers are meant to be long-lived: once instantiated, there's no way to remove them from the run loop; create them once at the module level.

local DISTANT_FUTURE=315360000 -- 10 years (roughly)
module.delayed = {
  new=function(delay,fn)
    local tmr=module.new(DISTANT_FUTURE,fn):start()
    return {
      start=function(self,dl) tmr:setNextTrigger(dl or delay) return self end,
      stop=function(self) tmr:setNextTrigger(DISTANT_FUTURE) return self end,
      nextTrigger=function() local nt=tmr:nextTrigger() return (nt>0 and nt<=delay) and nt or nil end,
      running=function(self) return self:nextTrigger() and true or false end,
      setDelay=function(self,dl) if self:running() then delay=dl self:start() end delay=dl return self end,
    }
  end
}
-- Return Module Object --------------------------------------------------

return module
