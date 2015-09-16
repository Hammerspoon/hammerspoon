--- === hs.host ===
---
--- Inspect information about the machine Hammerspoon is running on
---
--- Notes:
---  * The network/hostname calls can be slow, as network resolution calls can be called, which are synchronous and will block Hammerspoon until they complete.

local host = require "hs.host.internal"
local fnutils = require "hs.fnutils"

local __tostring_for_tables = function(self)
    local result = ""
    local width = 0
    for i,v in fnutils.sortByKeys(self) do
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
local cpuUsage = host.cpuUsage

host.vmStat = function(...)
    return setmetatable(vmStat(...), {__tostring = __tostring_for_tables })
end

host.cpuUsage = function(...)
    local result = cpuUsage(...)
    for i,v in pairs(result) do
        if tostring(i) ~= "n" then
            result[i] = setmetatable(v, { __tostring = __tostring_for_tables })
        end
    end
    return result
end

return host
