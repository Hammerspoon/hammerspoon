#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>
#import <pthread.h>

// ----------------------- API Implementation ---------------------

/// hs.crash.crash()
/// Function
/// Causes Hammerspoon to immediately crash.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * This is for testing purposes only, you are extremely unlikely to need this in normal Hammerspoon usage
static int burnTheWorld(lua_State *L __unused) {
    int *x = NULL; *x = 42;
    return 0;
}

extern pthread_t mainthreadid;

/// hs.crash.isMainThread() -> bool
/// Function
/// Tells you whether you are executing Lua on the main thread.
///
/// Notes:
/// * This is for testing purposes only, you are extremely unlikely to need this in normal Hammerspoon usage
/// * When developing a new extension, especially one that involves handlers for outside events, this function
///   can be used to make sure your event handling happens on the main thread. You can use this Lua code
///   to make Hammerspoon abort if anything happens on a different thread:
///   ```lua
///   local function crashifnotmain(reason)
///     print("crashifnotmain called with reason", reason) -- may want to remove this, very verbose otherwise
///     if not hs.crash.isMainThread() then
///       print("not in main thread, crashing")
///       hs.crash.crash()
///     end
///   end
///
///   debug.sethook(crashifnotmain, 'c')
///   ```

static int isMainThread(lua_State *L)
{
    pthread_t id = pthread_self();

    lua_pushboolean(L, pthread_equal(mainthreadid, id));
    return 1;
}

// ----------------------- Lua/hs glue GAR ---------------------

static const luaL_Reg crashlib[] = {
    {"crash", burnTheWorld},
    {"isMainThread", isMainThread},

    {}
};

/* NOTE: The substring "hs_crash_internal" in the following function's name
         must match the require-path of this file, i.e. "hs.crash.internal". */

int luaopen_hs_crash_internal(lua_State *L) {
    // Table for luaopen
    luaL_newlib(L, crashlib);

    return 1;
}
