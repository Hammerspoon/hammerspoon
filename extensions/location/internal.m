@import Cocoa ;
@import LuaSkin ;
@import CoreLocation ;

@class HSLocation ;

static const char *USERDATA_TAG   = "hs.location" ;
static const char *GEOCODE_UD_TAG = "hs.location.geocode" ;
static int        refTable        = LUA_NOREF;
static int        callbackRef     = LUA_NOREF ;
static HSLocation *location ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSLocation : NSObject <CLLocationManagerDelegate>
@property CLLocationManager *manager ;
@end


@implementation HSLocation

- (instancetype)init {
    self = [super init] ;
    if (self) {
        _manager = [[CLLocationManager alloc] init];
        _manager.purpose = @"Hammerspoon location extension";
        _manager.delegate = self ;
    }
    return self;
}

// Since monitored regions persist, and we don't currently support region changes starting
// Hammerspoon, it seems cleanest/safest to clear them when we go away for now.  While the
// meta_gc function *should* do this, we include this in case it gets missed for some reason
// hopefully this will kick in when the object goes out of scope.
- (void)dealloc {
    if (_manager) {
        _manager.delegate = nil ;
        [_manager stopUpdatingLocation] ;
        for (CLRegion *region in [_manager monitoredRegions]) {
            [_manager stopMonitoringForRegion:region] ;
        }
        _manager = nil ;
    }
}

- (void)locationManager:(__unused CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    if (callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin *skin = [LuaSkin shared] ;
            _lua_stackguard_entry(skin.L);
            [skin pushLuaRef:refTable ref:callbackRef] ;
            [skin pushNSObject:self] ;
            [skin pushNSObject:@"didUpdateLocations"] ;
            [skin pushNSObject:locations] ;
            [skin protectedCallAndError:@"hs.location:didUpdateLocations callback" nargs:3 nresults:0];
            _lua_stackguard_exit(skin.L);
        }) ;
    }
}

- (void)locationManager:(__unused CLLocationManager *)manager didEnterRegion:(CLRegion *)region {
    if (callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin *skin = [LuaSkin shared] ;
            _lua_stackguard_entry(skin.L);
            [skin pushLuaRef:refTable ref:callbackRef] ;
            [skin pushNSObject:self] ;
            [skin pushNSObject:@"didEnterRegion"] ;
            [skin pushNSObject:region] ;
            [skin protectedCallAndError:@"hs.location:didEnterRegion callback" nargs:3 nresults:0];
            _lua_stackguard_exit(skin.L);
        }) ;
    }
}

- (void)locationManager:(__unused CLLocationManager *)manager didExitRegion:(CLRegion *)region {
    if (callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin *skin = [LuaSkin shared] ;
            _lua_stackguard_entry(skin.L);
            [skin pushLuaRef:refTable ref:callbackRef] ;
            [skin pushNSObject:self] ;
            [skin pushNSObject:@"didExitRegion"] ;
            [skin pushNSObject:region] ;
            [skin protectedCallAndError:@"hs.location:didExitRegion callback" nargs:3 nresults:0];
            _lua_stackguard_exit(skin.L);
        }) ;
    }
}

- (void)locationManager:(__unused CLLocationManager *)manager didFailWithError:(NSError *)error {
    if (callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin *skin = [LuaSkin shared] ;
            _lua_stackguard_entry(skin.L);
            [skin pushLuaRef:refTable ref:callbackRef] ;
            [skin pushNSObject:self] ;
            [skin pushNSObject:@"didFailWithError"] ;
            [skin pushNSObject:error.localizedDescription] ;
            [skin protectedCallAndError:@"hs.location:didFailWithError callback" nargs:3 nresults:0];
            _lua_stackguard_exit(skin.L);
        }) ;
    }
}

- (void)locationManager:(__unused CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region
                                                                      withError:(NSError *)error {
    if (callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin *skin = [LuaSkin shared] ;
            _lua_stackguard_entry(skin.L);
            [skin pushLuaRef:refTable ref:callbackRef] ;
            [skin pushNSObject:self] ;
            [skin pushNSObject:@"monitoringDidFailForRegion"] ;
            [skin pushNSObject:region] ;
            [skin pushNSObject:error.localizedDescription] ;
            [skin protectedCallAndError:@"hs.location:monitoringDidFailForRegion callback" nargs:4 nresults:0];
            _lua_stackguard_exit(skin.L);
        }) ;
    }
}

- (void)locationManager:(__unused CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin *skin = [LuaSkin shared] ;
            _lua_stackguard_entry(skin.L);
            [skin pushLuaRef:refTable ref:callbackRef] ;
            [skin pushNSObject:self] ;
            [skin pushNSObject:@"didChangeAuthorizationStatus"] ;

// according to the CLLocationManager.h file, kCLAuthorizationStatusAuthorizedWhenInUse is
// forbidden in OS X, but Clang still complains about it not being listed in the switch...
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wswitch-enum"
            switch(status) {
                case kCLAuthorizationStatusNotDetermined:    [skin pushNSObject:@"undefined"] ; break ;
                case kCLAuthorizationStatusRestricted:       [skin pushNSObject:@"restricted"] ; break ;
                case kCLAuthorizationStatusDenied:           [skin pushNSObject:@"denied"] ; break ;
                case kCLAuthorizationStatusAuthorized: [skin pushNSObject:@"authorized"] ; break ;
                default:
                    [skin pushNSObject:[NSString stringWithFormat:@"unrecognized CLAuthorizationStatus: %d, notify developers", status]] ;
                    break ;
            }
#pragma clang diagnostic pop

            [skin protectedCallAndError:@"hs.location:didChangeAuthorizationStatus callback" nargs:3 nresults:0];
            _lua_stackguard_exit(skin.L);
        }) ;
    }
}

- (void)locationManager:(__unused CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    if (callbackRef != LUA_NOREF) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LuaSkin *skin = [LuaSkin shared] ;
            _lua_stackguard_entry(skin.L);
            [skin pushLuaRef:refTable ref:callbackRef] ;
            [skin pushNSObject:self] ;
            [skin pushNSObject:@"didStartMonitoringForRegion"] ;
            [skin pushNSObject:region] ;
            [skin protectedCallAndError:@"hs.location:didStartMonitoringForRegion" nargs:3 nresults:0];
            _lua_stackguard_exit(skin.L);
        }) ;
    }
}

@end

static BOOL checkLocationManager() {
    if (!location) {
        location = [[HSLocation alloc] init] ;
    }
    return location ? [CLLocationManager locationServicesEnabled] : NO ;
}

#pragma mark - Module Functions

// internally used function
static int location_registerCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    callbackRef = [skin luaUnref:refTable ref:callbackRef] ;
    if (lua_type(L, 1) == LUA_TFUNCTION) {
        lua_pushvalue(L, 1) ;
        callbackRef = [skin luaRef:refTable] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.location.servicesEnabled() -> bool
/// Function
/// Gets the state of OS X Location Services
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if Location Services are enabled, otherwise false
static int location_locationServicesEnabled(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;
    lua_pushboolean(L, [CLLocationManager locationServicesEnabled]) ;
    return 1 ;
}

/// hs.location.authorizationStatus() -> string
/// Function
/// Returns a string describing the authorization status of Hammerspoon's use of Location Services.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string matching one of the following:
///    * "undefined"  - The user has not yet made a choice regarding whether Hammerspoon can use location services.
///    * "restricted" - Hammerspoon is not authorized to use location services. The user cannot change this status, possibly due to active restrictions such as parental controls being in place.
///    * "denied"     - The user explicitly denied the use of location services for Hammerspoon or location services are currently disabled in System Preferences.
///    * "authorized" - Hammerspoon is authorized to use location services.
///
/// Notes:
///  * The first time you use a function which requires Location Services, you will be prompted to grant Hammerspoon access. If you wish to change this permission after the initial prompt, you may do so from the Location Services section of the Security & Privacy section in the System Preferences application.
static int location_authorizationStatus(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;

// according to the CLLocationManager.h file, kCLAuthorizationStatusAuthorizedWhenInUse is
// forbidden in OS X, but Clang still complains about it not being listed in the switch...
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wswitch-enum"
    switch([CLLocationManager authorizationStatus]) {
        case kCLAuthorizationStatusNotDetermined:    [skin pushNSObject:@"undefined"] ; break ;
        case kCLAuthorizationStatusRestricted:       [skin pushNSObject:@"restricted"] ; break ;
        case kCLAuthorizationStatusDenied:           [skin pushNSObject:@"denied"] ; break ;
        case kCLAuthorizationStatusAuthorized: [skin pushNSObject:@"authorized"] ; break ;
        default:
            [skin pushNSObject:[NSString stringWithFormat:@"unrecognized CLAuthorizationStatus: %d, notify developers", [CLLocationManager authorizationStatus]]] ;
            break ;
    }
#pragma clang diagnostic pop

    return 1 ;
}

/// hs.location.distance(from, to) -> meters
/// Function
/// Measures the distance between two points of latitude and longitude
///
/// Parameters:
///  * `from` - A locationTable as described in the module header
///  * `to`   - A locationTable as described in the module header
///
/// Returns:
///  * A number containing the distance between `from` and `to` in meters. The measurement is made by tracing a line that follows an idealised curvature of the earth
///
/// Notes:
///  * This function does not require Location Services to be enabled for Hammerspoon.
static int location_distanceBetween(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE, LS_TTABLE, LS_TBREAK] ;
    CLLocation *pointA = [skin luaObjectAtIndex:1 toClass:"CLLocation"] ;
    CLLocation *pointB = [skin luaObjectAtIndex:2 toClass:"CLLocation"] ;
    lua_pushnumber(L, [pointA distanceFromLocation:pointB]) ;
    return 1;
}

// internally used function
static int location_startWatching(lua_State* L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;
    lua_pushboolean(L, checkLocationManager()) ;
    if (lua_toboolean(L, -1)) [location.manager startUpdatingLocation];
    return 1;
}

// internally used function
static int location_stopWatching(lua_State* L __unused) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;
    if (location) [location.manager stopUpdatingLocation];
    return 0;
}

/// hs.location.get() -> locationTable or nil
/// Function
/// Returns a table representing the current location
///
/// Parameters:
///  * None
///
/// Returns:
///  * If successful, a locationTable as described in the module header, otherwise nil.
///
/// Notes:
///  * This function activates Location Services for Hammerspoon, so the first time you call this, you may be prompted to authorise Hammerspoon to use Location Services.
///  * If access to Location Services is enabled for Hammerspoon, this function will return the most recent cached data for the computer's location.
///    * Internally, the Location Services cache is updated whenever additional WiFi networks are detected or lost (not necessarily joined). When update tracking is enabled with the [hs.location.start](#start) function, calculations based upon the RSSI of all currently seen networks are preformed more often to provide a more precise fix, but it's still based on the WiFi networks near you.
static int location_getLocation(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TBREAK] ;
    if (checkLocationManager()) {
        [skin pushNSObject:location.manager.location] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.location.dstOffset() -> number
/// Function
/// Returns a number giving the current daylight savings time offset
///
/// Parameters:
///  * None
///
/// Returns:
///  * The number of minutes of daylight savings offset, zero if there is no offset
///
/// Notes:
///  * This value is derived from the currently configured system timezone, it does not use Location Services
static int location_dstOffset(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TBREAK];

    NSTimeZone *tz = [NSTimeZone localTimeZone];
    NSTimeInterval interval = 0;
    if (tz.daylightSavingTime) {
        interval = tz.daylightSavingTimeOffset;
    }

    lua_pushnumber(skin.L, interval);
    return 1;
}

// internally used function
static int location_monitoredRegions(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    if (location) {
        [skin pushNSObject:location.manager.monitoredRegions] ;
    } else {
// reserve nil for when we actually try to create manager and can't
//         lua_pushnil(L) ;
        lua_newtable(L) ;
    }
    return 1 ;
}

// internally used function
static int location_addMonitoredRegion(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE, LS_TBREAK] ;
    CLCircularRegion  *region  = [skin luaObjectAtIndex:1 toClass:"CLCircularRegion"] ;
    if (region) {
        if (checkLocationManager()) {
            [location.manager startMonitoringForRegion:region] ;
            lua_pushboolean(L, YES) ;
        } else {
            lua_pushnil(L) ;
        }
    } else {
        return NO ;
    }
    return 1 ;
}

// internally used function
static int location_removeMonitoredRegion(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    NSString          *identifier = [skin toNSObjectAtIndex:1] ;
    CLCircularRegion  *targetRegion ;

    if (location) {
        for (CLCircularRegion *region in location.manager.monitoredRegions) {
            if ([identifier isEqualToString:region.identifier]) {
                targetRegion = region ;
                break ;
            }
        }
        if (targetRegion) {
            [location.manager stopMonitoringForRegion:targetRegion] ;
            lua_pushboolean(L, YES) ;
        } else {
            lua_pushboolean(L, NO) ;
        }
    } else {
// reserve nil for when we actually try to create manager and can't
//         lua_pushnil(L) ;
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

// internally used function, may document for testing purposes
static int location_fakeLocationChange(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK | LS_TVARARG] ;
    NSString *message = [skin toNSObjectAtIndex:1] ;
    if (location) {
        if ([message isEqualToString:@"didUpdateLocations"]) {
            [skin checkArgs:LS_TSTRING, LS_TTABLE, LS_TBREAK] ;
            CLLocation *loc = [skin luaObjectAtIndex:2 toClass:"CLLocation"] ;
            [location locationManager:location.manager didUpdateLocations:[NSArray arrayWithObject:loc]] ;
        } else if ([message isEqualToString:@"didEnterRegion"]) {
            [skin checkArgs:LS_TSTRING, LS_TTABLE, LS_TBREAK] ;
            CLCircularRegion *region = [skin luaObjectAtIndex:2 toClass:"CLCircularRegion"] ;
            [location locationManager:location.manager didEnterRegion:region] ;
        } else if ([message isEqualToString:@"didExitRegion"]) {
            [skin checkArgs:LS_TSTRING, LS_TTABLE, LS_TBREAK] ;
            CLCircularRegion *region = [skin luaObjectAtIndex:2 toClass:"CLCircularRegion"] ;
            [location locationManager:location.manager didExitRegion:region] ;
        } else if ([message isEqualToString:@"didFailWithError"]) {
            [skin checkArgs:LS_TSTRING, LS_TNUMBER, LS_TBREAK] ;
            NSError *error = [NSError errorWithDomain:@"fakeError" code:lua_tointeger(L, 2) userInfo:nil] ;
            [location locationManager:location.manager didFailWithError:error] ;
        } else if ([message isEqualToString:@"monitoringDidFailForRegion"]) {
            [skin checkArgs:LS_TSTRING, LS_TTABLE, LS_TNUMBER, LS_TBREAK] ;
            CLCircularRegion *region = [skin luaObjectAtIndex:2 toClass:"CLCircularRegion"] ;
            NSError *error = [NSError errorWithDomain:@"fakeError" code:lua_tointeger(L, 3) userInfo:nil] ;
            [location locationManager:location.manager monitoringDidFailForRegion:region withError:error] ;
        } else if ([message isEqualToString:@"didChangeAuthorizationStatus"]) {
            [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TBREAK] ;
            NSString *status = [skin toNSObjectAtIndex:2] ;
            CLAuthorizationStatus statusCode ;
            if ([status isEqualToString:@"undefined"]) {
                statusCode = kCLAuthorizationStatusNotDetermined ;
            } else if ([status isEqualToString:@"restricted"]) {
                statusCode = kCLAuthorizationStatusRestricted ;
            } else if ([status isEqualToString:@"denied"]) {
                statusCode = kCLAuthorizationStatusDenied ;
            } else if ([status isEqualToString:@"authorized"]) {
                statusCode = kCLAuthorizationStatusAuthorized ;
            } else {
                return luaL_argerror(L, 2, [[NSString stringWithFormat:@"%@ is not a recognized status", status] UTF8String]) ;
            }
            [location locationManager:location.manager didChangeAuthorizationStatus:statusCode] ;
        } else if ([message isEqualToString:@"didStartMonitoringForRegion"]) {
            [skin checkArgs:LS_TSTRING, LS_TTABLE, LS_TBREAK] ;
            CLCircularRegion *region = [skin luaObjectAtIndex:2 toClass:"CLCircularRegion"] ;
            [location locationManager:location.manager didStartMonitoringForRegion:region] ;
        } else {
            return luaL_argerror(L, 1, [[NSString stringWithFormat:@"%@ is not a recognized message", message] UTF8String]) ;
        }
        lua_pushboolean(L, YES) ;
    } else {
// reserve nil for when we actually try to create manager and can't
//         lua_pushnil(L) ;
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

#pragma mark - Geocoder Functions

/// hs.location.geocoder.lookupLocation(locationTable, fn) -> geocoderObject
/// Constructor
/// Look up geocoding information for the specified location.
///
/// Parameters:
///  * `locationTable` - a locationTable as described in the `hs.location` header specifying a location to obtain geocoding information about.
///  * `fn`            - A callback function which should expect 2 arguments and return none:
///    * `state`  - a boolean indicating whether or not geocoding data was provided
///    * `result` - if `state` is true indicating that geocoding was successful, this argument will be a table containing one or more placemarkTables (as described in the module header) containing the geocoding data available for the location.  If `state` is false, this argument will be a string containing an error message describing the problem encountered.
///
/// Returns:
///  * a geocodingObject
///
/// Notes:
///  * This constructor requires internet access and the callback will be invoked with an error message if the internet is not currently accessible.
///  * This constructor does not require Location Services to be enabled for Hammerspoon.
static int clgeocoder_lookupLocation(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TTABLE, LS_TFUNCTION, LS_TBREAK] ;
    CLLocation *theLocation = [skin luaObjectAtIndex:1 toClass:"CLLocation"] ;
    lua_pushvalue(L, 2) ;
    int fnRef = [skin luaRef:refTable] ;

    CLGeocoder *geoItem = [[CLGeocoder alloc] init] ;
    [geoItem reverseGeocodeLocation:theLocation completionHandler:^(NSArray *placemark, NSError *error) {
        LuaSkin   *_skin = [LuaSkin shared] ;
//         if (error) [_skin logInfo:[NSString stringWithFormat:@"%s:lookupLocation completion error:%@", GEOCODE_UD_TAG, error.localizedDescription]] ;
        lua_State *_L    = [_skin L] ;
        [_skin pushLuaRef:refTable ref:fnRef] ;
        lua_pushboolean(_L, (error == NULL)) ;
        [_skin pushNSObject:(error ? error.localizedDescription : placemark)] ;
        [_skin protectedCallAndError:@"hs.location.geocode:lookupLocation callback" nargs:2 nresults:0];
        [_skin luaUnref:refTable ref:fnRef] ;
    }] ;
    [skin pushNSObject:geoItem] ;
    return 1 ;
}

/// hs.location.geocoder.lookupAddress(address, fn) -> geocoderObject
/// Constructor
/// Look up geocoding information for the specified address.
///
/// Parameters:
///  * `address` - a string containing address information as commonly expressed in your locale.
///  * `fn`      - A callback function which should expect 2 arguments and return none:
///    * `state`  - a boolean indicating whether or not geocoding data was provided
///    * `result` - if `state` is true indicating that geocoding was successful, this argument will be a table containing one or more placemarkTables (as described in the module header) containing the geocoding data available for the location.  If `state` is false, this argument will be a string containing an error message describing the problem encountered.
///
/// Returns:
///  * a geocodingObject
///
/// Notes:
///  * This constructor requires internet access and the callback will be invoked with an error message if the internet is not currently accessible.
///  * This constructor does not require Location Services to be enabled for Hammerspoon.
static int clgeocoder_lookupAddress(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TFUNCTION, LS_TBREAK] ;
    NSString *searchString = [skin toNSObjectAtIndex:1] ;
    lua_pushvalue(L, 2) ;
    int fnRef = [skin luaRef:refTable] ;

    CLGeocoder *geoItem = [[CLGeocoder alloc] init] ;
    [geoItem geocodeAddressString:searchString completionHandler:^(NSArray *placemark, NSError *error) {
        LuaSkin   *_skin = [LuaSkin shared] ;
//         if (error) [_skin logInfo:[NSString stringWithFormat:@"%s:lookupAddress completion error:%@", GEOCODE_UD_TAG, error.localizedDescription]] ;
        lua_State *_L    = [_skin L] ;
        [_skin pushLuaRef:refTable ref:fnRef] ;
        lua_pushboolean(_L, (error == NULL)) ;
        [_skin pushNSObject:(error ? error.localizedDescription : placemark)] ;
        [_skin protectedCallAndError:@"hs.location.geocode:lookupAddress callback" nargs:2 nresults:0];
        [_skin luaUnref:refTable ref:fnRef] ;
    }] ;
    [skin pushNSObject:geoItem] ;
    return 1 ;
}

/// hs.location.geocoder.lookupAddressNear(address, [regionTable], fn) -> geocoderObject
/// Constructor
/// Look up geocoding information for the specified address.
///
/// Parameters:
///  * `address`     - a string containing address information as commonly expressed in your locale.
///  * `regionTable` - an optional regionTable as described in the `hs.location` header used to prioritize the order of the results found.  If this parameter is not provided and Location Services is enabled for Hammerspoon, a region containing current location is used.
///  * `fn`          - A callback function which should expect 2 arguments and return none:
///    * `state`  - a boolean indicating whether or not geocoding data was provided
///    * `result` - if `state` is true indicating that geocoding was successful, this argument will be a table containing one or more placemarkTables (as described in the module header) containing the geocoding data available for the location.  If `state` is false, this argument will be a string containing an error message describing the problem encountered.
///
/// Returns:
///  * a geocodingObject
///
/// Notes:
///  * This constructor requires internet access and the callback will be invoked with an error message if the internet is not currently accessible.
///  * This constructor does not require Location Services to be enabled for Hammerspoon.
///  * While a partial address can be given, the more information you provide, the more likely the results will be useful.  The `regionTable` only determines sort order if multiple entries are returned, it does not constrain the search.
static int clgeocoder_lookupAddressNear(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK | LS_TVARARG] ;
    NSString *searchString = [skin toNSObjectAtIndex:1] ;
    CLCircularRegion *theRegion = nil ;
    if (lua_gettop(L) == 2) {
        [skin checkArgs:LS_TSTRING, LS_TFUNCTION, LS_TBREAK] ;
        lua_pushvalue(L, 2) ;
    } else {
        [skin checkArgs:LS_TSTRING, LS_TTABLE, LS_TFUNCTION, LS_TBREAK] ;
        theRegion = [skin luaObjectAtIndex:2 toClass:"CLCircularRegion"] ;
        lua_pushvalue(L, 3) ;
    }
    int fnRef = [skin luaRef:refTable] ;

    CLGeocoder *geoItem = [[CLGeocoder alloc] init] ;
    [geoItem geocodeAddressString:searchString inRegion:theRegion completionHandler:^(NSArray *placemark, NSError *error) {
        LuaSkin   *_skin = [LuaSkin shared] ;
//         if (error) [_skin logInfo:[NSString stringWithFormat:@"%s:lookupAddressNear completion error:%@", GEOCODE_UD_TAG, error.localizedDescription]] ;
        lua_State *_L    = [_skin L] ;
        [_skin pushLuaRef:refTable ref:fnRef] ;
        lua_pushboolean(_L, (error == NULL)) ;
        [_skin pushNSObject:(error ? error.localizedDescription : placemark)] ;
        [_skin protectedCallAndError:@"hs.location.geocode:lookupAddressNear callback" nargs:2 nresults:0];
        [_skin luaUnref:refTable ref:fnRef] ;
    }] ;
    [skin pushNSObject:geoItem] ;
    return 1 ;
}

#pragma mark - Geocoder Methods

/// hs.location.geocoder:geocoding() -> boolean
/// Method
/// Returns a boolean indicating whether or not the geocoding process is still active.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean indicating if the geocoding process is still active.  If false, then the callback function either has already been called or will be as soon as the main thread of Hammerspoon becomes idle again.
static int clgeocoder_isGeocoding(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, GEOCODE_UD_TAG, LS_TBREAK] ;
    CLGeocoder *geoItem = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, geoItem.geocoding) ;
    return 1 ;
}

/// hs.location.geocoder:cancel() -> nil
/// Method
/// Cancels the pending or in progress geocoding request.
///
/// Parameters:
///  * None
///
/// Returns:
///  * nil to facilitate garbage collection by assigning this result to the geocodeObject
///
/// Notes:
///  * This method has no effect if the geocoding process has already completed.
static int clgeocoder_cancelGeocoding(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TUSERDATA, GEOCODE_UD_TAG, LS_TBREAK] ;
    CLGeocoder *geoItem = [skin toNSObjectAtIndex:1] ;
    [geoItem cancelGeocode] ;
    lua_pushnil(L) ; // allow this method to be used in assignment
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushCLGeocoder(lua_State *L, id obj) {
    CLGeocoder *value = obj ;
    void** valuePtr = lua_newuserdata(L, sizeof(CLGeocoder *)) ;
    *valuePtr = (__bridge_retained void *)value ;
    luaL_getmetatable(L, GEOCODE_UD_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

id toCLGeocoderFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    CLGeocoder *value ;
    if (luaL_testudata(L, idx, GEOCODE_UD_TAG)) {
        value = get_objectFromUserdata(__bridge CLGeocoder, L, idx, GEOCODE_UD_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", GEOCODE_UD_TAG, lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

static int pushCLLocation(lua_State *L, id obj) {
//     LuaSkin *skin = [LuaSkin shared] ;
    CLLocation *loc = obj ;
    lua_newtable(L) ;
    lua_pushnumber(L, loc.coordinate.latitude) ;               lua_setfield(L, -2, "latitude") ;
    lua_pushnumber(L, loc.coordinate.longitude) ;              lua_setfield(L, -2, "longitude") ;
    lua_pushnumber(L, loc.altitude) ;                          lua_setfield(L, -2, "altitude") ;
    lua_pushnumber(L, loc.horizontalAccuracy) ;                lua_setfield(L, -2, "horizontalAccuracy") ;
    lua_pushnumber(L, loc.verticalAccuracy) ;                  lua_setfield(L, -2, "verticalAccuracy") ;
    lua_pushnumber(L, loc.course) ;                            lua_setfield(L, -2, "course") ;
    lua_pushnumber(L, loc.speed) ;                             lua_setfield(L, -2, "speed") ;
//     [skin pushNSObject:loc.description] ;         lua_setfield(L, -2, "description") ;
    lua_pushnumber(L, [loc.timestamp timeIntervalSince1970]) ; lua_setfield(L, -2, "timestamp") ;
    lua_pushstring(L, "CLLocation") ;                          lua_setfield(L, -2, "__luaSkinType") ;
    return 1 ;
}

static int pushCLCircularRegion(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    CLCircularRegion *theRegion = obj ;
    lua_newtable(L) ;
    [skin pushNSObject:theRegion.identifier] ;      lua_setfield(L, -2, "identifier") ;
    lua_pushnumber(L, theRegion.center.latitude) ;  lua_setfield(L, -2, "latitude") ;
    lua_pushnumber(L, theRegion.center.longitude) ; lua_setfield(L, -2, "longitude") ;
    lua_pushnumber(L, theRegion.radius) ;           lua_setfield(L, -2, "radius") ;
    lua_pushboolean(L, theRegion.notifyOnEntry) ;   lua_setfield(L, -2, "notifyOnEntry") ;
    lua_pushboolean(L, theRegion.notifyOnExit) ;    lua_setfield(L, -2, "notifyOnExit") ;
    return 1 ;
}

static id CLLocationFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    CLLocation *theLocation ;

    if (lua_type(L, idx) == LUA_TTABLE) {
        CLLocationCoordinate2D loc        = { 0.0, 0.0 } ;
        CLLocationDistance     altitude   =  0.0 ;
        CLLocationAccuracy     hAccuracy  =  0.0 ;
        CLLocationAccuracy     vAccuracy  = -1.0 ; // invalid unless explicitly specified
        CLLocationDirection    course     = -1.0 ; // invalid unless explicitly specified
        CLLocationSpeed        speed      = -1.0 ; // invalid unless explicitly specified
        NSDate                 *timestamp = [NSDate date] ;

        if (lua_getfield(L, idx, "latitude") == LUA_TNUMBER)           loc.latitude = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "longitude") == LUA_TNUMBER)          loc.longitude = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "altitude") == LUA_TNUMBER)           altitude = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "horizontalAccuracy") == LUA_TNUMBER) hAccuracy = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "verticalAccuracy") == LUA_TNUMBER)   vAccuracy = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "course") == LUA_TNUMBER)             course = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "speed") == LUA_TNUMBER)              speed = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "timestamp") == LUA_TNUMBER)
            timestamp = [NSDate dateWithTimeIntervalSince1970:lua_tonumber(L, -1)] ;
        lua_pop(L, 8) ;

        theLocation = [[CLLocation alloc] initWithCoordinate:loc
                                                    altitude:altitude
                                          horizontalAccuracy:hAccuracy
                                            verticalAccuracy:vAccuracy
                                                      course:course
                                                       speed:speed
                                                   timestamp:timestamp] ;
    } else {
        [skin logError:[NSString stringWithFormat:@"%s:CLLocationFromLua expected table, found %s", USERDATA_TAG, lua_typename(L, lua_type(L, idx))]] ;
    }

    return theLocation ;
}

static id CLCircularRegionFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
    CLCircularRegion *theRegion ;

    if (lua_type(L, idx) == LUA_TTABLE) {
        CLLocationCoordinate2D theCenter  = { 0.0, 0.0 } ;
        CLLocationDistance     theRadius = 0.0 ;
        NSString               *theIdentifier = [[NSUUID UUID] UUIDString] ;

        if (lua_getfield(L, idx, "longitude") == LUA_TNUMBER)  theCenter.longitude = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "latitude") == LUA_TNUMBER)   theCenter.latitude = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "radius") == LUA_TNUMBER)     theRadius = lua_tonumber(L, -1) ;
        if (lua_getfield(L, idx, "identifier") == LUA_TSTRING) theIdentifier = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 4) ;

        theRegion = [[CLCircularRegion alloc] initWithCenter:theCenter
                                                      radius:theRadius
                                                  identifier:theIdentifier] ;

        if (lua_getfield(L, idx, "notifyOnEntry") == LUA_TBOOLEAN) theRegion.notifyOnEntry = (BOOL)lua_toboolean(L, -1) ;
        if (lua_getfield(L, idx, "notifyOnExit") == LUA_TBOOLEAN)  theRegion.notifyOnExit = (BOOL)lua_toboolean(L, -1) ;
        lua_pop(L, 2) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"%s:CLCircularRegionFromLua expected table, found %s", USERDATA_TAG, lua_typename(L, lua_type(L, idx))]] ;
    }
    return theRegion ;
}

static int pushCLPlacemark(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    CLPlacemark *thePlace = obj ;
    lua_newtable(L) ;
      [skin pushNSObject:[thePlace location]] ;                 lua_setfield(L, -2, "location") ;
      [skin pushNSObject:[thePlace name]] ;                     lua_setfield(L, -2, "name") ;
      [skin pushNSObject:[thePlace addressDictionary]] ;        lua_setfield(L, -2, "addressDictionary") ;
      [skin pushNSObject:[thePlace ISOcountryCode]] ;           lua_setfield(L, -2, "countryCode") ;
      [skin pushNSObject:[thePlace country]] ;                  lua_setfield(L, -2, "country") ;
      [skin pushNSObject:[thePlace postalCode]] ;               lua_setfield(L, -2, "postalCode") ;
      [skin pushNSObject:[thePlace administrativeArea]] ;       lua_setfield(L, -2, "administrativeArea") ;
      [skin pushNSObject:[thePlace subAdministrativeArea]] ;    lua_setfield(L, -2, "subAdministrativeArea") ;
      [skin pushNSObject:[thePlace locality]] ;                 lua_setfield(L, -2, "locality") ;
      [skin pushNSObject:[thePlace subLocality]] ;              lua_setfield(L, -2, "subLocality") ;
      [skin pushNSObject:[thePlace thoroughfare]] ;             lua_setfield(L, -2, "thoroughfare") ;
      [skin pushNSObject:[thePlace subThoroughfare]] ;          lua_setfield(L, -2, "subThoroughfare") ;
      [skin pushNSObject:[thePlace region]] ;                   lua_setfield(L, -2, "region") ;
      // timezone added in OS X 10.11
      if ([thePlace respondsToSelector:@selector(timeZone)]) {
          [skin pushNSObject:[[thePlace performSelector:@selector(timeZone)] abbreviation]] ;
          lua_setfield(L, -2, "timeZone") ;
      }
      [skin pushNSObject:[thePlace inlandWater]] ;              lua_setfield(L, -2, "inlandWater") ;
      [skin pushNSObject:[thePlace ocean]] ;                    lua_setfield(L, -2, "ocean") ;
      [skin pushNSObject:[thePlace areasOfInterest]] ;          lua_setfield(L, -2, "areasOfInterest") ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int clgeocoder_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    CLGeocoder *obj = [skin luaObjectAtIndex:1 toClass:"CLGeocoder"] ;
    NSString *title = obj.geocoding ? @"geocoding" : @"idle" ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", GEOCODE_UD_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int clgeocoder_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, GEOCODE_UD_TAG) && luaL_testudata(L, 2, GEOCODE_UD_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        CLGeocoder *obj1 = [skin luaObjectAtIndex:1 toClass:"CLGeocoder"] ;
        CLGeocoder *obj2 = [skin luaObjectAtIndex:2 toClass:"CLGeocoder"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int clgeocoder_gc(lua_State* L) {
    CLGeocoder *obj = get_objectFromUserdata(__bridge_transfer CLGeocoder, L, 1, GEOCODE_UD_TAG) ;
    if (obj) {
        [obj cancelGeocode] ;
        obj = nil ;
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* __unused L) {
    // make sure we don't get a last-minute callback during teardown
    callbackRef = [[LuaSkin shared] luaUnref:refTable ref:callbackRef] ;
    if (location) {
        if (location.manager) {
            location.manager.delegate = nil ;
            [location.manager stopUpdatingLocation] ;
            for (CLRegion *region in [location.manager monitoredRegions]) {
                [location.manager stopMonitoringForRegion:region] ;
            }
            location.manager = nil ;
        }
        location = nil ;
    }
    return 0 ;
}

static const luaL_Reg clgeocode_moduleLib[] = {
    {"lookupAddress",     clgeocoder_lookupAddress},
    {"lookupLocation",    clgeocoder_lookupLocation},
    {"lookupAddressNear", clgeocoder_lookupAddressNear},
    {NULL,                NULL}
};

// Metatable for userdata objects
static const luaL_Reg clgeocoder_metaLib[] = {
    {"geocoding",  clgeocoder_isGeocoding},
    {"cancel",     clgeocoder_cancelGeocoding},

    {"__tostring", clgeocoder_tostring},
    {"__eq",       clgeocoder_eq},
    {"__gc",       clgeocoder_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"servicesEnabled",        location_locationServicesEnabled},
    {"authorizationStatus",    location_authorizationStatus},
    {"distance",               location_distanceBetween},
    {"start",                  location_startWatching},
    {"stop",                   location_stopWatching},
    {"get",                    location_getLocation},
    {"dstOffset",              location_dstOffset},

    {"_registerCallback",      location_registerCallback},
    {"_monitoredRegions",      location_monitoredRegions},
    {"_addMonitoredRegion",    location_addMonitoredRegion},
    {"_removeMonitoredRegion", location_removeMonitoredRegion},
    {"_fakeLocationChange",    location_fakeLocationChange},

    {NULL,                     NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs_location_internal(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;

    // in case a reload skipped meta_gc for some reason (e.g. module got resurrected right
    // before gc_finalize), kick off the object's dealloc method
    if (location) location = nil ;

    refTable = [skin registerLibrary:moduleLib metaFunctions:module_metaLib] ;

    [skin registerPushNSHelper:pushCLLocation             forClass:"CLLocation"] ;
    [skin registerLuaObjectHelper:CLLocationFromLua       forClass:"CLLocation"
                                                  withTableMapping:"CLLocation"] ;

    [skin registerPushNSHelper:pushCLCircularRegion       forClass:"CLCircularRegion"] ;
    [skin registerLuaObjectHelper:CLCircularRegionFromLua forClass:"CLCircularRegion"
                                                  withTableMapping:"CLCircularRegion"] ;

    // hs.location.geocoder submodule

    luaL_newlib(L, clgeocode_moduleLib) ; lua_setfield(L, -2, "geocoder") ;
    [skin registerObject:GEOCODE_UD_TAG objectFunctions:clgeocoder_metaLib] ;

    [skin registerPushNSHelper:pushCLGeocoder             forClass:"CLGeocoder"];
    [skin registerLuaObjectHelper:toCLGeocoderFromLua     forClass:"CLGeocoder"
                                               withUserdataMapping:GEOCODE_UD_TAG];

    [skin registerPushNSHelper:pushCLPlacemark            forClass:"CLPlacemark"] ;

    return 1;
}
