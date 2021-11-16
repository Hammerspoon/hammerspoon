/// === hs.wifi.watcher ===
///
/// Watch for changes to the associated wifi network

@import Cocoa ;
@import LuaSkin ;
@import CoreWLAN ;

@class HSWifiWatcher ;
@class HSWifiWatcherManager ;

static const char           *USERDATA_TAG = "hs.wifi.watcher" ;
static LSRefTable            refTable = LUA_NOREF ;
static NSDictionary         *watchableTypes ;
static HSWifiWatcherManager *manager ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
// #define get_structFromUserdata(objType, L, idx, tag) ((objType *)luaL_checkudata(L, idx, tag))
// #define get_cfobjectFromUserdata(objType, L, idx, tag) *((objType *)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

@interface HSWifiWatcherManager : NSObject <CWEventDelegate>
// Having problems with 10.10 and 10.11 even though Docs say it should work, so for now, we'll go the old route...
// @property CWWiFiClient *client ;
@property CWInterface  *interface;
@property NSMutableSet *watchers ;
@end

@interface HSWifiWatcher : NSObject
@property int   callbackRef ;
@property int   selfRef ;
@property NSSet *watchingFor ;
@end

@implementation HSWifiWatcherManager
- (instancetype)init {
    self = [super init] ;
    if (self) {
        _watchers = [[NSMutableSet alloc] init] ;

// Having problems with 10.10 and 10.11 even though Docs say it should work, so for now, we'll go the old route...
//         _client = [[CWWiFiClient alloc] init] ;
//         _client.delegate = self ;
        // Using the notification center for the notifications requires us to retain a reference to the interface
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        _interface = [CWInterface interface] ;
#pragma clang diagnostic pop


        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter] ;
        [watchableTypes enumerateKeysAndObjectsUsingBlock:^(__unused NSString *key, NSString *value, __unused BOOL *stop) {
// Having problems with 10.10 and 10.11 even though Docs say it should work, so for now, we'll go the old route...
//             if ([value isKindOfClass:[NSNumber class]]) {
//                 NSError *error ;
//                 [self->_client startMonitoringEventWithType:[value integerValue] error:&error] ;
//                 if (error) {
//                     [LuaSkin logWarn:[NSString stringWithFormat:@"%s:initManager unable to register for event type %@: %@", USERDATA_TAG, key, [error localizedDescription]]] ;
//                 }
//             }
            [nc addObserver:self selector:@selector(identifyNotification:) name:value object:nil];
        }] ;
    }
    return self ;
}

// If we ever go back to the "non-deprecated" approach, this is no longer required
- (void)dealloc {
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter] ;
    [watchableTypes enumerateKeysAndObjectsUsingBlock:^(__unused NSString *key, NSString *value, __unused BOOL *stop) {
        [nc removeObserver:self name:value object:nil];
    }] ;
}

- (void)identifyNotification:(NSNotification *)notification {
    NSString *type = notification.name ;
    NSString *interface = _interface.interfaceName ;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([type isEqualToString:CWPowerDidChangeNotification]) {
        [self invokeCallbacksFor:@"powerChange" withDetails:@[ interface ]] ;
    } else if ([type isEqualToString:CWSSIDDidChangeNotification]) {
        [self invokeCallbacksFor:@"SSIDChange" withDetails:@[ interface ]] ;
    } else if ([type isEqualToString:CWBSSIDDidChangeNotification]) {
        [self invokeCallbacksFor:@"BSSIDChange" withDetails:@[ interface ]] ;
    } else if ([type isEqualToString:CWCountryCodeDidChangeNotification]) {
        [self invokeCallbacksFor:@"countryCodeChange" withDetails:@[ interface ]] ;
    } else if ([type isEqualToString:CWLinkDidChangeNotification]) {
        [self invokeCallbacksFor:@"linkChange" withDetails:@[ interface ]] ;
    } else if ([type isEqualToString:CWLinkQualityDidChangeNotification]) {
        NSNumber *rssi = notification.userInfo[CWLinkQualityNotificationRSSIKey] ;
        NSNumber *transmitRate = notification.userInfo[CWLinkQualityNotificationTransmitRateKey] ;
        [self invokeCallbacksFor:@"linkQualityChange" withDetails:@[ interface, rssi, transmitRate ]] ;
    } else if ([type isEqualToString:CWModeDidChangeNotification]) {
        [self invokeCallbacksFor:@"modeChange" withDetails:@[ interface ]] ;
    } else if ([type isEqualToString:CWScanCacheDidUpdateNotification]) {
        [self invokeCallbacksFor:@"scanCacheUpdated" withDetails:@[ interface ]] ;
    } else {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:identifyNotification - unrecognized notification received: %@", USERDATA_TAG, type]] ;
    }
#pragma clang diagnostic pop
}

// Having problems with 10.10 and 10.11 even though Docs say it should work, so for now, we'll go the old route...
// // // Need to determine if these are useful or if they indicate problems we can't handle at present
// // // anyways... will wait until I know more or someone asks about them.
// //
// // - (void)clientConnectionInterrupted {
// //     [self invokeCallbacksFor:@"connectionInterrupted" withDetails:nil] ;
// // }
// //
// // - (void)clientConnectionInvalidated {
// //     [self invokeCallbacksFor:@"connectionInvalidated" withDetails:nil] ;
// // }
//
// - (void)powerStateDidChangeForWiFiInterfaceWithName:(NSString *)interfaceName {
//     [self invokeCallbacksFor:@"powerChange" withDetails:@[ interfaceName ]] ;
// }
//
// - (void)ssidDidChangeForWiFiInterfaceWithName:(NSString *)interfaceName {
//     [self invokeCallbacksFor:@"SSIDChange" withDetails:@[ interfaceName ]] ;
// }
//
// - (void)bssidDidChangeForWiFiInterfaceWithName:(NSString *)interfaceName {
//     [self invokeCallbacksFor:@"BSSIDChange" withDetails:@[ interfaceName ]] ;
// }
//
// - (void)countryCodeDidChangeForWiFiInterfaceWithName:(NSString *)interfaceName {
//     [self invokeCallbacksFor:@"countryCodeChange" withDetails:@[ interfaceName ]] ;
// }
//
// // // apparently Travis doesn't know about this yet... and since I don't know how to test it
// // // anyways, I'll wait until I know more or someone asks for it
// //
// // - (void)virtualInterfaceStateChangedForWiFiInterfaceWithName:(NSString *)interfaceName {
// //     [self invokeCallbacksFor:@"virtualInterfaceStateChanged" withDetails:@[ interfaceName ]] ;
// // }
//
// // // I think this applies to beacon support which I can't really test with my current hardware
// // // and can't find well documented for macOS at present... I'm holding off on this until I
// // // know more or someone asks about it.
// //
// // - (void)rangingReportEventForWiFiInterfaceWithName:(NSString *)interfaceName data:(NSArray *)rangingData error:(NSError *)error {
// //     NSMutableDictionary *details = [[NSMutableArray alloc] init] ;
// //     [details addObject:interfaceName] ;
// //     if (rangingData) [details addObject:rangingData] ;
// //     if (error)       [details addObject:[error localizedDescription]] ;
// //     [self invokeCallbacksFor:@"rangingReport" withDetails:details] ;
// // }
//
// - (void)linkDidChangeForWiFiInterfaceWithName:(NSString *)interfaceName {
//     [self invokeCallbacksFor:@"linkChange" withDetails:@[ interfaceName ]] ;
// }
//
// - (void)linkQualityDidChangeForWiFiInterfaceWithName:(NSString *)interfaceName rssi:(NSInteger)rssi transmitRate:(double)transmitRate {
//     [self invokeCallbacksFor:@"linkQualityChange" withDetails:@[ interfaceName, @(rssi), @(transmitRate) ]] ;
// }
//
// - (void)modeDidChangeForWiFiInterfaceWithName:(NSString *)interfaceName {
//     [self invokeCallbacksFor:@"modeChange" withDetails:@[ interfaceName ]] ;
// }
//
// - (void)scanCacheUpdatedForWiFiInterfaceWithName:(NSString *)interfaceName {
//     [self invokeCallbacksFor:@"scanCacheUpdated" withDetails:@[ interfaceName ]] ;
// }

- (void)invokeCallbacksFor:(NSString *)message withDetails:(NSArray *)details {
    if (!watchableTypes[message]) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:invokeCallbacksFor called with unrecognized lable:%@", USERDATA_TAG, message]] ;
        return ;
    }
    [_watchers enumerateObjectsUsingBlock:^(HSWifiWatcher *aWatcher, __unused BOOL *stop) {
        if ([aWatcher.watchingFor containsObject:message]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (aWatcher.callbackRef != LUA_NOREF) {
                    LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
                    _lua_stackguard_entry(skin.L);
                    [skin pushLuaRef:refTable ref:aWatcher.callbackRef] ;
                    [skin pushNSObject:aWatcher] ;
                    [skin pushNSObject:message] ;
                    NSUInteger count = (details) ? [details count] : 0 ;
                    if (count > 0) [skin growStack:(int)count withMessage:"hs.wifi.watcher:invokeCallbacksFor"];
                    if (details) {
                        for (id argument in details) {
                            [skin pushNSObject:argument withOptions:LS_NSDescribeUnknownTypes] ;
                        }
                    }
                    [skin protectedCallAndError:[NSString stringWithFormat:@"hs.wifi.watcher callback for %@", message] nargs:(2 + (int)count) nresults:0];
                    _lua_stackguard_exit(skin.L);
                }
            }) ;
        }
    }] ;
}

@end

@implementation HSWifiWatcher

- (instancetype)init {
    self = [super init] ;
    if (self) {
        _callbackRef = LUA_NOREF ;
        _selfRef     = 0 ;
        _watchingFor = [NSSet setWithObject:@"SSIDChange"] ;
    }
    return self ;
}

@end

#pragma mark - Module Functions

/// hs.wifi.watcher.new(fn) -> watcher
/// Constructor
/// Creates a new watcher for WiFi network events
///
/// Parameters:
///  * fn - A function that will be called when a WiFi event that is being monitored occurs. The function should expect 2 or 4 arguments as described in the notes below.
///
/// Returns:
///  * A `hs.wifi.watcher` object
///
/// Notes:
///  * For backwards compatibility, only "SSIDChange" is watched for by default, so existing code can continue to ignore the callback function arguments unless you add or change events with the [hs.wifi.watcher:watchingFor](#watchingFor).
///
///  * The callback function should expect between 3 and 5 arguments, depending upon the events being watched.  The possible arguments are as follows:
///
///    * `watcher`, "SSIDChange", `interface` - occurs when the associated network for the Wi-Fi interface changes
///      * `watcher`   - the watcher object itself
///      * `message`   - the message specifying the event, in this case "SSIDChange"
///      * `interface` - the name of the interface for which the event occured
///    * Use `hs.wifi.currentNetwork([interface])` to identify the new network, which may be nil when you leave a network.
///
///    * `watcher`, "BSSIDChange", `interface` - occurs when the base station the Wi-Fi interface is connected to changes
///      * `watcher`   - the watcher object itself
///      * `message`   - the message specifying the event, in this case "BSSIDChange"
///      * `interface` - the name of the interface for which the event occured
///
///    * `watcher`, "countryCodeChange", `interface` - occurs when the adopted country code of the Wi-Fi interface changes
///      * `watcher`   - the watcher object itself
///      * `message`   - the message specifying the event, in this case "countryCodeChange"
///      * `interface` - the name of the interface for which the event occured
///
///    * `watcher`, "linkChange", `interface` - occurs when the link state for the Wi-Fi interface changes
///      * `watcher`   - the watcher object itself
///      * `message`   - the message specifying the event, in this case "linkChange"
///      * `interface` - the name of the interface for which the event occured
///
///    * `watcher`, "linkQualityChange", `interface` - occurs when the RSSI or transmit rate for the Wi-Fi interface changes
///      * `watcher`   - the watcher object itself
///      * `message`   - the message specifying the event, in this case "linkQualityChange"
///      * `interface` - the name of the interface for which the event occured
///      * `rssi`      - the RSSI value for the currently associated network on the Wi-Fi interface
///      * `rate`      - the transmit rate for the currently associated network on the Wi-Fi interface
///
///    * `watcher`, "modeChange", `interface` - occurs when the operating mode of the Wi-Fi interface changes
///      * `watcher`   - the watcher object itself
///      * `message`   - the message specifying the event, in this case "modeChange"
///      * `interface` - the name of the interface for which the event occured
///
///    * `watcher`, "powerChange", `interface` - occurs when the power state of the Wi-Fi interface changes
///      * `watcher`   - the watcher object itself
///      * `message`   - the message specifying the event, in this case "powerChange"
///      * `interface` - the name of the interface for which the event occured
///
///    * `watcher`, "scanCacheUpdated", `interface` - occurs when the scan cache of the Wi-Fi interface is updated with new information
///      * `watcher`   - the watcher object itself
///      * `message`   - the message specifying the event, in this case "scanCacheUpdated"
///      * `interface` - the name of the interface for which the event occured
// ///
// ///    * `watcher`, "virtualInterfaceStateChanged", `interface` - occurs when the state of a Wi-Fi virtual interface changes
// ///      * `watcher`   - the watcher object itself
// ///      * `message`   - the message specifying the event, in this case "virtualInterfaceStateChanged"
// ///      * `interface` - the name of the interface for which the event occured
static int wifi_watcher_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK] ;
    HSWifiWatcher *newWatcher = [[HSWifiWatcher alloc] init] ;
    if (newWatcher) {
        lua_pushvalue(L, 1) ;
        newWatcher.callbackRef = [skin luaRef:refTable] ;
    }
    [skin pushNSObject:newWatcher] ;
    return 1 ;
}

#pragma mark - Module Methods

/// hs.wifi.watcher:start() -> watcher
/// Method
/// Starts the SSID watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.wifi.watcher` object
static int wifi_watcher_start(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWifiWatcher *watcher = [skin toNSObjectAtIndex:1] ;
    [manager.watchers addObject:watcher] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.wifi.watcher:stop() -> watcher
/// Method
/// Stops the SSID watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.wifi.watcher` object
static int wifi_watcher_stop(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSWifiWatcher *watcher = [skin toNSObjectAtIndex:1] ;
    [manager.watchers removeObject:watcher] ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.wifi.watcher:watchingFor([messages]) -> watcher | current-value
/// Method
/// Get or set the specific types of wifi events to generate a callback for with this watcher.
///
/// Parameters:
///  * `messages` - an optional table of or list of strings specifying the types of events this watcher should invoke a callback for.  You can specify multiple types of events to watch for. Defaults to `{ "SSIDChange" }`.
///
/// Returns:
///  * if a value is provided, returns the watcher object; otherwise returns the current values as a table of strings.
///
/// Notes:
///  * the possible values for this method are described in [hs.wifi.watcher.eventTypes](#eventTypes).
///  * the special string "all" specifies that all event types should be watched for.
static int wifi_watcher_watchingFor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    HSWifiWatcher *watcher = [skin toNSObjectAtIndex:1] ;
    if (lua_gettop(L) == 1) {
        [skin pushNSObject:watcher.watchingFor] ;
    } else {
        NSArray *messages = [skin toNSObjectAtIndex:2] ;
        if ([messages isKindOfClass:[NSArray class]]) {
            __block NSString *messageError ;
            [messages enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
                if ([obj isKindOfClass:[NSString class]]) {
                    if (![[watchableTypes allKeys] containsObject:obj]) {
                        *stop = YES ;
                        messageError = [NSString stringWithFormat:@"unrecognized message at index %lu; expected one of %@", idx + 1, [[watchableTypes allKeys] componentsJoinedByString:@", "]] ;
                    }
                } else {
                    *stop = YES ;
                    messageError = [NSString stringWithFormat:@"expected string at index %lu", idx + 1] ;
                }
            }] ;
            if (messageError) return luaL_argerror(L, 2, [messageError UTF8String]) ;
            watcher.watchingFor = [NSSet setWithArray:messages] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, "expected an array of messages") ;
        }
    }
    return 1 ;
}

#pragma mark - Module Constants

/// hs.wifi.watcher.eventTypes[]
/// Constant
/// A table containing the possible event types that this watcher can monitor for.
///
/// The following events are available for monitoring:
/// * "SSIDChange"                   - monitor when the associated network for the Wi-Fi interface changes
/// * "BSSIDChange"                  - monitor when the base station the Wi-Fi interface is connected to changes
/// * "countryCodeChange"            - monitor when the adopted country code of the Wi-Fi interface changes
/// * "linkChange"                   - monitor when the link state for the Wi-Fi interface changes
/// * "linkQualityChange"            - monitor when the RSSI or transmit rate for the Wi-Fi interface changes
/// * "modeChange"                   - monitor when the operating mode of the Wi-Fi interface changes
/// * "powerChange"                  - monitor when the power state of the Wi-Fi interface changes
/// * "scanCacheUpdated"             - monitor when the scan cache of the Wi-Fi interface is updated with new information
// /// * "virtualInterfaceStateChanged" - monitor when the state of a Wi-Fi virtual interface changes
static int pushEventTypes(lua_State *L) {
    [[LuaSkin sharedWithState:L] pushNSObject:[watchableTypes allKeys]] ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSWifiWatcher(lua_State *L, id obj) {
    HSWifiWatcher *value = obj;
    value.selfRef++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSWifiWatcher *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSWifiWatcherFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSWifiWatcher *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSWifiWatcher, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     HSWifiWatcher *obj = [skin luaObjectAtIndex:1 toClass:"HSWifiWatcher"] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSWifiWatcher *obj1 = [skin luaObjectAtIndex:1 toClass:"HSWifiWatcher"] ;
        HSWifiWatcher *obj2 = [skin luaObjectAtIndex:2 toClass:"HSWifiWatcher"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSWifiWatcher *obj = get_objectFromUserdata(__bridge_transfer HSWifiWatcher, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRef-- ;
        if (obj.selfRef == 0) {
            obj.callbackRef = [[LuaSkin sharedWithState:L] luaUnref:refTable ref:obj.callbackRef] ;
            [manager.watchers removeObject:obj] ;
            obj = nil ;
        }
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

static int meta_gc(lua_State* __unused L) {
    [manager.watchers removeAllObjects] ;
    NSError *error ;
// Having problems with 10.10 and 10.11 even though Docs say it should work, so for now, we'll go the old route...
//     [manager.client stopMonitoringAllEventsAndReturnError:&error] ;
    if (error) {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:meta_gc unable to unregister events: %@", USERDATA_TAG, [error localizedDescription]]] ;
    }
// Having problems with 10.10 and 10.11 even though Docs say it should work, so for now, we'll go the old route...
//     manager.client = nil ;
    manager = nil ;
    return 0 ;
}

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"start",       wifi_watcher_start},
    {"stop",        wifi_watcher_stop},
    {"watchingFor", wifi_watcher_watchingFor},

    {"__tostring",  userdata_tostring},
    {"__eq",        userdata_eq},
    {"__gc",        userdata_gc},
    {NULL,          NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", wifi_watcher_new},
    {NULL,  NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

int luaopen_hs_libwifiwatcher(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    watchableTypes = @{
// Having problems with 10.10 and 10.11 even though Docs say it should work, so for now, we'll go the old route...
//         @"powerChange"                  : @(CWEventTypePowerDidChange),
//         @"SSIDChange"                   : @(CWEventTypeSSIDDidChange),
//         @"BSSIDChange"                  : @(CWEventTypeBSSIDDidChange),
//         @"countryCodeChange"            : @(CWEventTypeCountryCodeDidChange),
//         @"linkChange"                   : @(CWEventTypeLinkDidChange),
//         @"linkQualityChange"            : @(CWEventTypeLinkQualityDidChange),
//         @"modeChange"                   : @(CWEventTypeModeDidChange),
//         @"scanCacheUpdated"             : @(CWEventTypeScanCacheUpdated),
// // see delegate for comments regarding these
// //         @"virtualInterfaceStateChanged" : @(CWEventTypeVirtualInterfaceStateChanged),
// //         @"rangingReport"                : @(CWEventTypeRangingReportEvent),
// //         @"connectionInterrupted"        : @"clientConnectionInterrupted",
// //         @"connectionInvalidated"        : @"clientConnectionInvalidated",
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        @"powerChange"                  : CWPowerDidChangeNotification,
        @"SSIDChange"                   : CWSSIDDidChangeNotification,
        @"BSSIDChange"                  : CWBSSIDDidChangeNotification,
        @"countryCodeChange"            : CWCountryCodeDidChangeNotification,
        @"linkChange"                   : CWLinkDidChangeNotification,
        @"linkQualityChange"            : CWLinkQualityDidChangeNotification,
        @"modeChange"                   : CWModeDidChangeNotification,
        @"scanCacheUpdated"             : CWScanCacheDidUpdateNotification,
#pragma clang diagnostic pop
    } ;

    manager = [[HSWifiWatcherManager alloc] init] ;

    [skin registerPushNSHelper:pushHSWifiWatcher         forClass:"HSWifiWatcher"];
    [skin registerLuaObjectHelper:toHSWifiWatcherFromLua forClass:"HSWifiWatcher"
                                             withUserdataMapping:USERDATA_TAG];

    pushEventTypes(L) ; lua_setfield(L, -2, "eventTypes") ;

    return 1;
}
