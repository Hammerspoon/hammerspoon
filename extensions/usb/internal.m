#import <Cocoa/Cocoa.h>
#import <IOKit/usb/IOUSBLib.h>
#import <LuaSkin/LuaSkin.h>

CFStringRef productNameKey = CFSTR(kUSBProductString);
CFStringRef vendorNameKey = CFSTR(kUSBVendorString);
CFStringRef productIDKey = CFSTR(kUSBProductID);
CFStringRef vendorIDKey = CFSTR(kUSBVendorID);

static int usb_gc(lua_State* L __unused) {
    return 0;
}

/// hs.usb.attachedDevices() -> table or nil
/// Function
/// Gets details about currently attached USB devices
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing information about currently attached USB devices, or nil if an error occurred. The table contains a sub-table for each USB device, the keys of which are:
///   * productName - A string containing the name of the device
///   * vendorName - A string containing the name of the device vendor
///   * vendorID - A number containing the Vendor ID of the device
///   * productID - A number containing the Product ID of the device
static int usb_attachedDevices(lua_State* L) {
    CFMutableDictionaryRef matchingDict;
    CFMutableDictionaryRef deviceData;

    CFStringRef productName = nil;
    CFStringRef vendorName = nil;
    CFNumberRef productID = nil;
    CFNumberRef vendorID = nil;

    io_iterator_t iterator;
    io_service_t usbDevice;
    int i = 1;

    matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
    if (!matchingDict) {
        lua_pushnil(L);
        return 1;
    }

    if (IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &iterator) != KERN_SUCCESS) {
        lua_pushnil(L);
        return 1;
    }

    lua_newtable(L);

    while ((usbDevice = IOIteratorNext(iterator))) {
        lua_pushinteger(L, i++);

        // START OF BLOCK THAT SHOULD MOVE OUT TO A SEPARATE FUNCTION
        IORegistryEntryCreateCFProperties(usbDevice, &deviceData, kCFAllocatorDefault, kNilOptions);

        productName = CFDictionaryGetValue(deviceData, productNameKey);
        vendorName = CFDictionaryGetValue(deviceData, vendorNameKey);
        productID = CFDictionaryGetValue(deviceData, productIDKey);
        vendorID = CFDictionaryGetValue(deviceData, vendorIDKey);

        //NSLog(@"Found: '%@'(%@) '%@'(%@)", vendorName, vendorID, productName, productID);

        lua_newtable(L);
        lua_pushstring(L, "productName");
        lua_pushstring(L, [(__bridge NSString *)productName UTF8String]);
        lua_settable(L, -3);
        lua_pushstring(L, "vendorName");
        lua_pushstring(L, [(__bridge NSString *)vendorName UTF8String]);
        lua_settable(L, -3);
        lua_pushstring(L, "productID");
        lua_pushinteger(L, [(__bridge NSNumber *)productID intValue]);
        lua_settable(L, -3);
        lua_pushstring(L, "vendorID");
        lua_pushinteger(L, [(__bridge NSNumber *)vendorID intValue]);
        lua_settable(L, -3);

        IOObjectRelease(usbDevice);
        CFRelease(deviceData);
        // END OF BLOCK THAT SHOULD MOVE OUT TO A SEPARATE FUNCTION

        lua_settable(L, -3);
    }

    IOObjectRelease(iterator);

    return 1;
}

static const luaL_Reg usblib[] = {
    {"attachedDevices", usb_attachedDevices},

    {NULL, NULL}
};

static const luaL_Reg metalib[] = {
    {"__gc", usb_gc},

    {NULL, NULL}
};

int luaopen_hs_usb_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibrary:"hs.usb" functions:usblib metaFunctions:metalib];

    return 1;
}
