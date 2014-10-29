#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>
#import <CoreLocation/CoreLocation.h>

@interface HSLocation : NSObject<CLLocationManagerDelegate>
@property (strong, atomic) CLLocationManager* manager;
@end

static HSLocation *location;
static NSMutableIndexSet *locationHandlers;

@implementation HSLocation

- (id)init {
    if ([super init]) {
        self.manager = [[CLLocationManager alloc] init];
    }
    return self;
}

- (void)locationManager:(CLLocationManager *)__unused manager didUpdateLocations:(NSArray *)__unused locations {
//    NSLog(@"hs.location:didUpdateLocations %@", [[locations lastObject] description]);
    return;
}

- (void)locationManager:(CLLocationManager *)__unused manager didFailWithError:(NSError *)error {
        NSLog(@"hs.location didFailWithError: %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    NSString *msg;
    switch (status) {
        case kCLAuthorizationStatusAuthorized:
            msg = @"allowed";
            [manager startUpdatingLocation];
            break;
        case kCLAuthorizationStatusNotDetermined:
            // This seems to help with getting authorized
            [manager startUpdatingLocation];
            [manager stopUpdatingLocation];
            msg = @"not yet determined";
            break;
        case kCLAuthorizationStatusRestricted:
            msg = @"restricted";
            break;
        case kCLAuthorizationStatusDenied:
            msg = @"denied by user";
            // FIXME: Do something useful here, definitely pop an error up into lua console
            break;
        default:
            msg = @"state unknown";
            break;
    }
    NSLog(@"hs.location didChangeAuthorizationStatus authorization %@", msg);
}

@end

BOOL manager_create() {
    if (!location) {
        location = [[HSLocation alloc] init];
        location.manager.purpose = @"Hammerspoon location extension";
        [location.manager setDelegate:location];

        if (![CLLocationManager locationServicesEnabled]) {
            // FIXME: pop this up into the Lua console stack
            NSLog(@"ERROR: Location Services are disabled");
            return false;
        }

        CLAuthorizationStatus status __unused = [CLLocationManager authorizationStatus];
    }
    return true;
}

/// hs.location.start() -> boolean
/// Function
/// Begins location monitoring using OS X's Location Services.
/// The first time you call this, you may be prompted to authorise Hammerspoon to use Location Services.
static int location_start_watching(lua_State* L) {
    if (!manager_create()) {
        lua_pushboolean(L, 0);
        return 1;
    }
    [location.manager startUpdatingLocation];
    lua_pushboolean(L, 1);
    return 1;
}

/// hs.location.stop()
/// Function
/// Stops location monitoring
static int location_stop_watching(lua_State* L) {
    [location.manager stopUpdatingLocation];
    location = nil;
    return 0;
}

/// hs.location.get() -> table or nil
/// Function
/// Returns a table representing the current location, with the keys:
///  latitude - The latitude in degrees. Positive values indicate latitudes north of the equator. Negative values indicate latitudes south of the equator
///  longitude - The longitude in degrees. Measurements are relative to the zero meridian, with positive values extending east of the meridian and negative values extending west of the meridian
///  altitude - The altitude measured in meters
///  timestamp - The time at which this location was determined, in seconds from the first instant of 1 January 1970, GMT
///  horizontalAccuracy - The radius of uncertainty for the location, measured in meters
///  verticalAccuracy - The accuracy of the altitude value in meters
///
/// Note that there is a small lag between calling hs.location.start() and this function returning useful data, and it may never return data if the user has denied access to Location Services.
/// Rather than poll this function in a loop, consider using hs.timer.doafter() to continue your work after a reasonable delay.
static int location_get_location(lua_State* L) {
    CLLocation *current = [location.manager location];
    if (!current) {
        NSLog(@"hs.location.get(): No data yet, returning nil");
        lua_pushnil(L);
        return 1;
    }

    NSLog(@"hs.location.get(): %@", current.description);
    lua_newtable(L);

    lua_pushstring(L, "latitude");
    lua_pushnumber(L, current.coordinate.latitude);
    lua_settable(L, -3);

    lua_pushstring(L, "longitude");
    lua_pushnumber(L, current.coordinate.longitude);
    lua_settable(L, -3);

    lua_pushstring(L, "altitude");
    lua_pushnumber(L, current.altitude);
    lua_settable(L, -3);

    lua_pushstring(L, "timestamp");
    lua_pushnumber(L, current.timestamp.timeIntervalSince1970);
    lua_settable(L, -3);

    lua_pushstring(L, "horizontalAccuracy");
    lua_pushnumber(L, current.horizontalAccuracy);
    lua_settable(L, -3);

    lua_pushstring(L, "verticalAccuracy");
    lua_pushnumber(L, current.verticalAccuracy);
    lua_settable(L, -3);

    return 1;
}

/// hs.location.services_enabled() -> bool
/// Function
/// Returns true or false if OS X Location Services are enabled
static int location_is_enabled(lua_State *L) {
    BOOL enabled = [CLLocationManager locationServicesEnabled];
    lua_pushboolean(L, enabled);
    return 1;
}

// ----------------------- Lua/hs glue GAR ---------------------

static int location_gc(lua_State *L) {
    [location.manager stopUpdatingLocation];

    return 0;
}

static const luaL_Reg locationlib[] = {
    {"start", location_start_watching},
    {"stop", location_stop_watching},
    {"get", location_get_location},
    {"services_enabled", location_is_enabled},
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
