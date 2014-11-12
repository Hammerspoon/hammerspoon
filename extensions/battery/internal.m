#import <Cocoa/Cocoa.h>
#import <lauxlib.h>
// #import <Carbon/Carbon.h>
#import <IOKit/ps/IOPowerSources.h>
#import <IOKit/ps/IOPSKeys.h>
#import <IOKit/pwr_mgt/IOPM.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

// Helper functions to yank an object from a dictionary by key, and push it onto the LUA stack.
// May be switched to use global NSObject_to_lua, if it ever actually lands in Hammerspoon
// core; but since we're only needing a string, number, or boolean, and only at the top-level
// of the dictionary object, this highly simplified version works just as well.
static void NSObject_to_lua(lua_State* L, id obj) {
    if (obj == nil || [obj isEqual: [NSNull null]]) { lua_pushnil(L); }
    else if ([obj isKindOfClass: [NSNumber class]]) {
        NSNumber* number = obj;
        if (number == (id)kCFBooleanTrue)
            lua_pushboolean(L, YES);
        else if (number == (id)kCFBooleanFalse)
            lua_pushboolean(L, NO);
        else
            lua_pushnumber(L, [number doubleValue]);
    } else if ([obj isKindOfClass: [NSString class]]) {
        NSString* string = obj;
        lua_pushstring(L, [string UTF8String]);
    } else {
        lua_pushstring(L, [[NSString stringWithFormat:@"<Object> : %@", obj] UTF8String]) ;
    }
}

static int _push_dict_key_value(lua_State* L, NSDictionary* dict, NSString* key) {
    id value = [dict objectForKey:key];
    NSObject_to_lua(L, value);
    return 1;
}

// Gets battery info from IOPM API.
NSDictionary* get_iopm_battery_info() {
    mach_port_t masterPort;
    CFArrayRef batteryInfo;

    if (kIOReturnSuccess == IOMasterPort(MACH_PORT_NULL, &masterPort) &&
        kIOReturnSuccess == IOPMCopyBatteryInfo(masterPort, &batteryInfo) &&
        CFArrayGetCount(batteryInfo))
    {
        CFDictionaryRef battery = CFDictionaryCreateCopy(NULL, CFArrayGetValueAtIndex(batteryInfo, 0));
        CFRelease(batteryInfo);
        return (__bridge_transfer NSDictionary*) battery;
    }
    return NULL;
}

// Get battery info from IOPS API.
NSDictionary* get_iops_battery_info() {
    CFTypeRef info = IOPSCopyPowerSourcesInfo();

    if (info == NULL)
        return NULL;


    CFArrayRef list = IOPSCopyPowerSourcesList(info);

    // Nothing we care about here...
    if (list == NULL || !CFArrayGetCount(list)) {
        if (list)
            CFRelease(list);

        CFRelease(info);
        return NULL;
    }

    CFDictionaryRef battery = CFDictionaryCreateCopy(NULL, IOPSGetPowerSourceDescription(info, CFArrayGetValueAtIndex(list, 0)));

    // Battery is released by ARC transfer.
    CFRelease(list);
    CFRelease(info);

    return (__bridge_transfer NSDictionary* ) battery;
}

// Get battery info from IOPMPS Apple Smart Battery API.
NSDictionary* get_iopmps_battery_info() {
    io_registry_entry_t entry = 0;
    entry = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceNameMatching("AppleSmartBattery"));
    if (entry == IO_OBJECT_NULL)
        return nil;

    CFMutableDictionaryRef battery;
    IORegistryEntryCreateCFProperties(entry, &battery, NULL, 0);
    return (__bridge_transfer NSDictionary *) battery;
}

/// hs.battery.cycles() -> number
/// Function
/// Returns the number of cycles the connected battery has went through.
static int battery_cycles(lua_State *L) {
    return _push_dict_key_value(L, get_iopm_battery_info(), @kIOBatteryCycleCountKey);
}

/// hs.battery.name() -> string
/// Function
/// Returns the name of the battery.
static int battery_name(lua_State *L) {
    return _push_dict_key_value(L, get_iops_battery_info(), @kIOPSNameKey);
}

/// hs.battery.maxCapacity() -> number
/// Function
/// Returns the current maximum capacity of the battery in mAh.
static int battery_maxcapacity(lua_State *L) {
    return _push_dict_key_value(L, get_iopm_battery_info(), @kIOBatteryCapacityKey);
}

/// hs.battery.capacity() -> number
/// Function
/// Returns the current capacity of the battery in mAh.
static int battery_capacity(lua_State *L) {
    return _push_dict_key_value(L, get_iopm_battery_info(), @kIOBatteryCurrentChargeKey);
}

/// hs.battery.designCapacity() -> number
/// Function
/// Returns the design capacity of the battery in mAh.
static int battery_designcapacity(lua_State *L) {
    return _push_dict_key_value(L, get_iopmps_battery_info(), @kIOPMPSDesignCapacityKey);
}

/// hs.battery.voltage() -> number
/// Function
/// Returns the voltage flow of the battery in mV.
static int battery_voltage(lua_State *L) {
    return _push_dict_key_value(L, get_iopm_battery_info(), @kIOBatteryVoltageKey);
}

/// hs.battery.amperage() -> number
/// Function
/// Returns the amperage of the battery in mA. (will be negative if battery is discharging)
static int battery_amperage(lua_State *L) {
    return _push_dict_key_value(L, get_iopm_battery_info(), @kIOBatteryAmperageKey);
}

/// hs.battery.watts() -> number
/// Function
/// Returns the watts into or out of the battery in Watt (will be negative if battery is discharging)
static int battery_watts(lua_State *L) {
    NSDictionary* battery = get_iopm_battery_info();

    NSNumber *amperage = [battery objectForKey:@kIOBatteryVoltageKey];
    NSNumber *voltage = [battery objectForKey:@kIOBatteryAmperageKey];

    if (amperage && voltage) {
        double battery_wattage = ([amperage doubleValue] * [voltage doubleValue]) / 1000000;
        lua_pushnumber(L, battery_wattage);
    } else
        lua_pushnil(L);

    return 1;
}

/// hs.battery.health() -> string
/// Function
/// Returns the health status of the battery. One of {Good, Fair, Poor}
static int battery_health(lua_State *L) {
    return _push_dict_key_value(L, get_iops_battery_info(), @kIOPSBatteryHealthKey);
}

/// hs.battery.healthCondition() -> string
/// Function
/// Returns the health condition status of the battery. One of {Check Battery, Permanent Battery Failure}. Nil if there is no health condition set.
static int battery_healthcondition(lua_State *L) {
    return _push_dict_key_value(L, get_iops_battery_info(), @kIOPSBatteryHealthConditionKey);
}

/// hs.battery.percentage() -> number
/// Function
/// Returns the current percentage of the battery between 0 and 100.
static int battery_percentage(lua_State *L) {
    NSDictionary* battery = get_iops_battery_info();

    // IOPS Gives the proper percentage reading, that the OS displays...
    // IOPM... oddly enough... is a few percentage points off.
    NSNumber *maxCapacity = [battery objectForKey:@kIOPSMaxCapacityKey];
    NSNumber *currentCapacity = [battery objectForKey:@kIOPSCurrentCapacityKey];

    if (maxCapacity && currentCapacity) {
        double battery_percentage = ([currentCapacity doubleValue] / [maxCapacity doubleValue]) * 100;
        lua_pushnumber(L, battery_percentage);
    } else
        lua_pushnil(L);

    return 1;
}

/// hs.battery.timeRemaining() -> number
/// Function
/// Returns the time remaining in minutes. Or a negative value: -1 = calculating time remaining, -2 = unlimited (i.e. you're charging, or apple has somehow discovered an infinite power source.)

static int battery_timeremaining(lua_State* L) {
    CFTimeInterval remaining = IOPSGetTimeRemainingEstimate();

    if (remaining > 0)
        remaining /= 60;

    lua_pushnumber(L, remaining);
    return 1;
}

/// hs.battery.timeToFullCharge() -> number
/// Function
/// Returns the time remaining to a full charge in minutes. Or a negative value, -1 = calculating time remaining.
static int battery_timetofullcharge(lua_State* L) {
    return _push_dict_key_value(L, get_iops_battery_info(), @kIOPSTimeToFullChargeKey);
}

/// hs.battery.isCharging() -> boolean
/// Function
/// Returns true if the battery is charging.
static int battery_ischarging(lua_State* L) {
    return _push_dict_key_value(L, get_iops_battery_info(), @kIOPSIsChargingKey);
}

/// hs.battery.isCharged() -> boolean
/// Function
/// Returns true if battery is charged.
static int battery_ischarged(lua_State* L) {
    return _push_dict_key_value(L, get_iops_battery_info(), @kIOPSIsChargedKey);
}

/// hs.battery.isFinishingCharge() -> boolean
/// Function
/// Returns true if battery is finishing charge.
static int battery_isfinishingcharge(lua_State* L) {
    return _push_dict_key_value(L, get_iops_battery_info(), @kIOPSIsFinishingChargeKey);
}

/// hs.battery.powerSource() -> boolean
/// Function
/// Returns current source of power. One of {AC Power, Battery Power, Off Line}.
static int battery_powersource(lua_State* L) {
    return _push_dict_key_value(L, get_iops_battery_info(), @kIOPSPowerSourceStateKey);
}

static const luaL_Reg battery_lib[] = {
    {"cycles", battery_cycles},
    {"name", battery_name},
    {"maxCapacity", battery_maxcapacity},
    {"capacity", battery_capacity},
    {"designCapacity", battery_designcapacity},
    {"percentage", battery_percentage},
    {"voltage", battery_voltage},
    {"amperage", battery_amperage},
    {"watts", battery_watts},
    {"health", battery_health},
    {"healthCondition", battery_healthcondition},
    {"timeRemaining", battery_timeremaining},
    {"timeToFullCharge", battery_timetofullcharge},
    {"isCharging", battery_ischarging},
    {"isCharged", battery_ischarged},
    {"isFinishingCharge", battery_isfinishingcharge},
    {"powerSource", battery_powersource},
    {NULL, NULL}
};

int luaopen_hs_battery_internal(lua_State* L) {
    luaL_newlib(L, battery_lib);
    return 1;
}
