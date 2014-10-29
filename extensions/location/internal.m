#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>
#import <CoreLocation/CoreLocation.h>

@interface HSLocation : NSObject<CLLocationManagerDelegate>
@property CLLocationManager* manager;
@end

@implementation HSLocation 
@end

static HSLocation *location;

void manager_create() {
    if (!location) {
        HSLocation *location = [[HSLocation alloc] init];
    }
}

static int location_start_watching(lua_State* L) {
    manager_create();
    [location.manager startUpdatingLocation];
    return 0;
}

static int location_stop_watching(lua_State* L) {
    [location.manager stopUpdatingLocation];
    return 0;
}

// ----------------------- Lua/hs glue GAR ---------------------

static int location_gc(lua_State *L) {
    [location.manager stopUpdatingLocation];
    [location dealloc];

    return 0;
}

static const luaL_Reg locationlib[] = {
    {"start_watching", location_start_watching},
    {"stop_watching", location_stop_watching},
    {}
};

static const luaL_Reg metalib[] = {
    {"__gc", location_gc},

    {}
};

/* NOTE: The substring "hs_location_internal" in the following function's name
         must match the require-path of this file, i.e. "hs.location.internal". */

int luaopen_hs_location_internal(lua_State *L) {
    luaL_newlib(L, locationlib);
    luaL_newlib(L, metalib);
    lua_setmetatable(L, -2);

    return 1;
}
