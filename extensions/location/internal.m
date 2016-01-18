#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import <CoreLocation/CoreLocation.h>

@interface HSLocation : NSObject<CLLocationManagerDelegate>
@property (strong, atomic) CLLocationManager* manager;
@end

static HSLocation *location;
static NSMutableIndexSet *locationHandlers;

@implementation HSLocation

- (id)initWithLua:(lua_State* ) L {
    if (self = [super init]) {
        self.manager = [[CLLocationManager alloc] init];
    }
    return self;
}

- (void)locationManager:(CLLocationManager *)__unused manager didUpdateLocations:(NSArray *)__unused locations {
//    NSLog(@"hs.location:didUpdateLocations %@", [[locations lastObject] description]);
    LuaSkin *skin = [LuaSkin shared];
    lua_State *L = skin.L;

    lua_getglobal(L, "hs");
    lua_getfield(L, -1, "location"); lua_remove(L, -2);
    lua_getfield(L, -1, "__dispatch"); lua_remove(L, -2);

    if (![skin protectedCallAndTraceback:0 nresults:0]) {
        const char *errorMsg = lua_tostring(L, -1);
        [skin logError:[NSString stringWithFormat:@"hs.location.register() callback error: %s", errorMsg]];
    }

    return;
}

- (void)locationManager:(CLLocationManager *)__unused manager didFailWithError:(NSError *)error {
    LuaSkin *skin = [LuaSkin shared];
    [skin logBreadcrumb:[NSString stringWithFormat:@"hs.location didFailWithError: %@", error]];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    LuaSkin *skin = [LuaSkin shared];
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
    [skin logBreadcrumb:[NSString stringWithFormat:@"hs.location didChangeAuthorizationStatus authorization %@", msg]];
}

@end

BOOL manager_create(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    if (!location) {
        location = [[HSLocation alloc] initWithLua: L];
        location.manager.purpose = @"Hammerspoon location extension";
        [location.manager setDelegate:location];

        if (![CLLocationManager locationServicesEnabled]) {
            [skin logError:@"hs.location: Location Services are disabled by the OS. Check your settings"];
            return false;
        }

        CLAuthorizationStatus status __unused = [CLLocationManager authorizationStatus];
    }
    return true;
}

/// hs.location.start() -> boolean
/// Function
/// Begins location monitoring using OS X's Location Services
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the operation succeeded, otherwise false
///
/// Notes:
///  * The first time you call this, you may be prompted to authorise Hammerspoon to use Location Services.
static int location_start_watching(lua_State* L) {
    if (!manager_create(L)) {
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
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int location_stop_watching(lua_State* L __unused) {
    [location.manager stopUpdatingLocation];
    location = nil;
    return 0;
}

/// hs.location.get() -> table or nil
/// Function
/// Returns a table representing the current location
///
/// Parameters:
///  * None
///
/// Returns:
///  * If successful, a table, otherwise nil. The table contains the following keys:
///   * latitude - A number containing the latitude in degrees. Positive values indicate latitudes north of the equator. Negative values indicate latitudes south of the equator
///   * longitude - A number containing the longitude in degrees. Measurements are relative to the zero meridian, with positive values extending east of the meridian and negative values extending west of the meridian
///   * altitude - A number containing the altitude measured in meters
///   * timestamp - A number containing the time at which this location was determined, in seconds from the first instant of 1 January 1970, GMT
///   * horizontalAccuracy - A number containing the radius of uncertainty for the location, measured in meters
///   * verticalAccuracy - A number containing the distance of uncertainty for the altitude, measured in meters
///
/// Notes:
///  * There is a small lag between calling hs.location.start() and this function returning useful data, and it may never return data if the user has denied access to Location Services.
///  * Rather than poll this function in a loop, consider using hs.timer.doAfter() to continue your work after a reasonable delay.
static int location_get_location(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    CLLocation *current = [location.manager location];
    if (!current) {
        [skin logBreadcrumb:@"hs.location.get(): No data yet, returning nil"];
        lua_pushnil(L);
        return 1;
    }

    [skin logBreadcrumb:[NSString stringWithFormat:@"hs.location.get(): %@", current.description]];
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

/// hs.location.distance(from, to) -> meters
/// Function
/// Measures the distance between two points of latitude and longitude
///
/// Parameters:
///  * from - A table with the following keys:
///   * latitude - A number representing degrees latitude
///   * longitude - A number representing degrees longitude
///  * to - A table containing the same keys as the `from` parameter
///
/// Returns:
///  * A number containing the distance between `from` and `to` in meters. The measurement is made by tracing a line that follows an idealised curvature of the earth
static int location_distance(lua_State* L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    luaL_checktype(L, 2, LUA_TTABLE);
    lua_getfield(L, 1, "latitude"); CLLocationDegrees latitude1 = lua_tonumber(L, -1) ; lua_pop(L, 1);
    lua_getfield(L, 1, "longitude"); CLLocationDegrees longitude1 = lua_tonumber(L, -1) ; lua_pop(L, 1);
    lua_getfield(L, 2, "latitude"); CLLocationDegrees latitude2 = lua_tonumber(L, -1) ; lua_pop(L, 1);
    lua_getfield(L, 2, "longitude"); CLLocationDegrees longitude2 = lua_tonumber(L, -1) ; lua_pop(L, 1);
    CLLocation* location1 = [[CLLocation alloc] initWithLatitude:latitude1 longitude:longitude1] ;
    CLLocation* location2 = [[CLLocation alloc] initWithLatitude:latitude2 longitude:longitude2] ;
    lua_pushnumber(L, [location1 distanceFromLocation:location2]) ;

    return 1;
}

/// hs.location.services_enabled() -> bool
/// Function
/// Gets the state of OS X Location Services
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if Location Services are enabled, otherwise false
static int location_is_enabled(lua_State *L) {
    BOOL enabled = [CLLocationManager locationServicesEnabled];
    lua_pushboolean(L, enabled);
    return 1;
}

// ----------------------- Lua/hs glue GAR ---------------------

static int location_gc(lua_State *L __unused) {
    [location.manager stopUpdatingLocation];
    location = nil;
    return 0;
}

static const luaL_Reg locationlib[] = {
    {"start", location_start_watching},
    {"stop", location_stop_watching},
    {"get", location_get_location},
    {"services_enabled", location_is_enabled},
    {"distance", location_distance},
    {NULL, NULL}
};

static const luaL_Reg metalib[] = {
    {"__gc", location_gc},

    {NULL, NULL}
};

/* NOTE: The substring "hs_location_internal" in the following function's name
         must match the require-path of this file, i.e. "hs.location.internal". */

int luaopen_hs_location_internal(lua_State *L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    [skin registerLibrary:locationlib metaFunctions:metalib];

    return 1;
}

