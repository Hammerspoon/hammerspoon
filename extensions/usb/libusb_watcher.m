#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/IOMessage.h>
#import <IOKit/IOCFPlugIn.h>
#import <IOKit/usb/IOUSBLib.h>
#import <LuaSkin/LuaSkin.h>

/// === hs.usb.watcher ===
///
/// Watch for USB device connection/disconnection events

// Common Code

#define USERDATA_TAG    "hs.usb.watcher"
static LSRefTable refTable;

// Not so common code

// userdata object for each watcher
typedef struct _usbwatcher_t {
    bool running;
    bool isFirstRun;
    int fn;
    IONotificationPortRef gNotifyPort;
    io_iterator_t gAddedIter;
    CFRunLoopSourceRef runLoopSource;
    LSGCCanary lsCanary;
} usbwatcher_t;

// private data for each USB device
typedef struct _usbprivdata_t {
    usbwatcher_t *watcher;
    io_object_t notification;
    char *productName;
    char *vendorName;
    int productID;
    int vendorID;
} usbprivdata_t;

// Process an IOKit notification, discarding it if it's not about a device being removed
void DeviceNotification(void *refCon, io_service_t service __unused, natural_t messageType, void *messageArgument __unused) {
    usbprivdata_t *privateDataRef = (usbprivdata_t *)refCon;
    usbwatcher_t *watcher = privateDataRef->watcher;

    if (messageType == kIOMessageServiceIsTerminated) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        lua_State *L = skin.L;
        if (![skin checkGCCanary:watcher->lsCanary]) {
            return;
        }
        _lua_stackguard_entry(L);

        [skin pushLuaRef:refTable ref:watcher->fn];

        // Prepare the callback's argument table
        lua_newtable(L);
        lua_pushstring(L, "productName");
        lua_pushstring(L, privateDataRef->productName);
        lua_settable(L, -3);
        lua_pushstring(L, "vendorName");
        lua_pushstring(L, privateDataRef->vendorName);
        lua_settable(L, -3);
        lua_pushstring(L, "productID");
        lua_pushinteger(L, privateDataRef->productID);
        lua_settable(L, -3);
        lua_pushstring(L, "vendorID");
        lua_pushinteger(L, privateDataRef->vendorID);
        lua_settable(L, -3);
        lua_pushstring(L, "eventType");
        lua_pushstring(L, "removed");
        lua_settable(L, -3);

        // Call the callback
        [skin protectedCallAndError:@"hs.usb.watcher:removed callback" nargs:1 nresults:0];

        // Free the USB private data
        if (privateDataRef) {
            IOObjectRelease(privateDataRef->notification);
        }
        if (privateDataRef->productName) {
            free(privateDataRef->productName);
            privateDataRef->productName = NULL;
        }
        if (privateDataRef->vendorName) {
            free(privateDataRef->vendorName);
            privateDataRef->vendorName = NULL;
        }
        if (privateDataRef) {
            free(privateDataRef);
            privateDataRef = NULL;
        }
        _lua_stackguard_exit(L);
    }
}

// Iterate over new devices
void DeviceAdded(void *refCon, io_iterator_t iterator) {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    lua_State *L = skin.L;
    _lua_stackguard_entry(L);
    usbwatcher_t *watcher = (usbwatcher_t *)refCon;
    kern_return_t kr;
    io_service_t usbDevice;
    CFMutableDictionaryRef deviceData;
    NSString *productName;
    NSString *vendorName;
    int length;

    while ((usbDevice = IOIteratorNext(iterator))) {
        // Prepare an object to store private data about this USB device
        usbprivdata_t *privateDataRef = NULL;
        privateDataRef = malloc(sizeof(usbprivdata_t));
        bzero(privateDataRef, sizeof(usbprivdata_t));
        privateDataRef->watcher = watcher;

        // Fetch the IOKit properties for this device
        IORegistryEntryCreateCFProperties(usbDevice, &deviceData, kCFAllocatorDefault, kNilOptions);

        // Extract the USB device's name
        productName = (__bridge NSString *)CFDictionaryGetValue(deviceData, CFSTR(kUSBProductString));
        length = (int)[productName length] + 1;
        privateDataRef->productName = malloc(length);
        if (![productName getCString:privateDataRef->productName maxLength:length encoding:NSUTF8StringEncoding]) {
            privateDataRef->productName[0] = '\0';
        }

        // Extract the USB device's vendor's name
        vendorName = (__bridge NSString *)CFDictionaryGetValue(deviceData, CFSTR(kUSBVendorString));
        length = (int)[vendorName length] + 1;
        privateDataRef->vendorName = malloc(length);
        if (![vendorName getCString:privateDataRef->vendorName maxLength:length encoding:NSUTF8StringEncoding]) {
            privateDataRef->vendorName[0] = '\0';
        }

        // Extract the USB device's product/vendor IDs
        privateDataRef->productID = [(__bridge NSNumber *)CFDictionaryGetValue(deviceData, CFSTR(kUSBProductID)) intValue];
        privateDataRef->vendorID  = [(__bridge NSNumber *)CFDictionaryGetValue(deviceData, CFSTR(kUSBVendorID)) intValue];

        // Register for notifications relating to this device
        kr = IOServiceAddInterestNotification(watcher->gNotifyPort, usbDevice, kIOGeneralInterest, DeviceNotification, privateDataRef, &(privateDataRef->notification));
        if (KERN_SUCCESS != kr) {
            [skin logBreadcrumb:[NSString stringWithFormat:@"IOServiceAddInterestNotification returned 0x%08x", kr]];
        }

        // Release data we don't need anymore
        CFRelease(deviceData);
        IOObjectRelease(usbDevice);

        // We don't want to trigger callbacks for every device attached before the watcher starts, but we needed to enumerate them to get private device data cached
        if (!watcher->isFirstRun && watcher->fn != LUA_REFNIL && watcher->fn != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:watcher->fn];

            lua_newtable(L);
            lua_pushstring(L, "productName");
            lua_pushstring(L, privateDataRef->productName);
            lua_settable(L, -3);
            lua_pushstring(L, "vendorName");
            lua_pushstring(L, privateDataRef->vendorName);
            lua_settable(L, -3);
            lua_pushstring(L, "productID");
            lua_pushinteger(L, privateDataRef->productID);
            lua_settable(L, -3);
            lua_pushstring(L, "vendorID");
            lua_pushinteger(L, privateDataRef->vendorID);
            lua_settable(L, -3);
            lua_pushstring(L, "eventType");
            lua_pushstring(L, "added");
            lua_settable(L, -3);

            [skin protectedCallAndError:@"hs.usb.watcher:added callback" nargs:1 nresults:0];
        }
    }
    _lua_stackguard_exit(L);
}

/// hs.usb.watcher.new(fn) -> watcher
/// Constructor
/// Creates a new watcher for USB device events
///
/// Parameters:
///  * fn - A function that will be called when a USB device is inserted or removed. The function should accept a single parameter, which is a table containing the following keys:
///   * eventType - A string containing either "added" or "removed" depending on whether the USB device was connected or disconnected
///   * productName - A string containing the name of the device
///   * vendorName - A string containing the name of the device vendor
///   * vendorID - A number containing the Vendor ID of the device
///   * productID - A number containing the Product ID of the device
///
/// Returns:
///  * A `hs.usb.watcher` object
static int usb_watcher_new(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    luaL_checktype(L, 1, LUA_TFUNCTION);

    usbwatcher_t* usbwatcher = lua_newuserdata(L, sizeof(usbwatcher_t));
    memset(usbwatcher, 0, sizeof(usbwatcher_t));
    lua_pushvalue(L, 1);

    usbwatcher->fn = [skin luaRef:refTable];
    usbwatcher->running = NO;
    usbwatcher->gNotifyPort = IONotificationPortCreate(kIOMasterPortDefault);
    usbwatcher->runLoopSource = IONotificationPortGetRunLoopSource(usbwatcher->gNotifyPort);
    usbwatcher->lsCanary = [skin createGCCanary];

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1;
}

/// hs.usb.watcher:start() -> watcher
/// Method
/// Starts the USB watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.usb.watcher` object
static int usb_watcher_start(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    usbwatcher_t* usbwatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L,1) ;

    if (usbwatcher->running) return 1;

    CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
    if (!matchingDict) {
        [skin logBreadcrumb:@"Unable to create USB watcher matching dictionary"];
        return 1;
    }

    usbwatcher->running = YES;
    usbwatcher->isFirstRun = YES;

    CFRunLoopAddSource(CFRunLoopGetCurrent(), usbwatcher->runLoopSource, kCFRunLoopDefaultMode);
    if (KERN_SUCCESS == IOServiceAddMatchingNotification(usbwatcher->gNotifyPort,
                                                         kIOFirstMatchNotification,
                                                         matchingDict,
                                                         DeviceAdded,
                                                         usbwatcher,
                                                         &usbwatcher->gAddedIter)) {
        DeviceAdded(usbwatcher, usbwatcher->gAddedIter);
        usbwatcher->isFirstRun = NO;
    }

    return 1;
}

/// hs.usb.watcher:stop() -> watcher
/// Method
/// Stops the USB watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.usb.watcher` object
static int usb_watcher_stop(lua_State* L) {
    usbwatcher_t* usbwatcher = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L,1) ;

    if (!usbwatcher->running) return 1;

    usbwatcher->running = NO;
    IOObjectRelease(usbwatcher->gAddedIter);
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), usbwatcher->runLoopSource, kCFRunLoopDefaultMode);

    return 1;
}

static int usb_watcher_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    usbwatcher_t* usbwatcher = luaL_checkudata(L, 1, USERDATA_TAG);

    lua_pushcfunction(L, usb_watcher_stop) ; lua_pushvalue(L,1); lua_call(L, 1, 1);

    usbwatcher->fn = [skin luaUnref:refTable ref:usbwatcher->fn];
    [skin destroyGCCanary:&(usbwatcher->lsCanary)];

    IONotificationPortDestroy(usbwatcher->gNotifyPort);

    return 0;
}

static int meta_gc(lua_State* __unused L) {
    return 0;
}

static int userdata_tostring(lua_State* L) {
    lua_pushstring(L, [[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

// Metatable for created objects when _new invoked
static const luaL_Reg usb_metalib[] = {
    {"start",   usb_watcher_start},
    {"stop",    usb_watcher_stop},
    {"__tostring", userdata_tostring},
    {"__gc",    usb_watcher_gc},
    {NULL,      NULL}
};

// Functions for returned object when module loads
static const luaL_Reg usbLib[] = {
    {"new",     usb_watcher_new},
    {NULL,      NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

int luaopen_hs_libusbwatcher(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:usbLib metaFunctions:meta_gcLib objectFunctions:usb_metalib];

    return 1;
}
