--- === hs.network.reachability ===
---
--- This sub-module can be used to determine the reachability of a target host. A remote host is considered reachable when a data packet, sent by an application into the network stack, can leave the local device. Reachability does not guarantee that the data packet will actually be received by the host.
---
--- It is important to remember that this module works by determining if the computer has a route for network traffic bound to a specific destination.  An active internet connection provides a default route for any network that the host is not a member of, so care must be used when testing for specific VPN or local networks to avoid false positives.  Some examples follow:
---
--- This is a simple watcher which will be invoked whenever the computer's active internet connection changes state:
--- ~~~
---     hs.network.reachability.internet():setCallback(function(self, flags)
---         if (flags & hs.network.reachability.flags.reachable) > 0 then
---             -- a default route exists, so an active internet connection is present
---         else
---             -- no default route exists, so no active internet connection is present
---         end
---    end):start()
--- ~~~
---
--- Note that when an active internet connection is up (reachable), any specific network test that does not include an address pair will be reachable, since internet reachability is defined as having a default route for all non-local networks.
---
--- A specific test for determining if an OpenVPN network is available.  This example requires knowing what the local computer's IP address on the VPN network is (OpenVPN does not set the `isDirect` flag) and has been tested with Tunnelblick.
--- ~~~
---     hs.network.reachability.forAddress("10.x.y.z"):setCallback(function(self, flags)
---         -- note that because having an internet connection at all will show the remote network
---         -- as "reachable", we instead look at whether or not our specific address is "local" instead
---         if (flags & hs.network.reachability.flags.isLocalAddress) > 0 then
---             -- VPN tunnel is up
---         else
---             -- VPN tunnel is down
---         end
---    end):start()
--- ~~~
local USERDATA_TAG  = "hs.network.reachability"
local module        = require(USERDATA_TAG.."internal")

-- private variables and methods -----------------------------------------

local _kMetaTable = {}
_kMetaTable._k = setmetatable({}, {__mode = "k"})
_kMetaTable._t = setmetatable({}, {__mode = "k"})
_kMetaTable.__index = function(obj, key)
        if _kMetaTable._k[obj] then
            if _kMetaTable._k[obj][key] then
                return _kMetaTable._k[obj][key]
            else
                for k,v in pairs(_kMetaTable._k[obj]) do
                    if v == key then return k end
                end
            end
        end
        return nil
    end
_kMetaTable.__newindex = function(obj, key, value)
        error("attempt to modify a table of constants",2)
        return nil
    end
_kMetaTable.__pairs = function(obj) return pairs(_kMetaTable._k[obj]) end
_kMetaTable.__len = function(obj) return #_kMetaTable._k[obj] end
_kMetaTable.__tostring = function(obj)
        local result = ""
        if _kMetaTable._k[obj] then
            local width = 0
            for k,v in pairs(_kMetaTable._k[obj]) do width = width < #tostring(k) and #tostring(k) or width end
            for k,v in require("hs.fnutils").sortByKeys(_kMetaTable._k[obj]) do
                if _kMetaTable._t[obj] == "table" then
                    result = result..string.format("%-"..tostring(width).."s %s\n", tostring(k),
                        ((type(v) == "table") and "{ table }" or tostring(v)))
                else
                    result = result..((type(v) == "table") and "{ table }" or tostring(v)).."\n"
                end
            end
        else
            result = "constants table missing"
        end
        return result
    end
_kMetaTable.__metatable = _kMetaTable -- go ahead and look, but don't unset this

local _makeConstantsTable
_makeConstantsTable = function(theTable)
    if type(theTable) ~= "table" then
        local dbg = debug.getinfo(2)
        local msg = dbg.short_src..":"..dbg.currentline..": attempting to make a '"..type(theTable).."' into a constant table"
        if module.log then module.log.ef(msg) else print(msg) end
        return theTable
    end
    for k,v in pairs(theTable) do
        if type(v) == "table" then
            local count = 0
            for a,b in pairs(v) do count = count + 1 end
            local results = _makeConstantsTable(v)
            if #v > 0 and #v == count then
                _kMetaTable._t[results] = "array"
            else
                _kMetaTable._t[results] = "table"
            end
            theTable[k] = results
        end
    end
    local results = setmetatable({}, _kMetaTable)
    _kMetaTable._k[results] = theTable
    local count = 0
    for a,b in pairs(theTable) do count = count + 1 end
    if #theTable > 0 and #theTable == count then
        _kMetaTable._t[results] = "array"
    else
        _kMetaTable._t[results] = "table"
    end
    return results
end

-- Public interface ------------------------------------------------------

module.flags            = _makeConstantsTable(module.flags)
module.specialAddresses = _makeConstantsTable({
    IN_LINKLOCALNETNUM = 0xA9FE0000, -- 169.254.0.0
    INADDR_ANY         = 0x00000000, -- 0.0.0.0
})

--- hs.network.reachability.internet() -> reachabilityObject
--- Constructor
--- Creates a reachability object for testing internet access
---
--- Parameters:
---  * None
---
--- Returns:
---  * a reachability object
---
--- Notes:
---  * This is equivalent to `hs.network.reachability.forAddress("0.0.0.0")`
---  * This constructor assumes that a default route for IPv4 traffic is sufficient to determine internet access.  If you are on an IPv6 only network which does not also provide IPv4 route mapping, you should probably use something along the lines of `hs.network.reachability.forAddress("::")` instead.
module.internet = function()
    return module.forAddress(module.specialAddresses.INADDR_ANY)
end


--- hs.network.reachability.linkLocal() -> reachabilityObject
--- Constructor
--- Creates a reachability object for testing IPv4 link local networking
---
--- Parameters:
---  * None
---
--- Returns:
---  * a reachability object
---
--- Notes:
---  * This is equivalent to `hs.network.reachability.forAddress("169.254.0.0")`
---  * You can use this to determine if any interface has an IPv4 link local address (i.e. zero conf or local only networking) by checking the "isDirect" flag:
---    * `hs.network.reachability.linklocal():status() & hs.network.reachability.flags.isDirect`
---  * If the internet is reachable, then this network will also be reachable by default -- use the isDirect flag to ensure that the route is local.
module.linklocal = function()
    return module.forAddress(module.specialAddresses.IN_LINKLOCALNETNUM)
end

-- Return Module Object --------------------------------------------------

return module
