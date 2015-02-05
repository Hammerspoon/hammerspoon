--- === hs.location ===
---
--- Determine the machine's location and useful information about that location

local location = require("hs.location.internal")
local internal = {}
internal.__callbacks = {}

--- hs.location.register(tag, fn[, distance])
--- Function
--- Registers a callback function to be called when the system location is updated
---
--- Parameters:
---  * tag - A string containing a unique tag, used to identify the callback later
---  * fn - A function to be called when the system location is updated. The function should accept a single argument, which will be a table containing the same data as is returned by `hs.location.get()`
---  * distance - An optional number containing the minimum distance in meters that the system should have moved, before calling the callback. Defaults to 0
---
--- Returns:
---  * None
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
--- Unregisters a callback
---
--- Parameters:
---  * tag - A string containing the unique tag a callback was registered with
---
--- Returns:
---  * None
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

-- -------- Functions related to sunrise/sunset times -----------------

local rad = math.rad
local deg = math.deg
local floor = math.floor
local frac = function(n) return n - floor(n) end
local cos = function(d) return math.cos(rad(d)) end
local acos = function(d) return deg(math.acos(d)) end
local sin = function(d) return math.sin(rad(d)) end
local asin = function(d) return deg(math.asin(d)) end
local tan = function(d) return math.tan(rad(d)) end
local atan = function(d) return deg(math.atan(d)) end

local function fit_into_range(val, min, max)
   local range = max - min
   local count
   if val < min then
      count = floor((min - val) / range) + 1
      return val + count * range
   elseif val >= max then
      count = floor((val - max) / range) + 1
      return val - count * range
   else
      return val
   end
end

local function day_of_year(date)
   local n1 = floor(275 * date.month / 9)
   local n2 = floor((date.month + 9) / 12)
   local n3 = (1 + floor((date.year - 4 * floor(date.year / 4) + 2) / 3))
   return n1 - (n2 * n3) + date.day - 30
end

local function sunturn_time(date, rising, latitude, longitude, zenith, local_offset)
   local n = day_of_year(date)

   -- Convert the longitude to hour value and calculate an approximate time
   local lng_hour = longitude / 15

   local t
   if rising then -- Rising time is desired
      t = n + ((6 - lng_hour) / 24)
   else -- Setting time is desired
      t = n + ((18 - lng_hour) / 24)
   end

   -- Calculate the Sun's mean anomaly
   local M = (0.9856 * t) - 3.289

   -- Calculate the Sun's true longitude
   local L = fit_into_range(M + (1.916 * sin(M)) + (0.020 * sin(2 * M)) + 282.634, 0, 360)

   -- Calculate the Sun's right ascension
   local RA = fit_into_range(atan(0.91764 * tan(L)), 0, 360)

   -- Right ascension value needs to be in the same quadrant as L
   local Lquadrant  = floor(L / 90) * 90
   local RAquadrant = floor(RA / 90) * 90
   RA = RA + Lquadrant - RAquadrant

   -- Right ascension value needs to be converted into hours
   RA = RA / 15

   -- Calculate the Sun's declination
   local sinDec = 0.39782 * sin(L)
   local cosDec = cos(asin(sinDec))

   -- Calculate the Sun's local hour angle
   local cosH = (cos(zenith) - (sinDec * sin(latitude))) / (cosDec * cos(latitude))

   if rising and cosH > 1 then
      return "N/R" -- The sun never rises on this location on the specified date
   elseif cosH < -1 then
      return "N/S" -- The sun never sets on this location on the specified date
   end

   -- Finish calculating H and convert into hours
   local H
   if rising then
      H = 360 - acos(cosH)
   else
      H = acos(cosH)
   end
   H = H / 15

   -- Calculate local mean time of rising/setting
   local T = H + RA - (0.06571 * t) - 6.622

   -- Adjust back to UTC
   local UT = fit_into_range(T - lng_hour, 0, 24)

   -- Convert UT value to local time zone of latitude/longitude
   local LT =  UT + local_offset

   return os.time({ day = date.day, month = date.month, year = date.year,
                    hour = floor(LT), min = frac(LT) * 60})
end

--- hs.location.sunrise(latitude, longitude, offset[, date]) -> number or string
--- Function
--- Returns the time of official sunrise for the supplied location
---
--- Parameters:
---  * latitude - A number containing a latitude
---  * longitude - A number containing a longitude
---  * offset - A number containing the offset from UTC (in hours) for the given latitude/longitude
---  * date - An optional table containing date information (equivalent to the output of ```os.date("*t")```). Defaults to the current date
---
--- Returns:
---  * A number containing the time of sunrise (represented as seconds since the epoch) for the given date. If no date is given, the current date is used. If the sun doesn't rise on the given day, the string "N/R" is returned.
---
--- Notes:
---  * You can turn the return value into a more useful structure, with ```os.date("*t", returnvalue)```
location.sunrise = function (lat, lon, offset, date)
    local zenith = 90.83
    if not date then
        date = os.date("*t")
    end
    return sunturn_time(date, true, lat, lon, zenith, offset)
end

--- hs.location.sunset(latitude, longitude, offset[, date]) -> number or string
--- Function
--- Returns the time of official sunset for the supplied location
---
--- Parameters:
---  * latitude - A number containing a latitude
---  * longitude - A number containing a longitude
---  * offset - A number containing the offset from UTC (in hours) for the given latitude/longitude
---  * date - An optional table containing date information (equivalent to the output of ```os.date("*t")```). Defaults to the current date
---
--- Returns:
---  * A number containing the time of sunset (represented as seconds since the epoch) for the given date. If no date is given, the current date is used. If the sun doesn't set on the given day, the string "N/S" is returned.
---
--- Notes:
---  * You can turn the return value into a more useful structure, with ```os.date("*t", returnvalue)```
location.sunset = function (lat, lon, offset, date)
    local zenith = 90.83
    if not date then
        date = os.date("*t")
    end
    return sunturn_time(date, false, lat, lon, zenith, offset)
end

local meta = getmetatable(location)
meta.__index = function(_, key) return internal[key] end
setmetatable(location, meta)
return location
