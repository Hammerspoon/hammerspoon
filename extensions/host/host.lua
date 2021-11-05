--- === hs.host ===
---
--- Inspect information about the machine Hammerspoon is running on
---
--- Notes:
---  * The network/hostname calls can be slow, as network resolution calls can be called, which are synchronous and will block Hammerspoon until they complete.

local host = require "hs.libhost"
local fnutils = require "hs.fnutils"
local timer   = require "hs.timer"

host.locale = require "hs.host_locale"

local __tostring_for_tables = function(self)
    local result = ""
    local width = 0
    for i,_ in fnutils.sortByKeys(self) do
        if type(i) == "string" and width < i:len() then width = i:len() end
    end
    for i,v in fnutils.sortByKeys(self) do
        if type(i) == "string" then
            result = result..string.format("%-"..tostring(width).."s %s\n", i, tostring(v))
        end
    end
    return result
end

local vmStat = host.vmStat

host.vmStat = function(...)
    return setmetatable(vmStat(...), {__tostring = __tostring_for_tables })
end

--- hs.host.cpuUsage([period], [callback]) -> table
--- Function
--- Query CPU usage statistics for a given time interval using [hs.host.cpuUsageTicks](#cpuUsageTicks) and return the results as percentages.
---
--- Parameters:
---  * `period`    - an optional value specifying the time between samples collected for calculating CPU usage statistics.
---    * If `callback` is not provided, this is an optional integer, default 100000, specifying the number of microseconds to block between samples collected.  Note that Hammerspoon will block for this period of time during execution of this function.
---    * If `callback` is provided, this is an optional number, default 1.0, specifying the number of seconds between samples collected.  Hammerspoon will *not* block during this time period.
---  * `callback` - an optional callback function which will receive the cpu usage statistics in a table, described below, as its sole argument.
---
--- Returns:
---  * If a callback function is not provided, this function will return a table containing the following:
---    * Individual tables, indexed by the core number, for each CPU core with the following keys in each subtable:
---      * user   -- percentage of CPU time occupied by user level processes.
---      * system -- percentage of CPU time occupied by system (kernel) level processes.
---      * nice   -- percentage of CPU time occupied by user level processes with a positive nice value. (See notes below)
---      * active -- For convenience, when you just want the total CPU usage, this is the sum of user, system, and nice.
---      * idle   -- percentage of CPU time spent idle
---    * The key `overall` containing the same keys as described above but based upon the average of all cores combined.
---    * The key `n` containing the number of cores detected.
---  * If a callback function is provided, this function will return a placeholder table with the following metamethods:
---    * `hs.host.cpuUsage:finished()` - returns a boolean indicating if the second CPU sample has been collected yet (true) or not (false).
---    * `hs.host.cpuUsage:stop()`     - abort the sample collection.  The callback function will not be invoked.
---    * The results of the cpu statistics will be submitted as a table, described above, to the callback function.
---
--- Notes:
---  * If no callback function is provided, Hammerspoon will block (i.e. no other Hammerspoon activity can occur) during execution of this function for `period` microseconds (1 second = 1,000,000 microseconds).  The default period is 1/10 of a second. If `period` is too small, it is possible that some of the CPU statistics may result in `nan` (not-a-number).
---
---  * For reference, the `top` command has a default period between samples of 1 second.
---
---  * The subtables for each core and `overall` have a __tostring() metamethod which allows listing it's contents in the Hammerspoon console by typing `hs.host.cpuUsage()[#]` where # is the core you are interested in or the string "overall".
local convertToPercentages = function(result1, result2)
    local result = {}
    for k,v in pairs(result2) do
        if k == "n" then
            result.n = v
        else
            result[k] = {}
            for k2, v2 in pairs(v) do
                result[k][k2] = v2 - result1[k][k2]
            end
            local total = result[k].active + result[k].idle
            for k2, _ in pairs(result[k]) do
                result[k][k2] = (result[k][k2] / total) * 100.0
            end
        end
    end
    for i,v in pairs(result) do
        if tostring(i) ~= "n" then
            result[i] = setmetatable(v, { __tostring = __tostring_for_tables })
        end
    end
    return result
end

host.cpuUsage = function(period, callback)
    if type(period) == "function" and type(callback) == "number" then
        period, callback = callback, period
    end
    if type(period) == "function" and type(callback) == "nil" then
        period, callback = 1, period
    end

    period = period or (callback and 1 or 100000)
    local result1 = host.cpuUsageTicks()
    if callback then
        local callbackPlaceHolder = {}
        callbackPlaceHolder.callbackTimer = timer.doAfter(period, function()
            local result2 = host.cpuUsageTicks()
            local result = convertToPercentages(result1, result2)
            callbackPlaceHolder.callbackTimer = nil
            callback(result)
        end)
        return setmetatable(callbackPlaceHolder, {
            __index = {
                finished = function(self) return self.callbackTimer == nil end,
                stop     = function(self)
                    self.callbackTimer:stop()
                    self.callbackTimer = false -- this way finished() == true only if it actually fired
                end,
            },
        })
    else
        timer.usleep(period)
        local result2 = host.cpuUsageTicks()
        local result = convertToPercentages(result1, result2)
        return result
    end
end

return host
