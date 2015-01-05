#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>
#import <pthread.h>

// ----------------------- API Implementation ---------------------

/// hs.crash.crash()
/// Method
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
