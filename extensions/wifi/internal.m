#import <Cocoa/Cocoa.h>
#import <CoreWLAN/CoreWLAN.h>
#import <CoreWLAN/CWWiFiClient.h>
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG "hs.wifi"
#define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))

static int refTable = LUA_NOREF;
static int logFnRef = LUA_NOREF;

#pragma mark - Testing out better logging with hs.logger

#define _cERROR   "ef"
#define _cWARN    "wf"
#define _cINFO    "f"
#define _cDEBUG   "df"
#define _cVERBOSE "vf"

// allow this to be potentially unused in the module
static int __unused log_to_console(lua_State *L, const char *level, NSString *theMessage) {
    LuaSkin *skin = [LuaSkin shared];
    lua_Debug functionDebugObject, callerDebugObject;
    int status = lua_getstack(L, 0, &functionDebugObject);
    status = status + lua_getstack(L, 1, &callerDebugObject);
    NSString *fullMessage = nil ;
    if (status == 2) {
        lua_getinfo(L, "n", &functionDebugObject);
        lua_getinfo(L, "Sl", &callerDebugObject);
        fullMessage = [NSString stringWithFormat:@"%s - %@ (%d:%s)", functionDebugObject.name,
                                                                     theMessage,
                                                                     callerDebugObject.currentline,
                                                                     callerDebugObject.short_src];
    } else {
        fullMessage = [NSString stringWithFormat:@"%s callback - %@", USERDATA_TAG,
                                                                      theMessage];
    }
    // Put it into the system logs, may help with troubleshooting
    [skin logBreadcrumb:[NSString stringWithFormat:@"hs.wifi: %@", fullMessage]];

    // If hs.logger reference set, use it and the level will indicate whether the user sees it or not
    // otherwise we print to the console for everything, just in case we forget to register.
    if (logFnRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:logFnRef];
        lua_getfield(L, -1, level); lua_remove(L, -2);
    } else {
        lua_getglobal(L, "print");
    }

    lua_pushstring(L, [fullMessage UTF8String]);
    if (![[LuaSkin shared] protectedCallAndTraceback:1 nresults:0]) { return lua_error(L); }
    return 0;
}

static int lua_registerLogForC(__unused lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TTABLE, LS_TBREAK];
    logFnRef = [[LuaSkin shared] luaRef:refTable];
    return 0;
}

#pragma mark - Support Functions

CWInterface *get_wifi_interface(NSString *theInterface) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        return (theInterface) ? [CWInterface interfaceWithName:theInterface] : [CWInterface interface] ;
#pragma clang diagnostic pop
}

@interface HSWifiScan : NSObject
@property int fnRef ;
@property BOOL isDone ;
@end

#pragma mark - HSWifiScan Definition

@implementation HSWifiScan

- (id)initWithCallback:(int)fnReference onInterface:(NSString *)interface {
    self = [super init] ;
    if (self) {
        _fnRef = fnReference ;
        _isDone = NO ;
        [self performSelectorInBackground:@selector(doBackgroundScan:) withObject:interface];
    }
    return self ;
}

- (void)doBackgroundScan:(id)object {
    NSString *theInterface = (NSString *)object ;

    NSError *theError = nil ;
    CWInterface *interface = get_wifi_interface(theInterface);
    NSSet *availableNetworks = [interface scanForNetworksWithName:nil error:&theError];
    _isDone = YES ;
    if (theError) {
        [self performSelectorOnMainThread:@selector(invokeCallback:)
                           withObject:theError
                        waitUntilDone:NO];
    } else {
        [self performSelectorOnMainThread:@selector(invokeCallback:)
                           withObject:availableNetworks
                        waitUntilDone:NO];
    }
}

- (void)invokeCallback:(id)object {
    if (_fnRef != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin shared] ;
        lua_State *L = [skin L] ;
        [[LuaSkin shared] pushLuaRef:refTable ref:_fnRef];
        if ([object isKindOfClass:[NSError class]]) {
            log_to_console(L, _cINFO, [(NSError *)object localizedDescription]) ;
            [skin pushNSObject:[(NSError *)object localizedDescription]] ;
        } else {
            [skin pushNSObject:(NSSet *)object] ;
        }

        if (![skin protectedCallAndTraceback:1 nresults:0]) {
            log_to_console(L, _cERROR, [skin toNSObjectAtIndex:-1]) ;
            lua_pop(L, 1) ;
        }
    }
}

@end

#pragma mark - Module Functions

/// hs.wifi.setPower(state, [interface]) -> boolean
/// Function
/// Turns a wifi interface on or off
///
/// Parameters:
///  * state - a boolean value indicating if the Wifi device should be powered on (true) or off (false).
///  * interface - an optional interface name as listed in the results of [hs.wifi.interfaces](#interfaces).  If not present, the interface defaults to the systems default WLAN device.
///
/// Returns:
///  * True if the power change was successful, or false and an error string if an error occurred attempting to set the power state.  Returns nil if there is a problem attaching to the interface.
static int setPower(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBOOLEAN, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    BOOL powerState = (BOOL)lua_toboolean(L, 1) ;
    NSString *theName = nil ;
    if (lua_gettop(L) == 2)
        theName = [NSString stringWithUTF8String:luaL_checkstring(L, 2)] ;

    CWInterface *interface = get_wifi_interface(theName);
    if (interface) {
        NSError *theError = nil ;
        if ([interface setPower:powerState error:&theError]) {
            lua_pushboolean(L, YES) ;
        } else {
            lua_pushboolean(L, NO) ;
            lua_pushstring(L, [[theError localizedDescription] UTF8String]) ;
            return 2 ;
        }
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.wifi.disassociate([interface]) -> nil
/// Function
/// Disconnect the interface from its current network.
///
/// Parameters:
///  * interface - an optional interface name as listed in the results of [hs.wifi.interfaces](#interfaces).  If not present, the interface defaults to the systems default WLAN device.
///
/// Returns:
///  * None
static int disassociate(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *theName = nil ;
    if (lua_gettop(L) == 1)
        theName = [NSString stringWithUTF8String:luaL_checkstring(L, 1)] ;

    CWInterface *interface = get_wifi_interface(theName);
    [interface disassociate] ;
    return 0 ;
}

/// hs.wifi.interfaces() -> table
/// Function
/// Returns a list of interface names for WLAN devices attached to the system
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table containing the names of all WLAN interfaces for this system.
///
/// Notes:
///  * For most systems, this will be one interface, but the result is still returned as an array.
static int wifi_interfaces(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [skin pushNSObject:[CWInterface interfaceNames]] ;
#pragma clang diagnostic pop
    return 1 ;
}

/// hs.wifi.availableNetworks([interface]) -> table
/// Function
/// Gets a list of available WiFi networks
///
/// Parameters:
///  * interface - an optional interface name as listed in the results of [hs.wifi.interfaces](#interfaces).  If not present, the interface defaults to the systems default WLAN device.
///
/// Returns:
///  * A table containing the names of all visible WiFi networks
///
/// Notes:
///  * WARNING: This function will block all Lua execution until the scan has completed. It's probably not very sensible to use this function very much, if at all.
static int wifi_scan(lua_State* L __unused) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *theName = nil ;
    if (lua_gettop(L) == 1)
        theName = [NSString stringWithUTF8String:luaL_checkstring(L, 1)] ;

    CWInterface *interface = get_wifi_interface(theName);
    NSSet *availableNetworks = [interface scanForNetworksWithName:nil error:nil];
    if (!availableNetworks) {
        lua_pushnil(L);
        return 1;
    }

    lua_newtable(L);
    int i = 1;
    for (CWNetwork *network in [availableNetworks allObjects]) {
        lua_pushinteger(L, i++);
        lua_pushstring(L, [[network ssid] UTF8String]);
        lua_settable(L, -3);
    }

    return 1;
}

/// hs.wifi.backgroundScan(fn, [interface]) -> scanObject
/// Constructor
/// Perform a scan for available wifi networks in the background (non-blocking)
///
/// Parameters:
///  * fn        - the function to callback when the scan is completed.
///  * interface - an optional interface name as listed in the results of [hs.wifi.interfaces](#interfaces).  If not present, the interface defaults to the systems default WLAN device.
///
/// Returns:
///  * returns a scan object
///
/// Notes:
///  * If you pass in nil as the callback function, the scan occurs but no callback function is called.  This can be useful to update the `cachedScanResults` entry returned by [hs.wifi.interfaceDetails](#interfaceDetails).
///
/// * The callback function should expect one argument which will be a table if the scan was successful or a string containing an error message if it was not.  The table will be an array of available networks.  Each entry in the array will be a table containing the following keys:
///    * beaconInterval         - The beacon interval (ms) for the network.
///    * bssid                  - The basic service set identifier (BSSID) for the network.
///    * countryCode            - The country code (ISO/IEC 3166-1:1997) for the network.
///    * ibss                   - Whether or not the network is an IBSS (ad-hoc) network.
///    * informationElementData - Information element data included in beacon or probe response frames.
///    * noise                  - The aggregate noise measurement (dBm) for the network.
///    * PHYModes               - A table containing the PHY Modes supported by the network.
///    * rssi                   - The aggregate received signal strength indication (RSSI) measurement (dBm) for the network.
///    * security               - A table containing the security types supported by the network.
///    * ssid                   - The service set identifier (SSID) for the network, encoded as a string.
///    * ssidData               - The service set identifier (SSID) for the network, returned as data (1-32 octets).
///    * wlanChannel            - A table containing details about the channel the network is on. The table will contain the following keys:
///      * band   - The channel band.
///      * number - The channel number.
///      * width  - The channel width.
static int wifi_scan_background(lua_State* L __unused) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TFUNCTION | LS_TNIL, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;

    int callbackRef = LUA_NOREF ;
    if (lua_type(L, 1) != LUA_TNIL) {
        lua_pushvalue(L, 1);
        callbackRef = [skin luaRef:refTable];
    }

    NSString *theName = nil ;
    if (lua_gettop(L) == 2)
        theName = [NSString stringWithUTF8String:luaL_checkstring(L, 2)] ;

    HSWifiScan *scanner = [[HSWifiScan alloc] initWithCallback:callbackRef onInterface:theName];
    void** scannerPtr = lua_newuserdata(L, sizeof(HSWifiScan *));
    *scannerPtr = (__bridge_retained void *)scanner;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1;
}

/// hs.wifi.currentNetwork([interface]) -> string or nil
/// Function
/// Gets the name of the current WiFi network
///
/// Parameters:
///  * interface - an optional interface name as listed in the results of [hs.wifi.interfaces](#interfaces).  If not present, the interface defaults to the systems default WLAN device.
///
/// Returns:
///  * A string containing the SSID of the WiFi network currently joined, or nil if no there is no WiFi connection
static int wifi_current_ssid(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *theName = nil ;
    if (lua_gettop(L) == 1)
        theName = [NSString stringWithUTF8String:luaL_checkstring(L, 1)] ;

    CWInterface *interface = get_wifi_interface(theName);
    if (interface) {
        lua_pushstring(L, [[interface ssid] UTF8String]);
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.wifi.interfaceDetails([interface]) -> table
/// Function
/// Returns a table containing details about the wireless interface.
///
/// Parameters:
///  * interface - an optional interface name as listed in the results of [hs.wifi.interfaces](#interfaces).  If not present, the interface defaults to the systems default WLAN device.
///
/// Returns:
///  * A table containing details about the interface.  The table will contain the following keys:
///    * active            - The interface has its corresponding network service enabled.
///    * activePHYMode     - The current active PHY mode for the interface.
///    * bssid             - The current basic service set identifier (BSSID) for the interface.
///    * cachedScanResults - A table containing the networks currently in the scan cache for the WLAN interface.  See [hs.wifi.backgroundScan](#backgroundScan) for details on the table format.
///    * configuration     - A table containing the current configuration for the given WLAN interface.  This table will contain the following keys:
///      * networkProfiles                    - A table containing an array of known networks for the interface.  Entries in the array will each contain the following keys:
///        * ssid     - The service set identifier (SSID) for the network profile.
///        * ssidData - The service set identifier (SSID) for the network, returned as data (1-32 octets).
///        * security - The security mode for the network profile.
///      * rememberJoinedNetworks             - A boolean flag indicating whether or not the AirPort client will remember all joined networks.
///      * requireAdministratorForAssociation - A boolean flag indicating whether or not changing the wireless network requires an Administrator password.
///      * requireAdministratorForIBSSMode    - A boolean flag indicating whether or not creating an IBSS (Ad Hoc) network requires an Administrator password.
///      * requireAdministratorForPower       - A boolean flag indicating whether or not changing the wireless power state requires an Administrator password.
///    * countryCode       - The current country code (ISO/IEC 3166-1:1997) for the interface.
///    * hardwareAddress   - The hardware media access control (MAC) address for the interface.
///    * interface         - The BSD name of the interface.
///    * interfaceMode     - The current mode for the interface.
///    * noise             - The current aggregate noise measurement (dBm) for the interface.
///    * power             - Whether or not the interface is currently powered on.
///    * rssi              - The current aggregate received signal strength indication (RSSI) measurement (dBm) for the interface.
///    * security          - The current security mode for the interface.
///    * ssid              - The current service set identifier (SSID) for the interface.
///    * ssidData          - The service set identifier (SSID) for the interface, returned as data (1-32 octets).
///    * supportedChannels - An array of channels supported by the interface for the active country code.  The array will contain entries with the following keys:
///      * band   - The channel band.
///      * number - The channel number.
///      * width  - The channel width.
///    * transmitPower     - The current transmit power (mW) for the interface. Returns 0 in the case of an error.
///    * transmitRate      - The current transmit rate (Mbps) for the interface.
///    * wlanChannel       - A table containing details about the channel the interface is on. The table will contain the following keys:
///      * band   - The channel band.
///      * number - The channel number.
///      * width  - The channel width.
static int interfaceDetails(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *theName = nil ;
    if (lua_gettop(L) == 1)
        theName = [NSString stringWithUTF8String:luaL_checkstring(L, 1)] ;

    CWInterface *interface = get_wifi_interface(theName);
    if (interface) {
        [skin pushNSObject:interface] ;
    } else {
        lua_pushnil(L);
    }

    return 1;
}

#pragma mark - Module Object Methods

/// hs.wifi:isDone() -> boolean
/// Method
/// Returns whether or not a scan object has completed its scan for wireless networks.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean value indicating whether or not the scan has been completed.
///
/// Notes:
///  * This will be set whether or not an actual callback function was invoked.  This method can be checked to see if the cached data for the `cachedScanResults` entry returned by [hs.wifi.interfaceDetails](#interfaceDetails) has been updated.
static int backgroundScanIsDone(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWifiScan *scanner = get_objectFromUserdata(__bridge HSWifiScan, L, 1);
    lua_pushboolean(L, scanner.isDone) ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions

static int pushCWInterface(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    CWInterface *theInterface = (CWInterface *)obj ;
    lua_newtable(L) ;

    [skin pushNSObject:[theInterface wlanChannel]] ;           lua_setfield(L, -2, "wlanChannel") ;
    lua_pushnumber(L, [theInterface transmitRate]) ;           lua_setfield(L, -2, "transmitRate") ;
    lua_pushinteger(L, [theInterface transmitPower]) ;         lua_setfield(L, -2, "transmitPower") ;
    [skin pushNSObject:[theInterface supportedWLANChannels]] ; lua_setfield(L, -2, "supportedChannels") ;
    [skin pushNSObject:[theInterface ssidData]] ;              lua_setfield(L, -2, "ssidData") ;
    [skin pushNSObject:[theInterface ssid]] ;                  lua_setfield(L, -2, "ssid") ;
    lua_pushboolean(L, [theInterface serviceActive]) ;         lua_setfield(L, -2, "active") ;
    switch([theInterface security]) {
        case kCWSecurityNone:               lua_pushstring(L, "None") ; break ;
        case kCWSecurityWEP:                lua_pushstring(L, "WEP") ; break ;
        case kCWSecurityWPAPersonal:        lua_pushstring(L, "WPA Personal") ; break ;
        case kCWSecurityWPAPersonalMixed:   lua_pushstring(L, "WPA Personal Mixed") ; break ;
        case kCWSecurityWPA2Personal:       lua_pushstring(L, "WPA2 Personal") ; break ;
        case kCWSecurityPersonal:           lua_pushstring(L, "Personal") ; break ;
        case kCWSecurityDynamicWEP:         lua_pushstring(L, "Dynamic WEP") ; break ;
        case kCWSecurityWPAEnterprise:      lua_pushstring(L, "WPA Enterprise") ; break ;
        case kCWSecurityWPAEnterpriseMixed: lua_pushstring(L, "WPA Enterprise Mixed") ; break ;
        case kCWSecurityWPA2Enterprise:     lua_pushstring(L, "WPA2 Enterprise") ; break ;
        case kCWSecurityEnterprise:         lua_pushstring(L, "Enterprise") ; break ;
        default:                            lua_pushstring(L, [[NSString stringWithFormat:@"unrecognized (%ld)", [theInterface security]] UTF8String]) ; break ;
    }
    lua_setfield(L, -2, "security") ;
    lua_pushinteger(L, [theInterface rssiValue]) ;             lua_setfield(L, -2, "rssi") ;
    lua_pushboolean(L, [theInterface powerOn]) ;               lua_setfield(L, -2, "power") ;
    lua_pushinteger(L, [theInterface noiseMeasurement]) ;      lua_setfield(L, -2, "noise") ;
    [skin pushNSObject:[theInterface interfaceName]] ;         lua_setfield(L, -2, "interface") ;
    switch([theInterface interfaceMode]) {
        case kCWInterfaceModeNone:    lua_pushstring(L, "None") ; break ;
        case kCWInterfaceModeStation: lua_pushstring(L, "Station") ; break ;
        case kCWInterfaceModeIBSS:    lua_pushstring(L, "IBSS") ; break ;
        case kCWInterfaceModeHostAP:  lua_pushstring(L, "Host AP") ; break ;
        default:                      lua_pushstring(L, [[NSString stringWithFormat:@"unrecognized (%ld)", [theInterface interfaceMode]] UTF8String]) ; break ;
    }
    lua_setfield(L, -2, "interfaceMode") ;
    [skin pushNSObject:[theInterface hardwareAddress]] ;       lua_setfield(L, -2, "hardwareAddress") ;
    [skin pushNSObject:[theInterface countryCode]] ;           lua_setfield(L, -2, "countryCode") ;
    [skin pushNSObject:[theInterface configuration]] ;         lua_setfield(L, -2, "configuration") ;
    [skin pushNSObject:[theInterface cachedScanResults]] ;     lua_setfield(L, -2, "cachedScanResults") ;
    [skin pushNSObject:[theInterface bssid]] ;                 lua_setfield(L, -2, "bssid") ;
    switch([theInterface activePHYMode]) {
        case kCWPHYModeNone: lua_pushstring(L, "None") ; break ;
        case kCWPHYMode11a:  lua_pushstring(L, "A") ; break ;
        case kCWPHYMode11b:  lua_pushstring(L, "B") ; break ;
        case kCWPHYMode11g:  lua_pushstring(L, "G") ; break ;
        case kCWPHYMode11n:  lua_pushstring(L, "N") ; break ;
        case kCWPHYMode11ac: lua_pushstring(L, "AC") ; break ;
        default:             lua_pushstring(L, [[NSString stringWithFormat:@"unrecognized (%ld)", [theInterface activePHYMode]] UTF8String]) ; break ;
    }
    lua_setfield(L, -2, "activePHYMode") ;

    return 1 ;
}

static int pushCWChannel(lua_State *L, id obj) {
    CWChannel *theChannel = (CWChannel *)obj ;
    lua_newtable(L) ;

    switch([theChannel channelWidth]) {
        case kCWChannelWidth20MHz:    lua_pushstring(L, "20MHz") ; break ;
        case kCWChannelWidth40MHz:    lua_pushstring(L, "40MHz") ; break ;
        case kCWChannelWidth80MHz:    lua_pushstring(L, "80MHz") ; break ;
        case kCWChannelWidth160MHz:   lua_pushstring(L, "160MHz") ; break ;
        case kCWChannelWidthUnknown:  lua_pushstring(L, "unknown") ; break ;
        default:                      lua_pushstring(L, [[NSString stringWithFormat:@"unrecognized (%ld)", [theChannel channelWidth]] UTF8String]) ; break ;
    }
    lua_setfield(L, -2, "width") ;

    lua_pushinteger(L, (lua_Integer)[theChannel channelNumber]) ;
    lua_setfield(L, -2, "number") ;

    switch([theChannel channelBand]) {
        case kCWChannelBand2GHz:    lua_pushstring(L, "2GHz") ; break ;
        case kCWChannelBand5GHz:    lua_pushstring(L, "5GHz") ; break ;
        case kCWChannelBandUnknown: lua_pushstring(L, "unknown") ; break ;
        default:                    lua_pushstring(L, [[NSString stringWithFormat:@"unrecognized (%ld)", [theChannel channelBand]] UTF8String]) ; break ;
    }
    lua_setfield(L, -2, "band") ;

    return 1 ;
}

static int pushCWConfiguration(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;

    CWConfiguration *theConfig = (CWConfiguration *)obj ;
    lua_newtable(L) ;
    lua_pushboolean(L, [theConfig requireAdministratorForPower]) ;
    lua_setfield(L, -2, "requireAdministratorForPower") ;
    lua_pushboolean(L, [theConfig requireAdministratorForIBSSMode]) ;
    lua_setfield(L, -2, "requireAdministratorForIBSSMode") ;
    lua_pushboolean(L, [theConfig requireAdministratorForAssociation]) ;
    lua_setfield(L, -2, "requireAdministratorForAssociation") ;
    lua_pushboolean(L, [theConfig rememberJoinedNetworks]) ;
    lua_setfield(L, -2, "rememberJoinedNetworks") ;
    [skin pushNSObject:[[theConfig networkProfiles] array]] ;
    lua_setfield(L, -2, "networkProfiles") ;

    return 1 ;
}

static int pushCWNetwork(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    CWNetwork *theNetwork = (CWNetwork *)obj ;
    lua_newtable(L) ;

    [skin pushNSObject:[theNetwork wlanChannel]] ;            lua_setfield(L, -2, "wlanChannel") ;
    [skin pushNSObject:[theNetwork ssidData]] ;               lua_setfield(L, -2, "ssidData") ;
    [skin pushNSObject:[theNetwork ssid]] ;                   lua_setfield(L, -2, "ssid") ;
    lua_pushinteger(L, [theNetwork rssiValue]) ;              lua_setfield(L, -2, "rssi") ;
    lua_pushinteger(L, [theNetwork noiseMeasurement]) ;       lua_setfield(L, -2, "noise") ;
    [skin pushNSObject:[theNetwork informationElementData]] ; lua_setfield(L, -2, "informationElementData") ;
    lua_pushboolean(L, [theNetwork ibss]) ;                   lua_setfield(L, -2, "ibss") ;
    [skin pushNSObject:[theNetwork countryCode]] ;            lua_setfield(L, -2, "countryCode") ;
    [skin pushNSObject:[theNetwork bssid]] ;                  lua_setfield(L, -2, "bssid") ;
    lua_pushinteger(L, [theNetwork beaconInterval]) ;         lua_setfield(L, -2, "beaconInterval") ;

    lua_newtable(L) ;
    if ([theNetwork supportsSecurity:kCWSecurityNone]) {
        lua_pushstring(L, "None") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    if ([theNetwork supportsSecurity:kCWSecurityWEP]) {
        lua_pushstring(L, "WEP") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    if ([theNetwork supportsSecurity:kCWSecurityWPAPersonal]) {
        lua_pushstring(L, "WPA Personal") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    if ([theNetwork supportsSecurity:kCWSecurityWPAPersonalMixed]) {
        lua_pushstring(L, "WPA Personal Mixed") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    if ([theNetwork supportsSecurity:kCWSecurityWPA2Personal]) {
        lua_pushstring(L, "WPA2 Personal") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    if ([theNetwork supportsSecurity:kCWSecurityPersonal]) {
        lua_pushstring(L, "Personal") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    if ([theNetwork supportsSecurity:kCWSecurityDynamicWEP]) {
        lua_pushstring(L, "Dynamic WEP") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    if ([theNetwork supportsSecurity:kCWSecurityWPAEnterprise]) {
        lua_pushstring(L, "WPA Enterprise") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    if ([theNetwork supportsSecurity:kCWSecurityWPAEnterpriseMixed]) {
        lua_pushstring(L, "WPA Enterprise Mixed") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    if ([theNetwork supportsSecurity:kCWSecurityWPA2Enterprise]) {
        lua_pushstring(L, "WPA2 Enterprise") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    if ([theNetwork supportsSecurity:kCWSecurityEnterprise]) {
        lua_pushstring(L, "Enterprise") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    lua_setfield(L, -2, "security") ;

    lua_newtable(L) ;
    if ([theNetwork supportsPHYMode:kCWPHYModeNone]) {
        lua_pushstring(L, "None") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    if ([theNetwork supportsPHYMode:kCWPHYMode11a]) {
        lua_pushstring(L, "A") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    if ([theNetwork supportsPHYMode:kCWPHYMode11b]) {
        lua_pushstring(L, "B") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    if ([theNetwork supportsPHYMode:kCWPHYMode11g]) {
        lua_pushstring(L, "G") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    if ([theNetwork supportsPHYMode:kCWPHYMode11n]) {
        lua_pushstring(L, "N") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    if ([theNetwork supportsPHYMode:kCWPHYMode11ac]) {
        lua_pushstring(L, "AC") ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    lua_setfield(L, -2, "PHYModes") ;

    return 1 ;
}

static int pushCWNetworkProfile(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin shared] ;
    CWNetworkProfile *theProfile = (CWNetworkProfile *)obj ;
    lua_newtable(L) ;

    [skin pushNSObject:[theProfile ssidData]] ; lua_setfield(L, -2, "ssidData") ;
    [skin pushNSObject:[theProfile ssid]] ;     lua_setfield(L, -2, "ssid") ;
    switch([theProfile security]) {
        case kCWSecurityNone:               lua_pushstring(L, "None") ; break ;
        case kCWSecurityWEP:                lua_pushstring(L, "WEP") ; break ;
        case kCWSecurityWPAPersonal:        lua_pushstring(L, "WPA Personal") ; break ;
        case kCWSecurityWPAPersonalMixed:   lua_pushstring(L, "WPA Personal Mixed") ; break ;
        case kCWSecurityWPA2Personal:       lua_pushstring(L, "WPA2 Personal") ; break ;
        case kCWSecurityPersonal:           lua_pushstring(L, "Personal") ; break ;
        case kCWSecurityDynamicWEP:         lua_pushstring(L, "Dynamic WEP") ; break ;
        case kCWSecurityWPAEnterprise:      lua_pushstring(L, "WPA Enterprise") ; break ;
        case kCWSecurityWPAEnterpriseMixed: lua_pushstring(L, "WPA Enterprise Mixed") ; break ;
        case kCWSecurityWPA2Enterprise:     lua_pushstring(L, "WPA2 Enterprise") ; break ;
        case kCWSecurityEnterprise:         lua_pushstring(L, "Enterprise") ; break ;
        default:                            lua_pushstring(L, [[NSString stringWithFormat:@"unrecognized (%ld)", [theProfile security]] UTF8String]) ; break ;
    }
    lua_setfield(L, -2, "security") ;

    return 1 ;
}

#pragma mark - Hammerspoon Infrastructure

static int userdata_tostring(lua_State* L) {
    HSWifiScan *scanner = get_objectFromUserdata(__bridge HSWifiScan, L, 1);
    LuaSkin *skin = [LuaSkin shared];
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %s (%p)", USERDATA_TAG, ((scanner.isDone) ? "scanning" : "done"), scanner]];
    return 1;
}

static int userdata_gc(lua_State* L) {
    HSWifiScan *scanner = get_objectFromUserdata(__bridge_transfer HSWifiScan, L, 1);
    LuaSkin *skin = [LuaSkin shared];

    scanner.fnRef = [skin luaUnref:refTable ref:scanner.fnRef];

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L);
    lua_setmetatable(L, 1);

    return 0;
}

// static int wifi_gc(lua_State* L __unused) {
//     return 0;
// }

static const luaL_Reg wifilib[] = {
    {"availableNetworks", wifi_scan},
    {"backgroundScan", wifi_scan_background},
    {"interfaces", wifi_interfaces},
    {"currentNetwork", wifi_current_ssid},
    {"interfaceDetails", interfaceDetails},
    {"setPower", setPower},
    {"disassociate", disassociate},

    {"_registerLogForC", lua_registerLogForC},
    {NULL, NULL}
};

// static const luaL_Reg metalib[] = {
//     {"__gc", wifi_gc},
//
//     {NULL, NULL}
// };

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"isDone", backgroundScanIsDone},

    {"__tostring", userdata_tostring},
    {"__gc", userdata_gc},
    {NULL, NULL}
};

int luaopen_hs_wifi_internal(__unused lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:wifilib
                                 metaFunctions:nil // metalib
                               objectFunctions:userdata_metaLib];

    logFnRef = LUA_NOREF;

    [skin registerPushNSHelper:pushCWInterface      forClass:"CWInterface"] ;
    [skin registerPushNSHelper:pushCWChannel        forClass:"CWChannel"] ;
    [skin registerPushNSHelper:pushCWConfiguration  forClass:"CWConfiguration"] ;
    [skin registerPushNSHelper:pushCWNetwork        forClass:"CWNetwork"] ;
    [skin registerPushNSHelper:pushCWNetworkProfile forClass:"CWNetworkProfile"] ;

    return 1;
}

// #pragma clang diagnostic pop

