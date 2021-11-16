--- === hs.milight ===
---
--- Simple controls for the MiLight LED WiFi bridge (also known as LimitlessLED and EasyBulb)

local milight = require "hs.libmilight"
milight.cmd = milight._cacheCommands()
local milightObject = hs.getObjectMetatable("hs.milight")

--- hs.milight.minBrightness
--- Constant
--- Specifies the minimum brightness value that can be used. Defaults to 0
milight.minBrightness = 0
--
--- hs.milight.maxBrightness
--- Constant
--- Specifies the maximum brightness value that can be used. Defaults to 25
milight.maxBrightness = 25

-- Internal helper to set brightness
local function brightnessHelper(bridge, zonecmd, value)
    if (bridge:send(milight.cmd[zonecmd])) then
        if (value < milight.minBrightness) then
            value = milight.minBrightness
        elseif (value > milight.maxBrightness) then
            value = milight.maxBrightness
        end
        value = value + 2 -- bridge accepts values between 2 and 27
        local result = bridge:send(milight.cmd["brightness"], value)
        if (result) then
            return value - 2
        else
            return -1
        end
    else
        return -1
    end
end

-- Internal helper to set color
local function colorHelper(bridge, zonecmd, value)
    if (bridge:send(milight.cmd[zonecmd])) then
        if (value < 0) then
            value = 0
        elseif (value > 255) then
            value = 255
        end
        return bridge:send(milight.cmd["rgbw"], value)
    else
        return false
    end
end

-- Internal helper to map an integer and a string to a zone command key
local function zone2cmdkey(zone, cmdType)
    local zoneString
    if (zone == 0) then
        zoneString = "all_"
    else
        zoneString = "zone"..zone.."_"
    end
    return zoneString..cmdType
end

--- hs.milight:zoneOff(zone) -> bool
--- Method
--- Turns off the specified zone
---
--- Parameters:
---  * zone - A number specifying which zone to operate on. 0 for all zones, 1-4 for zones one through four
---
--- Returns:
---  * True if the command was sent correctly, otherwise false
function milightObject:zoneOff(zone)
    return self:send(milight.cmd[zone2cmdkey(zone, "off")])
end

--- hs.milight:zoneOn(zone) -> bool
--- Method
--- Turns on the specified zone
---
--- Parameters:
---  * zone - A number specifying which zone to operate on. 0 for all zones, 1-4 for zones one through four
---
--- Returns:
---  * True if the command was sent correctly, otherwise false
function milightObject:zoneOn(zone)
    return self:send(milight.cmd[zone2cmdkey(zone, "on")])
end

--- hs.milight:disco() -> bool
--- Method
--- Cycles through the disco modes
---
--- Parameters:
---  * None
---
--- Returns:
---  * True if the command was sent correctly, otherwise false
function milightObject:discoCycle(zone)
    if (self:zoneOn(zone)) then
        return self:send(milight.cmd["disco"])
    else
        return false
    end
end

--- hs.milight:zoneBrightness(zone, value) -> integer
--- Method
--- Sets brightness for the specified zone
---
--- Parameters:
---  * zone - A number specifying which zone to operate on. 0 for all zones, 1-4 for zones one through four
---  * value - A number containing the brightness level to set, between `hs.milight.minBrightness` and `hs.milight.maxBrightness`
---
--- Returns:
---  * A number containing the value that was sent to the WiFi bridge, or -1 if an error occurred
function milightObject:zoneBrightness(zone, value)
    return brightnessHelper(self, zone2cmdkey(zone, "on"), value)
end

--- hs.milight:zoneColor(zone, value) -> bool
--- Method
--- Sets RGB color for the specified zone
---
--- Parameters:
---  * zone - A number specifying which zone to operate on. 0 for all zones, 1-4 for zones one through four
---  * value - A number between 0 and 255 that represents a color
---
--- Returns:
---  * True if the command was sent correctly, otherwise false
---
--- Notes:
---  * The color value is not a normal RGB colour, but rather a lookup in an internal table in the light hardware. While any number between 0 and 255 is valid, there are some useful values worth knowing:
---   * 00 - Violet
---   * 16 - Royal Blue
---   * 32 - Baby Blue
---   * 48 - Aqua
---   * 64 - Mint Green
---   * 80 - Seafoam Green
---   * 96 - Green
---   * 112 - Lime Green
---   * 128 - Yellow
---   * 144 - Yellowy Orange
---   * 160 - Orange
---   * 176 - Red
---   * 194 - Pink
---   * 210 - Fuscia
---   * 226 - Lilac
---   * 240 - Lavendar
function milightObject:zoneColor(zone, value)
    return colorHelper(self, zone2cmdkey(zone, "on"), value)
end

--- hs.milight:zoneWhite(zone) -> bool
--- Method
--- Sets the specified zone to white
---
--- Parameters:
---  * zone - A number specifying which zone to operate on. 0 for all zones, 1-4 for zones one through four
---
--- Returns:
---  * True if the command was sent correctly, otherwise false
function milightObject:zoneWhite(zone)
    if (self:zoneOn(zone)) then
        return self:send(milight.cmd[zone2cmdkey(zone, "white")])
    else
        return false
    end
end

return milight
