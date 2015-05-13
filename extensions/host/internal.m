#import <Cocoa/Cocoa.h>
#import <lauxlib.h>
#import "../hammerspoon.h"

static NSHost *host;

/// hs.host.addresses() -> table
/// Function
/// Gets a list of network addresses for the current machine
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table of strings containing the network addresses of the current machine
///
/// Notes:
///  * The results will include IPv4 and IPv6 addresses
static int hostAddresses(lua_State* L) {
    NSArray *addresses = [host addresses];
    if (!addresses) {
        lua_pushnil(L);
        return 1;
    }

    lua_newtable(L);
    int i = 1;
    for (NSString *address in addresses) {
        lua_pushnumber(L, i++);
        lua_pushstring(L, [address UTF8String]);
        lua_settable(L, -3);
    }

    return 1;
}

/// hs.host.names() -> table
/// Function
/// Gets a list of network names for the current machine
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table of strings containing the network names of the current machine
///
/// Notes:
///  * This function should be used sparingly, as it may involve blocking network access to resolve hostnames
static int hostNames(lua_State* L) {
    NSArray *names = [host names];
    if (!names) {
        lua_pushnil(L);
        return 1;
    }

    lua_newtable(L);
    int i = 1;
    for (NSString *name in names) {
        lua_pushnumber(L, i++);
        lua_pushstring(L, [name UTF8String]);
        lua_settable(L, -3);
    }

    return 1;
}

/// hs.host.localizedName() -> string
/// Function
/// Gets the name of the current machine, as displayed in the Finder sidebar
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the name of the current machine
static int hostLocalizedName(lua_State* L) {
    lua_pushstring(L, [[host localizedName] UTF8String]);
    return 1;
}

static const luaL_Reg hostlib[] = {
    {"addresses", hostAddresses},
    {"names", hostNames},
    {"localizedName", hostLocalizedName},

    {}
};

int luaopen_hs_host_internal(lua_State* L) {
    host = [NSHost currentHost];
    luaL_newlib(L, hostlib);

    return 1;
}
