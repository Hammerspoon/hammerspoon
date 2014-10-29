#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>
#import <CoreLocation/CoreLocation.h>

@interface HSLocation : NSObject<CLLocationManagerDelegate>
@property (strong, atomic) CLLocationManager* manager;
@end

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

static HSLocation *location;

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

        CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
        if (status != kCLAuthorizationStatusAuthorized) {
            switch (status) {
                case kCLAuthorizationStatusNotDetermined:
                    NSLog(@"Not Determined");
                    break;
                case kCLAuthorizationStatusRestricted:
                    NSLog(@"Restricted");
                    break;
                case kCLAuthorizationStatusDenied:
                    NSLog(@"Denied");
                    break;
                default:
                    NSLog(@"Shrug");
                    break;
            }
            NSLog(@"WARNING: hs.location not yet authorized to use Location Services");
        }
    }
    return true;
}

static int location_start_watching(lua_State* L) {
    if (!manager_create()) {
        lua_pushboolean(L, 0);
        return 1;
    }
    [location.manager startUpdatingLocation];
    lua_pushboolean(L, 1);
    return 1;
}

static int location_stop_watching(lua_State* L) {
    [location.manager stopUpdatingLocation];
    location = nil;
    return 0;
}

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
