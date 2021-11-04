--- === hs.network ===
---
--- This module provides functions for inquiring about and monitoring changes to the network.

local USERDATA_TAG   = "hs.network"
local module         = {}
-- module.reachability  = require(USERDATA_TAG..".reachability")
-- module.host          = require(USERDATA_TAG..".host")
-- module.configuration = require(USERDATA_TAG..".configuration")
-- module.ping          = require(USERDATA_TAG..".ping")

-- auto-load submodules as needed
local submodules = {
    reachability  = USERDATA_TAG..".reachability",
    host          = USERDATA_TAG..".host",
    configuration = USERDATA_TAG..".configuration",
    ping          = USERDATA_TAG..".ping",
}
setmetatable(module, {
    __index = function(self, key)
        if submodules[key] then
            self[key] = require(submodules[key])
        end
        return rawget(self, key)
    end,
})

local inspect        = require("hs.inspect")
local fnutils        = require("hs.fnutils")

local log = require"hs.logger".new(USERDATA_TAG, require"hs.settings".get(USERDATA_TAG .. ".logLevel") or "error")
module.log = log

-- private variables and methods -----------------------------------------

-- Public interface ------------------------------------------------------

--- hs.network.interfaces() -> table
--- Function
--- Returns a list of interfaces currently active for the system.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table containing a list of the interfaces active for the system.  Logs an error and returns nil if there was a problem retrieving this information.
---
--- Notes:
---  * The names of the interfaces returned by this function correspond to the interface's BSD name, not the user defined name that shows up in the System Preferences's Network panel.
---  * This function returns *all* interfaces, even ones used by the system that are not directly manageable by the user.
module.interfaces = function()
    local store = module.configuration.open()
    if not store then
        log.d("interfaces - unable to open system dynamic store")
        return nil
    end

    local queryResult = store:contents("State:/Network/Interface")
    local answer = queryResult and
                   queryResult["State:/Network/Interface"] and
                   queryResult["State:/Network/Interface"].Interfaces
    if not answer then
        log.df("interfaces - unexpected query results for State:/Network/Interface: %s", inspect(queryResult))
        return nil
    end
    return answer
end

--- hs.network.interfaceDetails([interface | favorIPv6]) -> table
--- Function
--- Returns details about the specified interface or the primary interface if no interface is specified.
---
--- Parameters:
---  * interface - an optional string specifying the interface to retrieve details about.  Defaults to the primary interface if not specified.
---  * favorIPv6 - an optional boolean specifying whether or not to prefer the primary IPv6 or the primary IPv4 interface if `interface` is not specified.  Defaults to false.
---
--- Returns:
---  * A table containing key-value pairs describing interface details.  Returns an empty table if no primary interface can be determined. Logs an error and returns nil if there was a problem retrieving this information.
---
--- Notes:
---  * When determining the primary interface, the `favorIPv6` flag only determines interface search order.  If you specify true for this flag, but no primary IPv6 interface exists (i.e. your DHCP server only provides an IPv4 address an IPv6 is limited to local only traffic), then the primary IPv4 interface will be used instead.
module.interfaceDetails = function(interface)
    local favorIPv6
    if type(interface) == "boolean" then interface, favorIPv6 = nil, interface end

    local store = module.configuration.open()
    if not store then
        log.d("interfaceDetails - unable to open system dynamic store")
        return nil
    end
    if not interface then
        local ipv4, ipv6 = module.primaryInterfaces()
        interface = (favorIPv6 and ipv6 or ipv4) or (ipv4 or ipv6)
        if not interface then
            log.d("interfaceDetails - unable to determine a global primary IPv4 or IPv6 interface")
            return nil
        end
    end

    local prefix = "State:/Network/Interface/" .. interface .. "/"
    local queryResult = store:contents(prefix .. ".*", true)
    if not queryResult then
        log.df("interfaceDetails - unexpected query results for State:/Network/Interface/%s/.*: %s", interface, inspect(queryResult))
        return nil
    end

    local results = {}
    for k, v in pairs(queryResult) do
        local newK = k:match("^" .. prefix .. "(.*)$") or k
        results[newK] = v
    end
    return results
end

--- hs.network.primaryInterfaces() -> ipv4Interface, ipv6Interface
--- Function
--- Returns the names of the primary IPv4 and IPv6 interfaces.
---
--- Parameters:
---  * None
---
--- Returns:
---  * The name of the primary IPv4 interface or false if there isn't one, and the name of the IPv6 interface or false if there isn't one. Logs an error and returns a single nil if there was a problem retrieving this information.
---
--- Notes:
---  * The IPv4 and IPv6 interface names are often, but not always, the same.
module.primaryInterfaces = function()
    local store = module.configuration.open()
    if not store then
        log.d("primaryInterfaces - unable to open system dynamic store")
        return nil
    end

    local queryResult = store:contents("State:/Network/Global/IPv[46]", true)
    if not queryResult then
        log.df("primaryInterfaces - unexpected query results for State:/Network/Global/IPv[46]: %s", inspect(queryResult))
        return nil
    end

    return
        queryResult["State:/Network/Global/IPv4"] and queryResult["State:/Network/Global/IPv4"].PrimaryInterface or false,
        queryResult["State:/Network/Global/IPv6"] and queryResult["State:/Network/Global/IPv6"].PrimaryInterface or false
end

--- hs.network.addresses([interface_list]) -> table
--- Function
--- Returns a list of the IPv4 and IPv6 addresses for the specified interfaces, or all interfaces if no arguments are given.
---
--- Parameters:
---  * interface_list - The interface names to return the IP addresses for. It should be specified as one of the following:
---    * one or more interface names, separated by a comma
---    * if the first argument is a table, it is assumes to be a table containing a list of interfaces and this list is used instead, ignoring any additional arguments that may be provided
---    * if no arguments are specified, then the results of [hs.network.interfaces](#interfaces) is used.
---
--- Returns:
---  * A table containing a list of the IP addresses for the interfaces as determined by the arguments provided.
---
--- Notes:
---  * The order of the IP addresses returned is undefined.
---  * If no arguments are provided, then this function returns the same results as `hs.host.addresses`, but does not block.
module.addresses = function(...)
    local interfaces = table.pack(...)
    if interfaces.n == 0 then interfaces = module.interfaces() end
    if type(interfaces[1]) == "table" then interfaces = interfaces[1] end

    local store = module.configuration.open()
    if not store then
        log.d("addresses - unable to open system dynamic store")
        return nil
    end
    local queryResult = store:contents("State:/Network/Interface/.*/IPv[46]", true)
    if not queryResult then
        log.df("addresses - unexpected query results for State:/Network/Interface/.*/IPv[46]: %s", inspect(queryResult))
        return nil
    end

    local results = {}
    for k, v in pairs(queryResult) do
        local intf, prot = k:match("^State:/Network/Interface/([^/]+)/(IPv[46])$")
        if fnutils.contains(interfaces, intf) then
            local suffix = (prot == "IPv6") and ("%" .. intf) or ""
            for _, v2 in ipairs(v.Addresses) do
                table.insert(results, v2 .. suffix)
            end
        end
    end
    return results
end

--- hs.network.interfaceName([interface | favorIPv6]) -> string
--- Function
--- Returns the user defined name for the specified interface or the primary interface if no interface is specified.
---
--- Parameters:
---  * interface - an optional string specifying the interface to retrieve the name for.  Defaults to the primary interface if not specified.
---  * favorIPv6 - an optional boolean specifying whether or not to prefer the primary IPv6 or the primary IPv4 interface if `interface` is not specified.  Defaults to false.
---
--- Returns:
---  * A string containing the user defined name for the interface, if one exists, or false if the interface does not have a user defined name. Logs an error and returns nil if there was a problem retrieving this information.
---
--- Notes:
---  * Only interfaces which show up in the System Preferences Network panel will have a user defined name.
---
---  * When determining the primary interface, the `favorIPv6` flag only determines interface search order.  If you specify true for this flag, but no primary IPv6 interface exists (i.e. your DHCP server only provides an IPv4 address an IPv6 is limited to local only traffic), then the primary IPv4 interface will be used instead.
module.interfaceName = function(interface, favorIPv6)
    if type(interface) == "boolean" then interface, favorIPv6 = nil, interface end

    local store = module.configuration.open()
    if not store then
        log.d("interfaceName - unable to open system dynamic store")
        return nil
    end
    if not interface then
        local ipv4, ipv6 = module.primaryInterfaces()
        interface = (favorIPv6 and ipv6 or ipv4) or (ipv4 or ipv6)
        if not interface then
            log.d("interfaceName - unable to determine a global primary IPv4 or IPv6 interface")
            return nil
        end
    end

    local queryResult = store:contents("Setup:/Network/Service/.*/Interface", true)
    if not queryResult then
        log.df("interfaceName - unexpected query results for Setup:/Network/Service/.*/Interface: %s", inspect(queryResult))
        return nil
    end

    for _, v in pairs(queryResult) do
        if v.DeviceName == interface then return v.UserDefinedName end
    end
    return false
end

-- Return Module Object --------------------------------------------------

return module
