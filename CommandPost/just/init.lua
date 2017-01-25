--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--                          J U S T     L I B R A R Y                         --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- Module created by David Peterson (https://github.com/randomeizer).
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
-- This module provides functions to help with performing tasks which may be
-- delayed, up to a finite number of loops.
--
--------------------------------------------------------------------------------
-- THE MODULE:
--------------------------------------------------------------------------------

local just = {}

local timer 					= require("hs.timer")

--- hs.just.doWhile(actionFn, period, loops) -> UI
--- Function
--- Performs an 'action' function, looping while the result of the function evaluates to 'true'.
--- It will halt after 'loops' repetitions if the result is never 'false'.
---
--- Parameters:
---  * actionFn	- a fuction which is called on each loop. It should return a 'truthy' value.
---  * `timeout`	- (optional) the number of seconds after which we will give up. Defaults to 1 second.
---  * `frequency`	- (optional) the number of loops to perform before giving up. Defaults to 1 millisecond.
---
--- Returns:
---  * The last return value of the action function.
---
function just.doWhile(actionFn, timeout, frequency)
	timeout = timeout or 1.0
	frequency = frequency or 0.001

	local period = frequency * 1000000
	local stopTime = timer.secondsSinceEpoch() + timeout

	local result = true
	while result and timer.secondsSinceEpoch() < stopTime do
		result = actionFn()
		timer.usleep(period)
	end
	return result
end

--- hs.just.doUntil(actionFn, period, loops) -> result
--- Function
--- Performs an `action` function, looping until the result of the function evaluates to `true` (or a non-nil value).
--- It will halt after the `timeout` (default)
---
--- Parameters:
---  * `actionFn`	- a fuction which is called on each loop. It should return a 'truthy' value.
---  * `timeout`	- (optional) the number of seconds after which we will give up. Defaults to 1 second.
---  * `frequency`	- (optional) the number of loops to perform before giving up. Defaults to 1 millisecond.
---
--- Returns:
---  * The last return value of the action function.
---
function just.doUntil(actionFn, timeout, frequency)
	timeout = timeout or 1.0
	frequency = frequency or 0.001

	local period = frequency * 1000000
	local stopTime = timer.secondsSinceEpoch() + timeout

	local result = false
	while not result and timer.secondsSinceEpoch() < stopTime do
		result = actionFn()
		timer.usleep(period)
	end
	return result
end

--- hs.just.wait(integer) -> nil
--- Function
--- Pauses the application for the specified number of seconds.
---
--- Parameters:
---  * periodInSeconds - the number of seconds to pause for.
---
--- Returns:
---  * N/A
---
function just.wait(periodInSeconds)
	timer.usleep(periodInSeconds * 1000000)
end

return just