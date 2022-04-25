--- === hs.battery ===
---
--- Battery/power information
--- All functions here may return nil, if the information requested is not available.
---
--- This module is based primarily on code from the previous incarnation of Mjolnir by [Steven Degutis](https://github.com/sdegutis/).


local module = require("hs.libbattery")
local fnutils = require("hs.fnutils")

-- private variables and methods -----------------------------------------

local check_list = {
    "cycles",
    "name",
    "maxCapacity",
    "capacity",
    "designCapacity",
    "percentage",
    "voltage",
    "amperage",
    "watts",
    "health",
    "healthCondition",
    "timeRemaining",
    "timeToFullCharge",
    "isCharging",
    "isCharged",
    "isFinishingCharge",
    "powerSource",
    "powerSourceType",
    "batteryType",
    "adapterSerialNumber",
    "batterySerialNumber",
    "otherBatteryInfo",
    "privateBluetoothBatteryInfo",
}

-- Public interface ------------------------------------------------------

module.watcher = require("hs.libbatterywatcher")

--- hs.battery.cycles() -> number
--- Function
--- Returns the number of discharge cycles of the battery
---
--- Parameters:
---  * None
---
--- Returns:
---  * The number of cycles
---
--- Notes:
---  * One cycle is a full discharge of the battery, followed by a full charge. This may also be an aggregate of many smaller discharge-then-charge cycles (e.g. 10 iterations of discharging the battery from 100% to 90% and then charging back to 100% each time, is considered to be one cycle)
module.cycles = function()
    local appleSmartBattery = module._appleSmartBattery() or {}
    return appleSmartBattery.CycleCount
end

--- hs.battery.name() -> string
--- Function
--- Returns the name of the battery
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the name of the battery
module.name = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1].Name
end

--- hs.battery.maxCapacity() -> number
--- Function
--- Returns the maximum capacity of the battery in mAh
---
--- Parameters:
---  * None
---
--- Returns:
---  * A number containing the observed maximum capacity of the battery in mAh
---
--- Notes:
---  * This may exceed the value of `hs.battery.designCapacity()` due to small variations in the production chemistry vs the design
module.maxCapacity = function()
    local appleSmartBattery = module._appleSmartBattery() or {}
    return appleSmartBattery.AppleRawMaxCapacity
end

--- hs.battery.capacity() -> number
--- Function
--- Returns the current capacity of the battery in mAh
---
--- Parameters:
---  * None
---
--- Returns:
---  * A number containing the current capacity of the battery in mAh
---
--- Notes:
---  * This is the measure of how charged the battery is, vs the value of `hs.battery.maxCapacity()`
module.capacity = function()
    local appleSmartBattery = module._appleSmartBattery() or {}
    return appleSmartBattery.AppleRawCurrentCapacity
end

--- hs.battery.designCapacity() -> number
--- Function
--- Returns the design capacity of the battery in mAh.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A number containing the rated maximum capacity of the battery
module.designCapacity = function()
    local appleSmartBattery = module._appleSmartBattery() or {}
    return appleSmartBattery.DesignCapacity
end

--- hs.battery.percentage() -> number
--- Function
--- Returns the current percentage of battery charge
---
--- Parameters:
---  * None
---
--- Returns:
---  * A number containing the percentage of battery charge
module.percentage = function()
    local powerSourceDescription = module._powerSources() or { {} }
    local appleSmartBattery      = module._appleSmartBattery() or {}
    local maxCapacity = powerSourceDescription[1]["Max Capacity"] or appleSmartBattery["MaxCapacity"]
    local curCapacity = powerSourceDescription[1]["Current Capacity"] or appleSmartBattery["CurrentCapacity"]

    if maxCapacity and curCapacity then
        return 100.0 * curCapacity / maxCapacity
    else
        return nil
    end
end

--- hs.battery.voltage() -> number
--- Function
--- Returns the current voltage of the battery in mV
---
--- Parameters:
---  * None
---
--- Returns:
---  * A number containing the current voltage of the battery
module.voltage = function()
    local appleSmartBattery = module._appleSmartBattery() or {}
    return appleSmartBattery.Voltage
end

--- hs.battery.amperage() -> number
--- Function
--- Returns the amount of current flowing through the battery, in mAh
---
--- Parameters:
---  * None
---
--- Returns:
---  * A number containing the amount of current flowing through the battery. The value may be:
---   * Less than zero if the battery is being discharged (i.e. the computer is running on battery power)
---   * Zero if the battery is being neither charged nor discharged
---   * Greater than zero if the battery is being charged
module.amperage = function()
    local appleSmartBattery = module._appleSmartBattery() or {}
    return appleSmartBattery.Amperage
end

--- hs.battery.watts() -> number
--- Function
--- Returns the power entering or leaving the battery, in W
---
--- Parameters:
---  * None
---
--- Returns:
---  * A number containing the rate of energy conversion in the battery. The value may be:
---   * Less than zero if the battery is being discharged (i.e. the computer is running on battery power)
---   * Zero if the battery is being neither charged nor discharged
---   * Greater than zero if the battery is being charged
module.watts = function()
    local appleSmartBattery = module._appleSmartBattery() or {}
    local voltage           = appleSmartBattery.Voltage
    local amperage          = appleSmartBattery.Amperage

    if amperage and voltage then
        return (amperage / voltage) / 1000000
    else
        return nil
    end
end

--- hs.battery.health() -> string
--- Function
--- Returns the health status of the battery.
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing one of {Good, Fair, Poor}, as determined by the Apple Smart Battery controller
module.health = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1].BatteryHealth
end

--- hs.battery.healthCondition() -> string or nil
--- Function
--- Returns the health condition status of the battery.
---
--- Parameters:
---  * None
---
--- Returns:
---  * Nil if there are no health conditions to report, or a string containing either:
---   * "Check Battery"
---   * "Permanent Battery Failure"
module.healthCondition = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1].BatteryHealthCondition
end

--- hs.battery.timeToFullCharge() -> number
--- Function
--- Returns the time remaining for the battery to be fully charged, in minutes
---
--- Parameters:
---  * None
---
--- Returns:
---  * A number containing the time (in minutes) remaining for the battery to be fully charged, or -1 if the remaining time is still being calculated
module.timeToFullCharge = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1]["Time to Full Charge"]
end

--- hs.battery.isCharging() -> boolean
--- Function
--- Returns the charging state of the battery
---
--- Parameters:
---  * None
---
--- Returns:
---  * True if the battery is being charged, false if not
module.isCharging = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1]["Is Charging"]
end

--- hs.battery.isCharged() -> boolean
--- Function
--- Returns the charged state of the battery
---
--- Parameters:
---  * None
---
--- Returns:
---  * True if the battery is charged, false if not
module.isCharged = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1]["Is Charged"]
end

--- hs.battery.isFinishingCharge() -> boolean or string
--- Function
--- Returns true if battery is finishing its charge
---
--- Parameters:
---  * None
---
--- Returns:
---  * True if the battery is in its final charging state (i.e. trickle charging), false if not
module.isFinishingCharge = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1]["Is Finishing Charge"]
end

--- hs.battery.powerSourceType() -> string
--- Function
--- Returns current power source type
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing one of {AC Power, Battery Power, Off Line}.
module.powerSourceType = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1]["Power Source State"]
end

--- hs.battery.batteryType() -> string
--- Function
--- Returns the type of battery present, or nil if there is no battery
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing one of "UPS" or "InternalBattery", or nil if no battery is present.
module.batteryType = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1]["Type"]
end

--- hs.battery.adapterSerialNumber() -> integer | string
--- Function
--- Returns the serial number of the attached power supply, if present
---
--- Parameters:
---  * None
---
--- Returns:
---  * An number or string containing the power supply's serial number, or nil if the adapter is not attached or does not provide one.
module.adapterSerialNumber = function()
    local adapterDetails = module._adapterDetails() or {}
    return adapterDetails.SerialNumber or adapterDetails.SerialString
end

--- hs.battery.batterySerialNumber() -> string
--- Function
--- Returns the serial number of the battery, if present
---
--- Parameters:
---  * None
---
--- Returns:
---  * A string containing the battery's serial number, or nil if there is no battery or the battery or UPS does not provide one.
module.batterySerialNumber = function()
    local powerSourceDescription = module._powerSources() or { {} }
    return powerSourceDescription[1]["Hardware Serial Number"]
end

--- hs.battery.getAll() -> table
--- Function
--- Get all available battery information
---
--- Parameters:
---  * None
---
--- Returns:
---  * A table containing all the information provided by the separate functions in hs.battery
---
--- Notes:
---  * If you require multiple pieces of information about a battery, this function may be more efficient than calling several other functions separately
module.getAll = function()
    local t = {}

    for _, v in ipairs(check_list) do
        t[v] = module[v]()
        if t[v] == nil then t[v] = "n/a" end
    end

    return ls.makeConstantsTable(t)
end

--- hs.battery._report() -> table
--- Function
--- Returns a table containing all of the details concerning the Mac's powersource(s).
---
--- Parameters:
---  * None
---
--- Returns:
---  * a table containing the raw data about the power source(s) for the Mac.
---
--- Notes:
---  * This function is generally not required and is provided to aid in debugging. This function combines the output of the following internally used functions:
---    * `hs.battery._adapterDetails()`
---    * `hs.battery._powerSources()`
---    * `hs.battery._appleSmartBattery()`
---    * `hs.battery._iopmBatteryInfo()`
---
---  * You can view this report by typing `hs.inspect(hs.battery._report())` (or a subset of it by using one of the above listed functions instead) -- it will primarily be of interest when debugging or extending this module and generally not necessary to use.
module._report = function()
    return {
        _adapterDetails    = module._adapterDetails()    or "** not available **",
        _powerSources      = module._powerSources()      or "** not available **",
        _appleSmartBattery = module._appleSmartBattery() or "** not available **",
        _iopmBatteryInfo   = module._iopmBatteryInfo()   or "** not available **",
    }
end

-- Return Module Object --------------------------------------------------

return module
