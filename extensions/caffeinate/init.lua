--- === hs.caffeinate ===
---
--- Control display/system sleep behaviours
---
--- **NOTE**: Any sleep preventions will be removed when hs.reload() is called. A future version of the module will save/restore state across reloads.

local caffeinate = require "hs.caffeinate.internal"

--- hs.caffeinate.set(sleepType, aValue, acAndBattery)
--- Function
--- Configures the sleep prevention settings.
--- **Arguments:**
--- * sleepType (string):
---     * displayIdle - Controls whether the screen will be allowed to sleep (and also the system) if the user is idle.
---     * systemIdle - Controls whether the system will be allowed to sleep if the user is idle (display may still sleep).
---     * system - Controls whether the system will be allowed to sleep for any reason.
--- * aValue (boolean):
---     * True - The specified sleep type should be prevented.
---     * False - The specified sleep type should be allowed.
--- * acAndBattery (boolean):
---     * True - System should not sleep when on AC or battery.
---     * False - System should not sleep only when on AC.
---
--- **NOTES:**
--- * These calls are not guaranteed to prevent the system sleep behaviours described above. The OS may override them if it feels it must (e.g. if your CPU temperature becomes dangerously high).
--- * The acAndBattery argument only applies to the "system" sleep type.
--- * You can toggle the acAndBattery state by calling set() again and altering the acAndBattery value.
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
--- Queries whether a particular sleep type is being prevented by hs.
--- **Arguments:**
--- * sleepType (string): (see [set](#set) for information about these values)
---     * displayIdle
---     * systemIdle
---     * system
---
--- **Returns:**
--- * true - if the specified sleepType is currently being prevented.
--- * false - if the specified sleepType is not currenly being prevented.
--- * nil - if an invalid sleepType is specified.
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
--- Toggles the current state of the specified sleepType.
--- **Arguments:**
--- * sleepType (string): (see [set](#set) for information about these values)
---     * displayIdle
---     * systemIdle
---     * system
---
--- **Returns:**
--- * true - if the new state of sleepType is prevention.
--- * false - if the new state of sleepType is allowance.
--- * nil - if an invalid sleepType is specified.
---
--- **NOTE:** If systemIdle is toggled to on, it will apply to AC only.
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

return caffeinate
