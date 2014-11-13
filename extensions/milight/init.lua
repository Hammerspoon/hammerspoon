--- === hs.milight ===
---
--- Simple controls for the MiLight LED WiFi bridge (also known as LimitlessLED and EasyBulb)

local milight = require "hs.milight.internal"
milight.cmd = milight._cacheCommands()

-- Internal helper to set brightness
function brightnessHelper(bridge, zonecmd, value)
    if (milight.send(bridge, milight.cmd[zonecmd])) then
        if (value < 0) then
            value = 0
        elseif (value > 25) then
            value = 25
        end
        value = value + 2 -- bridge accepts values between 2 and 27
        result = milight.send(bridge, milight.cmd["brightness"], value)
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
function colorHelper(bridge, zonecmd, value)
    if (milight.send(bridge, milight.cmd[zonecmd])) then
        if (value < 0) then
            value = 0
        elseif (value > 255) then
            value = 255
        end
        return milight.send(bridge, milight.cmd["rgbw"], value)
    else
        return false
    end
end

-- Internal helper to map an integer and a string to a zone command key
function zone2cmdkey(zone, cmdType)
    local zoneString
    if (zone == 0) then
        zoneString = "all_"
    else
        zoneString = "zone"..zone.."_"
    end
    return zoneString..cmdType
end

--- hs.milight.zoneOff(zone) -> bool
--- Method
--- Turns off the specified zone
---
--- Parameters:
---  * zone - 0 for all zones, 1-4 for zones one through four
--- Returns:
---  * True if the command was sent correctly, false if not
function milight:zoneOff(zone)
    return milight.send(self, milight.cmd[zone2cmdkey(zone, "off")])
end

--- hs.milight.zoneOn(zone) -> bool
--- Method
--- Turns on the specified zone
---
--- Parameters:
---  * zone - 0 for all zones, 1-4 for zones one through four
--- Returns:
---  * True if the command was sent correctly, false if not
function milight:zoneOn(zone)
    return milight.send(self, milight.cmd[zone2cmdkey(zone, "on")])
end

--- hs.milight:disco() -> bool
--- Method
--- Cycles through the disco modes
---
--- Parameters:
---  * None
--- Returns:
---  * True if the command was sent correctly, false if not
function milight:discoCycle(zone)
    if (self:zoneOn(zone)) then
        return milight.send(self, milight.cmd["disco"])
    else
        return false
    end
end

--- hs.milight:zoneBrightness(zone, value) -> bool
--- Method
--- Sets brightness for the specified zone
---
--- Parameters:
---  * zone - 0 for all zones, 1-4 for zones one through four
---  * value - Brightness level to set, between 0 and 25
--- Returns:
---  * The value that was sent to the WiFi bridge, or -1 if an error occurred
function milight:zoneBrightness(zone, value)
    return brightnessHelper(self, zone2cmdkey(zone, "on"), value)
end

--- hs.milight:zoneColor(zone, value) -> bool
--- Method
--- Sets RGB color for the specified zone
---
--- Parameters:
---  * zone - 0 for all zones, 1-4 for zones one through four
---  * value - RGB color value between 0 and 255
--- Returns:
---  * True if the command was sent correctly, false if not
function milight:zoneColor(zone, value)
    return colorHelper(self, zone2cmdkey(zone, "on"), value)
end

--- hs.milight.zoneWhite(zone) -> bool
--- Method
--- Sets the specified zone to white
---
--- Parameters:
---  * zone - 0 for all zones, 1-4 for zones one through four
--- Returns:
---  * True if the command was sent correctly, false if not
function milight:zoneWhite(zone)
    if (self:zoneOn(zone)) then
        return milight.send(self, milight.cmd[zone2cmdkey(zone, "white")])
    else
        return false
    end
end

return milight
