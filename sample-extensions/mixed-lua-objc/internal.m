#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>

// Inline documentation should be indicated with a three-slash comment
/// hs.foobar.addnumbers() -> int
/// Method
/// Takes two supplied numbers, adds them together and returns the result
static int foobar_addnumbers(lua_State* L) {
    int a = luaL_checknumber(L, 1);
    int b = luaL_checknumber(L, 2);
    lua_pushnumber(L, a + b);
    return 1;
}

static int numbers_gc(lua_State* L) {
    /* Do any cleanup required when the extension is unloaded */
    return 0;
}

/* You must supply a manual mapping of your API. For each Objective-C function
 * you wish to expose to users, you should add a row here in the form:
 * {"lua_function_name", objc_function_name},
 */
static const luaL_Reg foobarlib[] = {
    {"addnumbers", foobar_addnumbers},

    {} // This must end with an empty struct
};

/* If your module keeps hold of resources, you should add another mapping struct
 * that adds a "__gc" lua function. This will be called when your extension is
 * unloaded, allowing you to release the resources you are holding and avoid
 * any leaking */
static const luaL_Reg metalib[] = {
    {"__gc", numbers_gc},

    {} // This must end with an empty struct
};

/* NOTE: The substring "hs_foobar_internal" in the following function's name
         must match the require-path of this file, i.e. "hs.foobar.internal". */

int luaopen_hs_foobar_internal(lua_State* L) {
    luaL_newlib(L, foobarlib);

    /* These two lines are only required if you have added a "__gc" mapping */
    luaL_newlib(L, metalib);
    lua_setmetatable(L, -2);

    return 1;
}
