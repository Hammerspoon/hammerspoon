#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <LuaSkin/LuaSkin.h>

#define kIOPMAssertionAppliesToLimitedPowerKey  CFSTR("AppliesToLimitedPower")

static IOPMAssertionID noIdleDisplaySleep = 0;
static IOPMAssertionID noIdleSystemSleep = 0;
static IOPMAssertionID noSystemSleep = 0;

// Create an IOPM Assertion of specified type and store its ID in the specified variable
static void caffeinate_create_assertion(lua_State *L, CFStringRef assertionType, IOPMAssertionID *assertionID) {
    LuaSkin *skin = [LuaSkin shared];
    IOReturn result = 1;

    if (*assertionID) return;

    result = IOPMAssertionCreateWithDescription(assertionType,
                                                CFSTR("hs.caffeinate"),
                                                NULL,
                                                NULL,
                                                NULL,
                                                0,
                                                NULL,
                                                assertionID);

    if (result != kIOReturnSuccess) {
        [skin logError:@"caffeinate_create_assertion: failed"];
    }
}

// Release a previously stored assertion
static void caffeinate_release_assertion(lua_State *L, IOPMAssertionID *assertionID) {
    LuaSkin *skin = [LuaSkin shared];
    IOReturn result = 1;

    if (!*assertionID) return;

    result = IOPMAssertionRelease(*assertionID);

    if (result != kIOReturnSuccess) {
        [skin logError:@"caffeinate_release_assertion: failed"];
    }

    *assertionID = 0;
}

// ----------------------- Functions for display sleep when user is idle ----------------------------

// Prevent display sleep if the user goes idle (and by implication, system sleep)
static int caffeinate_preventIdleDisplaySleep(lua_State *L) {
    caffeinate_create_assertion(L, kIOPMAssertionTypePreventUserIdleDisplaySleep, &noIdleDisplaySleep);
    return 0;
}

// Allow display sleep if the user goes idle
static int caffeinate_allowIdleDisplaySleep(lua_State *L) {
    caffeinate_release_assertion(L, &noIdleDisplaySleep);
    return 0;
}

// Determine if idle display sleep is currently prevented
static int caffeinate_isIdleDisplaySleepPrevented(lua_State *L) {
    lua_pushboolean(L, noIdleDisplaySleep);
    return 1;
}

// ----------------------- Functions for system sleep when user is idle ----------------------------

// Prevent system sleep if the user goes idle (display may still sleep)
static int caffeinate_preventIdleSystemSleep(lua_State *L) {
    caffeinate_create_assertion(L, kIOPMAssertionTypePreventUserIdleSystemSleep, &noIdleSystemSleep);
    return 0;
}

// Allow system sleep if the user goes idle
static int caffeinate_allowIdleSystemSleep(lua_State *L) {
    caffeinate_release_assertion(L, &noIdleSystemSleep);
    return 0;
}

// Determine if idle system sleep is currently prevented
static int caffeinate_isIdleSystemSleepPrevented(lua_State *L) {
    lua_pushboolean(L, noIdleSystemSleep);
    return 1;
}

// ----------------------- Functions for system sleep ----------------------------

// Prevent system sleep
static int caffeinate_preventSystemSleep(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    IOReturn result = 1;
    BOOL ac_and_battery = false;

    if lua_isboolean(L, 1)
        ac_and_battery = lua_toboolean(L, 1);
    lua_settop(L, 1);

    caffeinate_create_assertion(L, kIOPMAssertionTypePreventSystemSleep, &noSystemSleep);

    if (noSystemSleep) {
        CFBooleanRef value;
        if (ac_and_battery) {
            value = kCFBooleanTrue;
        } else {
            value = kCFBooleanFalse;
        }
        result = IOPMAssertionSetProperty(noSystemSleep,
                                          kIOPMAssertionAppliesToLimitedPowerKey,
                                          (CFBooleanRef)value);
        if (result != kIOReturnSuccess) {
            [skin logError:@"ERROR: Unable to set systemSleep assertion property"];
        }
    }

    return 0;
}

// Allow system sleep
static int caffeinate_allowSystemSleep(lua_State *L) {
    caffeinate_release_assertion(L, &noSystemSleep);
    return 0;
}

// Determine if system sleep is currently prevented
static int caffeinate_isSystemSleepPrevented(lua_State *L) {
    lua_pushboolean(L, noSystemSleep);
    return 1;
}

/// hs.caffeinate.systemSleep()
/// Function
/// Requests the system to sleep immediately
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int caffeinate_systemSleep(lua_State *L __unused) {
    io_connect_t port = IOPMFindPowerManagement(MACH_PORT_NULL);
    IOPMSleepSystem(port);
    IOServiceClose(port);
    return 0;
}

// ----------------------- Lua/hs glue GAR ---------------------

static int caffeinate_gc(lua_State *L) {
    // TODO: We should register which of the assertions we have active, somewhere that persists a reload()
    caffeinate_allowIdleDisplaySleep(L);
    caffeinate_allowIdleSystemSleep(L);
    caffeinate_allowSystemSleep(L);

    return 0;
}

static const luaL_Reg caffeinatelib[] = {
    {"preventIdleDisplaySleep", caffeinate_preventIdleDisplaySleep},
    {"allowIdleDisplaySleep", caffeinate_allowIdleDisplaySleep},
    {"isIdleDisplaySleepPrevented", caffeinate_isIdleDisplaySleepPrevented},

    {"preventIdleSystemSleep", caffeinate_preventIdleSystemSleep},
    {"allowIdleSystemSleep", caffeinate_allowIdleSystemSleep},
    {"isIdleSystemSleepPrevented", caffeinate_isIdleSystemSleepPrevented},

    {"_preventSystemSleep", caffeinate_preventSystemSleep},
    {"allowSystemSleep", caffeinate_allowSystemSleep},
    {"isSystemSleepPrevented", caffeinate_isSystemSleepPrevented},
    {"systemSleep", caffeinate_systemSleep},

    {NULL, NULL}
};

static const luaL_Reg metalib[] = {
    {"__gc", caffeinate_gc},

    {NULL, NULL}
};

/* NOTE: The substring "hs_caffeinate_internal" in the following function's name
         must match the require-path of this file, i.e. "hs.caffeinate.internal". */

int luaopen_hs_caffeinate_internal(lua_State *L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    [skin registerLibrary:caffeinatelib metaFunctions:metalib];

    return 1;
}
