--- === hs.caffeinate ===
---
--- Control system power states (sleeping, preventing sleep, screen locking, etc)
---
--- **NOTE**: Any sleep preventions will be removed when hs.reload() is called. A future version of the module will save/restore state across reloads.

local caffeinate = require "hs.libcaffeinate"
caffeinate.watcher = require "hs.libcaffeinatewatcher"
local applescript = require "hs.applescript"

--- hs.caffeinate.set(sleepType, aValue, acAndBattery)
--- Function
--- Configures the sleep prevention settings
---
--- Parameters:
---  * sleepType - A string containing the type of sleep to be configured. The value should be one of:
---   * displayIdle - Controls whether the screen will be allowed to sleep (and also the system) if the user is idle.
---   * systemIdle - Controls whether the system will be allowed to sleep if the user is idle (display may still sleep).
---   * system - Controls whether the system will be allowed to sleep for any reason.
---  * aValue - A boolean, true if the specified type of sleep should be prevented, false if it should be allowed
---  * acAndBattery - A boolean, true if the sleep prevention should apply to both AC power and battery power, false if it should only apply to AC power.
---
--- Returns:
---  * None
---
--- Notes:
---  * These calls are not guaranteed to prevent the system sleep behaviours described above. The OS may override them if it feels it must (e.g. if your CPU temperature becomes dangerously high).
---  * The acAndBattery argument only applies to the `system` sleep type.
---  * You can toggle the acAndBattery state by calling `hs.caffeinate.set()` again and altering the acAndBattery value.
---  * The acAndBattery option does not appear to work anymore - it is based on private API that is not allowed in macOS 10.15 when running with the Hardened Runtime (which Hammerspoon now uses).
function caffeinate.set(aType, aValue, acAndBattery)
    if (aType == "displayIdle") then
        if (aValue == true) then
            caffeinate.preventIdleDisplaySleep()
        else
            caffeinate.allowIdleDisplaySleep()
        end
    elseif (aType == "systemIdle") then
        if (aValue == true) then
            caffeinate.preventIdleSystemSleep()
        else
            caffeinate.allowIdleSystemSleep()
        end
    elseif (aType == "system") then
        if (aValue == true) then
            caffeinate.preventSystemSleep(acAndBattery)
        else
            caffeinate.allowSystemSleep()
        end
    else
        print("Unknown type: " .. aType)
    end
end

--- hs.caffeinate.get(sleepType) -> bool or nil
--- Function
--- Queries whether a particular sleep type is being prevented
---
--- Parameters:
---  * sleepType - A string containing the type of sleep to inspect (see [hs.caffeinate.set()](#set) for information about the possible values)
---
--- Returns:
---  * True if the specified type of sleep is being prevented, false if not. nil if sleepType was an invalid value
function caffeinate.get(aType)
    if (aType == nil) then
        print("No sleepType specified")
        return nil
    end
    if (aType == "displayIdle") then
        return caffeinate.isIdleDisplaySleepPrevented()
    elseif (aType == "systemIdle") then
        return caffeinate.isIdleSystemSleepPrevented()
    elseif (aType == "system") then
        return caffeinate.isSystemSleepPrevented()
    else
        print("Unknown type: " .. aType)
    end

    return nil
end

--- hs.caffeinate.toggle(sleepType) -> bool or nil
--- Function
--- Toggles the current state of the specified type of sleep
---
--- Parameters:
---  * sleepType - A string containing the type of sleep to toggle (see [hs.caffeinate.set()](#set) for information about the possible values)
---
--- Returns:
---  * True if the specified type of sleep is being prevented, false if not. nil if sleepType was an invalid value
---
--- Notes:
---  * If systemIdle is toggled to on, it will apply to AC only
function caffeinate.toggle(aType)
    local current = caffeinate.get(aType)
    if (current == nil) then
        return nil
    end
    caffeinate.set(aType, not current)
    return caffeinate.get(aType)
end

function caffeinate.preventSystemSleep(acAndBattery)
    acAndBattery = acAndBattery or false

    caffeinate._preventSystemSleep(acAndBattery)
end

--- hs.caffeinate.fastUserSwitch()
--- Function
--- Show the Fast User Switch screen (ie a login screen without logging out first)
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function caffeinate.fastUserSwitch()
    os.execute("/System/Library/CoreServices/Menu\\ Extras/User.menu/Contents/Resources/CGSession -suspend")
end

--- hs.caffeinate.startScreensaver()
--- Function
--- Request the system start the screensaver (which may lock the screen if the OS is configured to do so)
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function caffeinate.startScreensaver()
    os.execute("open -a ScreenSaverEngine")
end

--- hs.caffeinate.logOut()
--- Function
--- Request the system log out the current user
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function caffeinate.logOut()
    applescript('tell application "System Events" to log out')
end

--- hs.caffeinate.restartSystem()
--- Function
--- Request the system reboot
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function caffeinate.restartSystem()
    applescript('tell application "System Events" to restart')
end

--- hs.caffeinate.shutdownSystem()
--- Function
--- Request the system log out and power down
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function caffeinate.shutdownSystem()
    applescript('tell application "System Events" to shut down')
end

-- allow reverse lookups of numeric values passed into callback function
local watcherMT = getmetatable(caffeinate.watcher)
watcherMT.__index = function(self, key)
    if math.type(key) == "integer" then
        local answer = nil
        for k, v in pairs(self) do
            if math.type(v) == "integer" and key == v then
                answer = k
                break
            end
        end
        return answer
    else
        return nil
    end
end
caffeinate.watcher = setmetatable(caffeinate.watcher, watcherMT)

return caffeinate
