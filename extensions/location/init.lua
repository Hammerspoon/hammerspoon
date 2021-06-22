
--- === hs.location ===
---
--- Determine the machine's location and useful information about that location
---
--- This module provides functions for getting current location information and tracking location changes. It expands on the earlier version of the module by adding the ability to create independant locationObjects which can enable/disable location tracking independant of other uses of Location Services by Hammerspoon, adds region monitoring for exit and entry, and adds the retrieval of geocoding information through the `hs.location.geocoder` submodule.
---
--- This module is backwards compatible with its predecessor with the following changes:
---  * [hs.location.get](#get) - no longer requires that you invoke [hs.location.start](#start) before using this function. The information returned will be the last cached value, which is updated internally whenever additional WiFi networks are detected or lost (not necessarily joined). When update tracking is enabled with the [hs.location.start](#start) function, calculations based upon the RSSI of all currently seen networks are preformed more often to provide a more precise fix, but it's still based on the WiFi networks near you. In many cases, the value retrieved when the WiFi state is changed should be sufficiently accurate.
---  * [hs.location.servicesEnabled](#servicesEnabled) - replaces `hs.location.services_enabled`. While the earlier function is included for backwards compatibility, it will display a deprecation warning to the console the first time it is invoked and may go away completely in the future.
---
--- The following labels are used to describe tables which are used by functions and methods as parameters or return values in this module and in `hs.location.geocoder`. These tables are described as follows:
---
---  * `locationTable` - a table specifying location coordinates containing one or more of the following key-value pairs:
---    * `latitude`           - a number specifying the latitude in degrees. Positive values indicate latitudes north of the equator. Negative values indicate latitudes south of the equator. When not specified in a table being used as an argument, this defaults to 0.0.
---    * `longitude`          - a number specifying the longitude in degrees. Measurements are relative to the zero meridian, with positive values extending east of the meridian and negative values extending west of the meridian. When not specified in a table being used as an argument, this defaults to 0.0.
---    * `altitude`           - a number indicating altitude above (positive) or below (negative) sea-level. When not specified in a table being used as an argument, this defaults to 0.0.
---    * `horizontalAccuracy` - a number specifying the radius of uncertainty for the location, measured in meters. If negative, the `latitude` and `longitude` keys are invalid and should not be trusted. When not specified in a table being used as an argument, this defaults to 0.0.
---    * `verticalAccuracy`   - a number specifying the accuracy of the altitude value in meters. If negative, the `altitude` key is invalid and should not be trusted. When not specified in a table being used as an argument, this defaults to -1.0.
---    * `course`             - a number specifying the direction in which the device is traveling. If this value is negative, then the value is invalid and should not be trusted. On current Macintosh models, this will almost always be a negative number. When not specified in a table being used as an argument, this defaults to -1.0.
---    * `speed`              - a number specifying the instantaneous speed of the device in meters per second. If this value is negative, then the value is invalid and should not be trusted. On current Macintosh models, this will almost always be a negative number. When not specified in a table being used as an argument, this defaults to -1.0.
---    * `timestamp`          - a number specifying the time at which this location was determined. This number is the number of seconds since January 1, 1970 at midnight, GMT, and is a floating point number, so you should use `math.floor` on this number before using it as an argument to Lua's `os.date` function. When not specified in a table being used as an argument, this defaults to the current time.
---
---  * `regionTable` - a table specifying a circular region containing one or more of the following key-value pairs:
---    * `identifier`    - a string for use in identifying the region. When not specified in a table being used as an argument, a new value is generated with `hs.host.uuid`.
---    * `latitude`      - a number specifying the latitude in degrees. Positive values indicate latitudes north of the equator. Negative values indicate latitudes south of the equator. When not specified in a table being used as an argument, this defaults to 0.0.
---    * `longitude`     - a number specifying the latitude in degrees. Positive values indicate latitudes north of the equator. Negative values indicate latitudes south of the equator. When not specified in a table being used as an argument, this defaults to 0.0.
---    * `radius`        - a number specifying the radius (measured in meters) that defines the region’s outer boundary. When not specified in a table being used as an argument, this defaults to 0.0.
---    * `notifyOnEntry` - a boolean specifying whether or not a callback with the "didEnterRegion" message should be generated when the machine enters the region. When not specified in a table being used as an argument, this defaults to true.
---    * `notifyOnExit`  - a boolean specifying whether or not a callback with the "didExitRegion" message should be generated when the machine exits the region. When not specified in a table being used as an argument, this defaults to true.

local USERDATA_TAG   = "hs.location"
--local GEOCODE_UD_TAG = USERDATA_TAG .. ".geocode"

local module       = require(USERDATA_TAG..".internal")
local host         = require("hs.host")

local objectMT = {
    __name = USERDATA_TAG,
    __type = USERDATA_TAG,
}
local objectInternals = setmetatable({}, { __mode = "kv" })

-- private variables and methods -----------------------------------------

-- we only really need to start once, but we need to track who has started us
local startedFor = {}
local locationStart = module.start
local locationStop  = module.stop

-- Set up callback dispatcher
local legacyCallbacks = {}

local __dispatch = function(msg, ...)
--     print("in callback for " .. msg)
    if msg == "didUpdateLocations" then
        for id, _ in pairs(startedFor) do
            if id == "legacy" then
            -- handle legacy callbacks
                local locationNow = module.get()
                for _, callback in pairs(legacyCallbacks) do
                    if not(callback.distance and module.distance(locationNow, callback.last) < callback.distance) then
                        callback.last = {
                            latitude = locationNow.latitude,
                            longitude = locationNow.longitude,
                            timestamp = locationNow.timestamp
                        }
                        callback.fn(locationNow)
                    end
                end
            else
                local _self = objectInternals[id]
                if _self and _self._callbk then
                    _self._callbk(_self, msg, ...)
                end
            end
        end
    else
        -- handle object callbacks for other messages
        for k, v in pairs(objectInternals) do
            if type(k) == "string" then
                local id, _self = k, v

                if _self._callbk then
                    if msg:match("Region$") then
                        local args = table.pack(...)
                        local originalID = args[1].identifier
                        local regionID = originalID:match("^([%w-]+)%%%%")
--     print("region id passed:" .. originalID .. " --> " .. regionID .. " wanted:" .. id)
                        if regionID == id then
                            -- CLLocationManagerDelegate methods returns a copy of the region data being
                            -- monitored and this copy does not reliably contain the proper values for the
                            -- notifyOnEntry and notifyOnExit keys... it must elsewhere, because the proper
                            -- notifications *do* occur, but what we get back has random values for these
                            -- fields, so we copy them at creation time and "reset" them here
                            args[1].notifyOnEntry = _self.regions[originalID].notifyOnEntry
                            args[1].notifyOnExit  = _self.regions[originalID].notifyOnExit
                            -- return the objects name for the region, not the internal one
                            args[1].identifier = _self.regions[originalID].identifier
                            _self._callbk(_self, msg, table.unpack(args))
                        end
                    else
                        _self._callbk(_self, msg, ...)
                    end
                end
            end
        end
    end
end
local registerCallback = module._registerCallback
module._registerCallback = nil -- not needed again until/unless Hammerspoon restarted
registerCallback(__dispatch)

-- note, will choke on recursion and ignores metatables
local simpleCopy
simpleCopy = function(t1)
    if type(t1) == "table" then
        local t2 = {}
        for k, v in pairs(t1) do t2[k] = simpleCopy(v) end
        return t2
    else
        return t1
    end
end

-- Public interface ------------------------------------------------------

-- legacy functions

local hasSeenDeprecationWarning = false
module.services_enabled = function(...)
    if not hasSeenDeprecationWarning then
        print("** hs.location.services_enabled is deprecated; use hs.location.servicesEnabled instead")
        hasSeenDeprecationWarning = true
    end
    return module.servicesEnabled(...)
end

--- hs.location.register(tag, fn[, distance])
--- Function
--- Registers a callback function to be called when the system location is updated
---
--- Parameters:
---  * `tag`      - A string containing a unique tag, used to identify the callback later
---  * `fn`       - A function to be called when the system location is updated. The function should expect a single argument which will be a locationTable as described in the module header.
---  * `distance` - An optional number containing the minimum distance in meters that the system should have moved, before calling the callback. Defaults to 0
---
--- Returns:
---  * None
module.register = function(tag, fn, distance)
    if legacyCallbacks[tag] then
        error("Callback tag '"..tag.."' already registered for hs.location.", 2)
    else
        legacyCallbacks[tag] = {
            fn = fn,
            distance = distance,
            last = {
                latitude = 0,
                longitude = 0,
                timestamp = 0,
            }
        }
    end
end

--- hs.location.unregister(tag)
--- Function
--- Unregisters a callback
---
--- Parameters:
---  * `tag` - A string containing the unique tag a callback was registered with
---
--- Returns:
---  * None
module.unregister = function(tag)
    legacyCallbacks[tag] = nil
end

--- hs.location.start() -> boolean
--- Function
--- Begins location tracking using OS X's Location Services so that registered callback functions can be invoked as the computer location changes.
---
--- Parameters:
---  * None
---
--- Returns:
---  * True if the operation succeeded, otherwise false
---
--- Notes:
---  * This function activates Location Services for Hammerspoon, so the first time you call this, you may be prompted to authorise Hammerspoon to use Location Services.
module.start = function()
    local result = true
    -- if startedFor is empty, then start
    if not next(startedFor) then result = locationStart() end
    -- if result is true (it will only be false if we tried to start and failed), update for legacy
    if result then startedFor.legacy = true end
    -- force a nil to be false to match documented behavior
    return startedFor.legacy or false
end

--- hs.location.stop()
--- Function
--- Stops location tracking.  Registered callback functions will cease to receive notification of location changes.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
module.stop = function()
    -- if startedFor is not empty, then clear for legacy
    if next(startedFor) then
        startedFor.legacy = nil
        -- now, if startedFor *is* empty, then actually stop
        if not next(startedFor) then locationStop() end
    end
end

-- hs.location independant objects

--- hs.location.new() -> locationObject
--- Constructor
--- Create a new location object which can receive callbacks independant of other Hammerspoon use of Location Services.
---
--- Parameters:
---  * None
---
--- Returns:
---  * a locationObject
---
--- Notes:
---  * The locationObject created will receive callbacks independant of all other locationObjects and the legacy callback functions created with [hs.location.register](#register).  It can also receive callbacks for region changes which are not available through the legacy callback mechanism.
module.new = function()
    local self = { id = host.uuid(), regions = {} }
    self.label = tostring(self):match("^table: (.+)$")
    objectInternals[self] = self.id
    objectInternals[self.id] = self
    return setmetatable(self, objectMT)
end

objectMT.__index = objectMT
objectMT.__eq = function(self, other)
    return self.id == other.id
end
objectMT.__gc = function(self)
    self._callbk = nil
    self:stopTracking()
    for _,v in ipairs(self:monitoredRegions()) do self:removeMonitoredRegion(v.identifier) end
    -- yeah, internal gc will get these, but it takes two passes to get both, so lets just kill both at once
    objectInternals[self.id] = nil
    objectInternals[self] = nil
    setmetatable(self, nil)
end
objectMT.__tostring = function(self)
    -- I'm a traditionalist... it really shouldn't matter to the user that we're using a
    -- table rather than a true userdata, so the tostring method should act similarly
    return string.format("%s: (%s)", USERDATA_TAG, self.label)
end

--- hs.location:startTracking() -> locationObject
--- Method
--- Enable callbacks for location changes/refinements for this locationObject
---
--- Parameters:
---  * None
---
--- Returns:
---  * the locationObject
---
--- Notes:
---  * This function activates Location Services for Hammerspoon, so the first time you call this, you may be prompted to authorise Hammerspoon to use Location Services.
objectMT.startTracking = function(self)
    local result = true
    -- if startedFor is empty, then start
    if not next(startedFor) then result = locationStart() end
    -- if result is true (it will only be false if we tried to start and failed), update for id
    if result then startedFor[self.id] = true end
    return self
end

--- hs.location:stopTracking() -> locationObject
--- Method
--- Disable callbacks for location changes/refinements for this locationObject
---
--- Parameters:
---  * None
---
--- Returns:
---  * the locationObject
objectMT.stopTracking = function(self)
    -- if startedFor is not empty, then clear for id
    if next(startedFor) then
        startedFor[self.id] = nil
        -- now, if startedFor *is* empty, then actually stop
        if not next(startedFor) then locationStop() end
    end
    return self
end

--- hs.location:distanceFrom(locationTable) -> distance | nil
--- Method
--- Enable callbacks for location changes/refinements for this locationObject
---
--- Parameters:
---  * None
---
--- Returns:
---  * the distance the specified location is from the current location in meters or nil if Location Services cannot be enabled for Hammerspoon. The measurement is made by tracing a line that follows an idealised curvature of the earth
---
--- Notes:
---  * This function activates Location Services for Hammerspoon, so the first time you call this, you may be prompted to authorise Hammerspoon to use Location Services.
objectMT.distanceFrom = function(self, ...)
    local current = self:get()
    if current then
        return module.distance(self:get(), ...)
    else
        return nil
    end
end

--- hs.location:monitoredRegions() -> table | nil
--- Method
--- Returns a table containing the regionTables for the regions currently being monitored for this locationObject
---
--- Parameters:
---  * None
---
--- Returns:
---  * if Location Services can be enabled for Hammerspoon, returns a table containing regionTables for each region which is being monitored for this locationObject; otherwise nil
---
--- Notes:
---  * This method activates Location Services for Hammerspoon, so the first time you call this, you may be prompted to authorise Hammerspoon to use Location Services.
local monitoredRegions = module._monitoredRegions
objectMT.monitoredRegions = function(self)
    local regions = monitoredRegions()
    if regions then
        local results = {}
        for _, v in ipairs(regions) do
            if self.regions[v.identifier] then
                table.insert(results, v)
                -- [CLLocationManager monitoredRegions] returns a copy of the region data being
                -- monitored and this copy does not reliably contain the proper values for the
                -- notifyOnEntry and notifyOnExit keys... it must elsewhere, because the proper
                -- notifications *do* occur, but what we get back has random values for these
                -- fields, so we copy them at creation time and "reset" them here
                results[#results].notifyOnEntry = self.regions[v.identifier].notifyOnEntry
                results[#results].notifyOnExit  = self.regions[v.identifier].notifyOnExit
                -- return the objects name for the region, not the internal one
                results[#results].identifier = self.regions[v.identifier].identifier
            end
        end
        return results
    else
        return nil
    end
end

--- hs.location:addMonitoredRegion(regionTable) -> locationObject | nil
--- Method
--- Adds a region to be monitored by Location Services
---
--- Parameters:
---  * `regionTable` - a region table as described in the module header
---
--- Returns:
---  * if the region table was able to be added to Location Services for monitoring, returns the locationObject; otherwise returns nil
---
--- Notes:
---  * This method activates Location Services for Hammerspoon, so the first time you call this, you may be prompted to authorise Hammerspoon to use Location Services.
---  * If the `identifier` key is not provided, a new UUID string is generated and used as the identifier.
---  * If the `identifier` key matches an already monitored region, this region will replace the existing one.
local addMonitoredRegion = module._addMonitoredRegion
objectMT.addMonitoredRegion = function(self, newRegion)
    local regionDetails, newIdentifier = {}, self.id
    if type(newRegion) == "table" then
--         if newRegion.identifier:match("%%%%") then
--             error("region identifier cannot contain internal delimiter '%%'", 2)
--         end
        -- in case they are keeping the newRegion table somewhere else, we don't want to modify it
        newRegion = simpleCopy(newRegion)
        -- now capture what we need for tracking and reference by other region aware code
        regionDetails.identifier = newRegion.identifier or host.uuid()
        if type(newRegion.notifyOnEntry) == "boolean" then
            regionDetails.notifyOnEntry = newRegion.notifyOnEntry
        else
            regionDetails.notifyOnEntry = true
        end
        if type(newRegion.notifyOnExit) == "boolean" then
            regionDetails.notifyOnExit = newRegion.notifyOnExit
        else
            regionDetails.notifyOnExit = true
        end
        newIdentifier = newIdentifier .. "%%" .. regionDetails.identifier
        newRegion.identifier = newIdentifier
    end
    -- else if not a table, the next line will error out for us
    local wasAdded = addMonitoredRegion(newRegion)
    if wasAdded then
        self.regions[newIdentifier] = regionDetails
        return self
    else
        return wasAdded
    end
end

--- hs.location:removeMonitoredRegion(identifier) -> locationObject | false | nil
--- Method
--- Removes a monitored region from Location Services
---
--- Parameters:
---  * `identifier` - a string which should contain the identifier of the region to remove from monitoring
---
--- Returns:
---  * if the region identifier matches a currently monitored region, returns the locationObject; if it does not match a currently monitored region, returns false; returns nil if an error occurs or if Location Services is not currently active (no function or method which activates Location Services has been invoked yet) or enabled for Hammerspoon.
---
--- Notes:
---  * This method activates Location Services for Hammerspoon, so the first time you call this, you may be prompted to authorise Hammerspoon to use Location Services.
---  * If the `identifier` key is not provided, a new UUID string is generated and used as the identifier.
---  * If the `identifier` key matches an already monitored region, this region will replace the existing one.
local removeMonitoredRegion = module._removeMonitoredRegion
objectMT.removeMonitoredRegion = function(self, identifier)
    local newIdentifier = self.id .. "%%" .. identifier
    local wasRemoved = removeMonitoredRegion(newIdentifier)
    if wasRemoved then
        self.regions[newIdentifier] = nil
        return self
    else
        return wasRemoved
    end
end

module._monitoredRegions = nil      -- not supported in legacy mode, so hide from use
module._addMonitoredRegion = nil    -- not supported in legacy mode, so hide from use
module._removeMonitoredRegion = nil -- not supported in legacy mode, so hide from

--- hs.location:currentRegion() -> identifier | nil
--- Method
--- Returns the string identifier for the current region
---
--- Parameters:
---  * None
---
--- Returns:
---  * the string identifier for the region that the current location is within, or nil if the current location is not within a currently monitored region or location services cannot be enabled for Hammerspoon.
---
--- Notes:
---  * This method activates Location Services for Hammerspoon, so the first time you call this, you may be prompted to authorise Hammerspoon to use Location Services.
objectMT.currentRegion = function(self)
    local location, regions = self:location(), self:monitoredRegions()
    local currentRegion, currentRadius = nil, math.huge
    if location then
        for _,v in ipairs(regions) do
            if module.distance(location, v) < v.radius and v.radius < currentRadius then
                currentRadius, currentRegion = v.radius, v.identifier
            end
        end
    end
    return currentRegion
end

--- hs.location:callback(fn) -> locationObject
--- Method
--- Sets or removes the callback function for this locationObject
---
--- Parameters:
---  * a function, or nil to remove the current function, which will be invoked as a callback for messages generated by this locationObject.  The callback function should expect 3 or 4 arguments as follows:
---    * the locationObject itself
---    * a string specifying the message generated by the locationObject:
---      * "didChangeAuthorizationStatus" - the user has changed the authorization status for Hammerspoon's use of Location Services.  The third argument will be a string as described in the [hs.location.authorizationStatus](#authorizationStatus) function.
---      * "didUpdateLocations"           - the current location has changed or been refined.  This message will only occur if location tracking has been enabled with [hs.location:startTracking](#startTracking). The third argument will be a table containing one or more locationTables as array elements.  The most recent location update is contained in the last element of the array.
---      * "didFailWithError"             - there was an error retrieving location information. The third argument will be a string describing the error that occurred.
---      * "didStartMonitoringForRegion"  - a new region has successfully been added to the regions being monitored.  The third argument will be the regionTable for the region which was just added.
---      * "monitoringDidFailForRegion"   - an error occurred while trying to add a new region to the list of monitored regions. The third argument will be the regionTable for the region that could not be added, and the fourth argument will be a string containing an error message describing why monitoring for the region failed.
---      * "didEnterRegion"               - the current location has entered a region with the `notifyOnEntry` field set to true specified with the [hs.location:addMonitoredRegion](#addMonitoredRegion) method. The third argument will be the regionTable for the region entered.
---      * "didExitRegion"                - the current location has exited a region with the `notifyOnExit` field set to true specified with the [hs.location:addMonitoredRegion](#addMonitoredRegion) method. The third argument will be the regionTable for the region exited.
---
--- Returns:
---  * the locationObject
objectMT.callback = function(self, ...)
    -- sigh, the only way to check for an explicit nil
    local args = table.pack(...)
    if args.n == 1 then
        local fn = args[1]
        if type(fn) == "function" or type(fn) == "nil" then
            self._callbk = fn
        else
            error("expeected a function or nil, found " .. type(fn), 2)
        end
    else
        error("expected 1 argument, found " .. tostring(args.n), 2)
    end
    return self
end

--- hs.location:location() -> locationTable | nil
--- Method
--- Returns the current location
---
--- Parameters:
---  * None
---
--- Returns:
---  * If successful, a locationTable as described in the module header, otherwise nil.
---
--- Notes:
---  * This function activates Location Services for Hammerspoon, so the first time you call this, you may be prompted to authorise Hammerspoon to use Location Services.
---  * If access to Location Services is enabled for Hammerspoon, this function will return the most recent cached data for the computer's location.
---    * Internally, the Location Services cache is updated whenever additional WiFi networks are detected or lost (not necessarily joined). When update tracking is enabled with the [hs.location.start](#start) function, calculations based upon the RSSI of all currently seen networks are preformed more often to provide a more precise fix, but it's still based on the WiFi networks near you.
objectMT.location = function()
    return module.get()
end

-- Return Module Object --------------------------------------------------

-- assign to the registry in case we ever need to access the metatable from the C side
debug.getregistry()[USERDATA_TAG] = objectMT

-- the following allows access to internal state and methods/functions which are otherwise hidden
-- because the average user shouldn't need them, but they may prove useful when debugging; this
-- allows us to access them without advertising them either through the docs or hs.inspect
local internal = {}
internal._fakeLocationChange, module._fakeLocationChange = module._fakeLocationChange, nil
internal.__legacyCallbacks      = legacyCallbacks       -- legacy callback tags -> { fn, distance, last }
internal.__startedFor           = startedFor            -- which trackers have been started
internal.__objectInternals      = objectInternals       -- internals for "object" version
internal._monitoredRegions      = monitoredRegions      -- actual monitoredRegions function
internal._addMonitoredRegion    = addMonitoredRegion    -- actual addMonitoredRegion function
internal._removeMonitoredRegion = removeMonitoredRegion -- actual removeMonitoredRegion function
internal._registerCallback      = registerCallback      -- actual registerCallback function
internal._start                 = locationStart         -- actual module start function without wrapper
internal._stop                  = locationStop          -- actual module stop function without wrapper
internal._debugHelp = function()
    local results = "Debugging keys for " .. USERDATA_TAG .. " are:\n"
    local size = 0
    for k, _ in pairs(internal) do if #k > size then size = #k end end
    for k, v in require("hs.fnutils").sortByKeys(internal) do
        results = results .. string.format("    %-" .. tostring(size) .. "s %s\n", k, tostring(v))
    end
    return results
end

-- now add metamethod that allows actually using these hidden items
local meta = getmetatable(module)
meta.__index = function(_, key) return internal[key] end
-- protect our debugging keys, but allow users to inject other stuff if they wish
meta.__newindex = function(_, key, value)
    if internal[key] then
        error(tostring(key) .. " is a protected key in " .. USERDATA_TAG, 2)
    else
        module[key] = value
    end
end
setmetatable(module, meta)

return module
