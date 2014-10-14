--- === hs.caffeinate ===
---
--- Prevent various kinds of sleep activities in OSX
---
--- **Usage**:
---     local caffeinate = require "hs.caffeinate"
---
--- **NOTE**: Any sleep preventions will be removed when hs.reload() is called. A future version of the module will save/restore state across reloads.

local caffeinate = require "hs.caffeinate.internal"

--- hs.caffeinate.set(sleepType, aValue, AC_and_battery)
--- Function
--- Configures the sleep prevention settings.
--- **Arguments:**
--- * sleepType (string):
---     * DisplayIdle - Controls whether the screen will be allowed to sleep (and also the system) if the user is idle.
---     * SystemIdle - Controls whether the system will be allowed to sleep if the user is idle (display may still sleep).
---     * System - Controls whether the system will be allowed to sleep for any reason.
--- * aValue (boolean):
---     * True - The specified sleep type should be prevented.
---     * False - The specified sleep type should be allowed.
--- * acAndBattery (boolean):
---     * True - System should not sleep when on AC or battery.
---     * False - System should not sleep only when on AC.
---
--- **NOTES:**
--- * These calls are not guaranteed to prevent the system sleep behaviours described above. The OS may override them if it feels it must (e.g. if your CPU temperature becomes dangerously high).
--- * The acAndBattery argument only applies to the "System" sleep type.
--- * You can toggle the acAndBattery state by calling set() again and altering the AC_and_battery value.
function caffeinate.set(aType, aValue, acAndBattery)
    if (aType == "DisplayIdle") then
        if (aValue == true) then
            caffeinate.prevent_idle_display_sleep()
        else
            caffeinate.allow_idle_display_sleep()
        end
    elseif (aType == "SystemIdle") then
        if (aValue == true) then
            caffeinate.prevent_idle_system_sleep()
        else
            caffeinate.allow_idle_system_sleep()
        end
    elseif (aType == "System") then
        if (aValue == true) then
            caffeinate.prevent_system_sleep(acAndBattery)
        else
            caffeinate.allow_system_sleep()
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
---     * DisplayIdle
---     * SystemIdle
---     * System
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
    if (aType == "DisplayIdle") then
        return caffeinate.is_idle_display_sleep_prevented()
    elseif (aType == "SystemIdle") then
        return caffeinate.is_idle_system_sleep_prevented()
    elseif (aType == "System") then
        return caffeinate.is_system_sleep_prevented()
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
---     * DisplayIdle
---     * SystemIdle
---     * System
---
--- **Returns:**
--- * true - if the new state of sleepType is prevention.
--- * false - if the new state of sleepType is allowance.
--- * nil - if an invalid sleepType is specified.
---
--- **NOTE:** If SystemIdle is toggled to on, it will apply to AC only.
function caffeinate.toggle(aType)
    local current = caffeinate.get(aType)
    if (current == nil) then
        return nil
    end
    caffeinate.set(aType, not current)
    return caffeinate.get(aType)
end

function caffeinate.prevent_system_sleep(ac_and_battery)
    ac_and_battery = ac_and_battery or false

    caffeinate._prevent_system_sleep(ac_and_battery)
end

return caffeinate
