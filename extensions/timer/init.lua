--- === hs.timer ===
---
--- Execute functions with various timing rules
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).

local module = require("hs.timer.internal")

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

function module.seconds(n) return n end

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
---  * See also `hs.timer.waitWhile`
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
--- Creates and starts a timer which will perform `actionFn` every `checkinterval` seconds until `predicateFn` returns true.  The timer is automatically stopped when `predicateFn` returns false.
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
---  * See also `hs.timer.doWhile`
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
---  * See also `hs.timer.waitUntil`
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
---  * See also `hs.timer.doUntil`
module.doWhile = function(predicateFn, ...)
    return module.doUntil(function() return not predicateFn() end, ...)
end

-- Return Module Object --------------------------------------------------

return module
