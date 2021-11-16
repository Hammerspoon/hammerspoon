#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <IOKit/pwr_mgt/IOPMLib.h>
#import <LuaSkin/LuaSkin.h>

// Apple Private API items
#define kIOPMAssertionAppliesToLimitedPowerKey  CFSTR("AppliesToLimitedPower")
CFBundleRef loginFramework = NULL;
typedef void (*SACLockScreenImmediatePtr)(void);

static IOPMAssertionID noIdleDisplaySleep = 0;
static IOPMAssertionID noIdleSystemSleep = 0;
static IOPMAssertionID noSystemSleep = 0;

NSString* stringFromError(unsigned int errorVal) {
    NSDictionary *ioReturnMap =
          @{@kIOReturnSuccess:          @"success",
            @kIOReturnError:            @"general error",
            @kIOReturnNoMemory:         @"memory allocation error",
            @kIOReturnNoResources:      @"resource shortage",
            @kIOReturnIPCError:         @"Mach IPC failure",
            @kIOReturnNoDevice:         @"no such device",
            @kIOReturnNotPrivileged:    @"privilege violation",
            @kIOReturnBadArgument:      @"invalid argument",
            @kIOReturnLockedRead:       @"device is read locked",
            @kIOReturnLockedWrite:      @"device is write locked",
            @kIOReturnExclusiveAccess:  @"device is exclusive access",
            @kIOReturnBadMessageID:     @"bad IPC message ID",
            @kIOReturnUnsupported:      @"unsupported function",
            @kIOReturnVMError:          @"virtual memory error",
            @kIOReturnInternalError:    @"internal driver error",
            @kIOReturnIOError:          @"I/O error",
            @kIOReturnCannotLock:       @"cannot acquire lock",
            @kIOReturnNotOpen:          @"device is not open",
            @kIOReturnNotReadable:      @"device is not readable",
            @kIOReturnNotWritable:      @"device is not writeable",
            @kIOReturnNotAligned:       @"alignment error",
            @kIOReturnBadMedia:         @"media error",
            @kIOReturnStillOpen:        @"device is still open",
            @kIOReturnRLDError:         @"rld failure",
            @kIOReturnDMAError:         @"DMA failure",
            @kIOReturnBusy:             @"device is busy",
            @kIOReturnTimeout:          @"I/O timeout",
            @kIOReturnOffline:          @"device is offline",
            @kIOReturnNotReady:         @"device is not ready",
            @kIOReturnNotAttached:      @"device/channel is not attached",
            @kIOReturnNoChannels:       @"no DMA channels available",
            @kIOReturnNoSpace:          @"no space for data",
            @kIOReturnPortExists:       @"device port already exists",
            @kIOReturnCannotWire:       @"cannot wire physical memory",
            @kIOReturnNoInterrupt:      @"no interrupt attached",
            @kIOReturnNoFrames:         @"no DMA frames enqueued",
            @kIOReturnMessageTooLarge:  @"message is too large",
            @kIOReturnNotPermitted:     @"operation is not permitted",
            @kIOReturnNoPower:          @"device is without power",
            @kIOReturnNoMedia:          @"media is not present",
            @kIOReturnUnformattedMedia: @"media is not formatted",
            @kIOReturnUnsupportedMode:  @"unsupported mode",
            @kIOReturnUnderrun:         @"data underrun",
            @kIOReturnOverrun:          @"data overrun",
            @kIOReturnDeviceError:      @"device error",
            @kIOReturnNoCompletion:     @"no completion routine",
            @kIOReturnAborted:          @"operation was aborted",
            @kIOReturnNoBandwidth:      @"bus bandwidth would be exceeded",
            @kIOReturnNotResponding:    @"device is not responding",
            @kIOReturnInvalid:          @"unanticipated driver error",
            };

    return [ioReturnMap objectForKey:[NSNumber numberWithInt:errorVal]];
}

// Create an IOPM Assertion of specified type and store its ID in the specified variable
static void caffeinate_create_assertion(lua_State *L, CFStringRef assertionType, IOPMAssertionID *assertionID) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
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
        [skin logError:[NSString stringWithFormat:@"caffeinate_create_assertion: failed (%@)", stringFromError(result)]];
    }
}

// Release a previously stored assertion
static void caffeinate_release_assertion(lua_State *L, IOPMAssertionID *assertionID) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    IOReturn result = 1;

    if (!*assertionID) return;

    result = IOPMAssertionRelease(*assertionID);

    if (result != kIOReturnSuccess) {
        [skin logError:[NSString stringWithFormat:@"caffeinate_release_assertion: failed (%@)", stringFromError(result)]];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
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
            [skin logError:[NSString stringWithFormat:@"ERROR: Unable to set systemSleep assertion property (%@)", stringFromError(result)]];
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

/// hs.caffeinate.declareUserActivity([id])
/// Function
/// Informs the OS that the user performed some activity
///
/// Parameters:
///  * id - An option number containing the assertion ID returned by a previous call of this function
///
/// Returns:
///  * A number containing the ID of the assertion generated by this function
///
/// Notes:
///  * This is intended to simulate user activity, for example to prevent displays from sleeping, or to wake them up
///  * It is not mandatory to re-use assertion IDs if you are calling this function mulitple times, but it is recommended that you do so if the calls are related
static int caffeinate_declareUserActivity(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK]; // The LS_TNIL is so people can call foo = hs.caffeinate.declareUserActivity(foo) and not have it error out the first time

    IOPMAssertionID assertionID = kIOPMNullAssertionID;

    if (lua_type(L, 1) == LUA_TNUMBER) {
        assertionID = (uint32)lua_tointeger(L, 1);
    }
    IOPMAssertionDeclareUserActivity(CFSTR("hs.caffeinate.declareUserActivity()"), kIOPMUserActiveLocal, &assertionID);

    lua_pushinteger(L, (int)assertionID);
    return 1;
}

/// hs.caffeinate.lockScreen()
/// Function
/// Locks the displays
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * This function uses private Apple APIs and could therefore stop working in any given release of macOS without warning.
static int caffeinate_lockScreen(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    // Load the private API we need to call SACLockScreenImmediate()
    if (!loginFramework) {
        NSString *bundlePath = @"/System/Library/PrivateFrameworks/login.framework";
        NSURL *bundleURL = [NSURL fileURLWithPath:bundlePath];
        loginFramework = CFBundleCreate(kCFAllocatorDefault, (CFURLRef)bundleURL);
    }

    SACLockScreenImmediatePtr SACLockScreenImmediate;
    SACLockScreenImmediate = (SACLockScreenImmediatePtr)CFBundleGetFunctionPointerForName(loginFramework, (__bridge CFStringRef)@"SACLockScreenImmediate");
    if (!SACLockScreenImmediate) {
        [skin logError:@"Unable to load SACLockScreenImmediate from private login.framework"];
    } else {
        SACLockScreenImmediate();
    }

    return 0;
}

/// hs.caffeinate.sessionProperties()
/// Function
/// Fetches information from the display server about the current session
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing information about the current session, or nil if an error occurred
///
/// Notes:
///  * The keys in this dictionary will vary based on the current state of the system (e.g. local vs VNC login, screen locked vs unlocked).
static int caffeinate_sessionProperties(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    CFDictionaryRef ref = CGSessionCopyCurrentDictionary();

    [skin pushNSObject:(__bridge NSDictionary *)ref];

    CFRelease(ref);

    return 1;
}

/// hs.caffeinate.currentAssertions()
/// Function
/// Fetches information about processes which are currently asserting display/power sleep restrictions
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing information about current power assertions, with process IDs (PID) as the keys, each of which may contain multiple assertions
static int caffeinate_currentAssertions(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    CFDictionaryRef assertions = NULL;
    IOReturn result = IOPMCopyAssertionsByProcess(&assertions);
    if (result != kIOReturnSuccess) {
        [skin pushNSObject:@{}];
        return 1;
    }

    [skin pushNSObject:(__bridge id)assertions];
    CFRelease(assertions);

    return 1;
}

// ----------------------- Lua/hs glue GAR ---------------------

static int caffeinate_gc(lua_State *L) {
    // TODO: We should register which of the assertions we have active, somewhere that persists a reload()
    caffeinate_allowIdleDisplaySleep(L);
    caffeinate_allowIdleSystemSleep(L);
    caffeinate_allowSystemSleep(L);

    if (loginFramework) {
        CFRelease(loginFramework);
        loginFramework = NULL ;
    }

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

    {"declareUserActivity", caffeinate_declareUserActivity},
    {"lockScreen", caffeinate_lockScreen},

    {"sessionProperties", caffeinate_sessionProperties},

    {"currentAssertions", caffeinate_currentAssertions},

    {NULL, NULL}
};

static const luaL_Reg metalib[] = {
    {"__gc", caffeinate_gc},

    {NULL, NULL}
};

/* NOTE: The substring "hs_caffeinate_internal" in the following function's name
         must match the require-path of this file, i.e. "hs.caffeinate.internal". */

int luaopen_hs_libcaffeinate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibrary:"hs.caffeinate" functions:caffeinatelib metaFunctions:metalib];

    return 1;
}
