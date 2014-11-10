--- === hs.location ===
---
--- Determine the machine's location

local location = require("hs.location.internal")
local internal = {}
internal.__callbacks = {}

--- hs.location.register(tag, fn[, distance])
--- Function
--- Register a callback function with the specified tag to be invoked when hs.location receives an updated location.  The optional distance argument is a number representing the distance in meters that the location must change by before invoking the callback again.  If it is not present, then all updates to the current location will invoke the callback.  The callback function will be called with the result of `hs.location.get` as it's argument.
location.register = function(tag, fn, distance)
    if internal.__callbacks[tag] then
        error("Callback tag '"..tag.."' already registered for hs.location.", 2)
    else
        internal.__callbacks[tag] = {
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
--- Unregisters the callback function with the specified tag.
location.unregister = function(tag)
    internal.__callbacks[tag] = nil
end

-- Set up callback dispatcher

internal.__dispatch = function()
    local locationNow = location.get()
    for tag, callback in pairs(internal.__callbacks) do
        if not(callback.distance and location.distance(locationNow, callback.last) < callback.distance) then
            callback.last = {
                latitude = locationNow.latitude,
                longitude = locationNow.longitude,
                timestamp = locationNow.timestamp
            }
            callback.fn(locationNow)
        end
    end
--    print("Proof of concept: ",hs.inspect(location.get()))
end

local meta = getmetatable(location)
meta.__index = function(_, key) return internal[key] end
setmetatable(location, meta)
return location
