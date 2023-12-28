@import Cocoa ;
@import LuaSkin ;
@import IOKit.ps ;
@import IOKit.pwr_mgt ;

@import IOBluetooth;

// Define the private API items of IOBluetooth we wil be using
// Taken from https://github.com/w0lfschild/macOS_headers/blob/master/macOS/Frameworks/IOBluetooth/6.0.2f2/IOBluetoothDevice.h
@interface IOBluetoothDevice (Private)
+ (id)connectedDevices;
- (unsigned short)productID;
- (unsigned short)vendorID;
- (BOOL)isAppleDevice;
@property(readonly) NSString *addressString;
@property(readonly) BOOL isEnhancedDoubleTapSupported;
@property(readonly) BOOL isANCSupported;
@property(readonly) BOOL isInEarDetectionSupported;
@property(nonatomic) unsigned char batteryPercentCombined;
@property(nonatomic) unsigned char batteryPercentCase;
@property(nonatomic) unsigned char batteryPercentRight;
@property(nonatomic) unsigned char batteryPercentLeft;
@property(nonatomic) unsigned char batteryPercentSingle;
@property(nonatomic) unsigned char primaryBud;
@property(nonatomic) unsigned char rightDoubleTap;
@property(nonatomic) unsigned char leftDoubleTap;
@property(nonatomic) unsigned char buttonMode;
@property(nonatomic) unsigned char micMode;
@property(nonatomic) unsigned char secondaryInEar;
@property(nonatomic) unsigned char primaryInEar;
@end

/// hs.battery.timeRemaining() -> number
/// Function
/// Returns the battery life remaining, in minutes
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the minutes of battery life remaining. The value may be:
///   * Greater than zero to indicate the number of minutes remaining
///   * -1 if the remaining battery life is still being calculated
///   * -2 if there is unlimited time remaining (i.e. the system is on AC power)
static int battery_timeremaining(lua_State* L) {
    CFTimeInterval remaining = IOPSGetTimeRemainingEstimate();

    if (remaining > 0)
        remaining /= 60;

    lua_pushnumber(L, remaining);
    return 1;
}

/// hs.battery.powerSource() -> string
/// Function
/// Returns the current source providing power
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing one of {AC Power, Battery Power, UPS Power}.
static int battery_powerSource(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    CFTypeRef sourcesBlob = IOPSCopyPowerSourcesInfo() ;
    if (sourcesBlob) {
        [skin pushNSObject:(__bridge NSString *)IOPSGetProvidingPowerSourceType(sourcesBlob)] ;
        CFRelease(sourcesBlob) ;
        return 1 ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "error retrieving power sources info") ;
        return 2 ;
    }
}

/// hs.battery.warningLevel() -> string
/// Function
/// Returns a string specifying the current battery warning state.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string specifying the current warning level state. The string will be one of "none", "low", or "critical".
///
/// Notes:
///  * The meaning of the return strings is as follows:
///    * "none" - indicates that the system is not in a low battery situation, or is currently attached to an AC power source.
///    * "low"  - the system is in a low battery situation and can provide no more than 20 minutes of runtime. Note that this is a guess only; 20 minutes cannot be guaranteed and will be greatly influenced by what the computer is doing at the time, how many applications are running, screen brightness, etc.
///    * "critical" - the system is in a very low battery situation and can provide no more than 10 minutes of runtime. Note that this is a guess only; 10 minutes cannot be guaranteed and will be greatly influenced by what the computer is doing at the time, how many applications are running, screen brightness, etc.
static int battery_batteryWarningLevel(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    IOPSLowBatteryWarningLevel level = IOPSGetBatteryWarningLevel() ;
    switch(level) {
        case kIOPSLowBatteryWarningNone:  lua_pushstring(L, "none")     ; break ;
        case kIOPSLowBatteryWarningEarly: lua_pushstring(L, "low")      ; break ;
        case kIOPSLowBatteryWarningFinal: lua_pushstring(L, "critical") ; break ;
        default:
            lua_pushfstring(L, "** unrecognized warning level: %d", level) ;
    }
    return 1 ;
}

/// hs.battery.otherBatteryInfo() -> table
/// Function
/// Returns information about non-PSU batteries (e.g. Bluetooth accessories)
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing information about other batteries known to the system, or an empty table if no devices were found
static int battery_others(lua_State*L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    mach_port_t     masterPort;
    kern_return_t   kr;
    io_iterator_t   ite;
    io_object_t     obj = 0;
    CFMutableDictionaryRef  properties;
    NSMutableArray *batteryInfo = [NSMutableArray arrayWithCapacity:5];

    kr = IOMainPort(bootstrap_port, &masterPort);
    if (kr != KERN_SUCCESS) {
        NSLog(@"IOMasterPort() failed: %x\n", kr);
        goto lua_return;
    }

    kr = IORegistryCreateIterator(masterPort,
                                  kIOServicePlane,
                                  true,
                                  &ite);

    while ((obj = IOIteratorNext(ite))) {
        kr = IORegistryEntryCreateCFProperties(obj,
                                               &properties,
                                               kCFAllocatorDefault,
                                               kNilOptions);

        if ((kr != KERN_SUCCESS) || !properties) {
            NSLog(@"IORegistryEntryCreateCFProperties error %x\n", kr);
            goto lua_return;
        } else {
            CFNumberRef percent = (CFNumberRef) CFDictionaryGetValue(properties, CFSTR("BatteryPercent"));
            if (percent) {
                SInt32 s;
                if(CFNumberGetValue(percent, kCFNumberSInt32Type, &s)) {
                    NSDictionary *deviceProperties = (__bridge NSDictionary *)properties;
                    [batteryInfo addObject:deviceProperties];
                }
            }
        }

        CFRelease(properties);
        IOObjectRelease(obj);
    }

    IOObjectRelease(ite);

lua_return:
    [skin pushNSObject:batteryInfo];
    return 1;
}

/// hs.battery.privateBluetoothBatteryInfo() -> table
/// Function
/// Returns information about Bluetooth devices using Apple Private APIs
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing information about devices using private Apple APIs.
///
/// Notes:
///  * This function uses private Apple APIs - that means it can break without notice on any macOS version update. Please report breakage to us!
///  * This function will return information for all connected Bluetooth devices, but much of it will be meaningless for most devices
///  * The table contains the following keys:
///    * vendorID - Numerical identifier for the vendor of the device (Apple's ID is 76)
///    * productID - Numerical identifier for the device
///    * address - The Bluetooth address of the device
///    * isApple - A string containing "YES" or "NO", depending on whether or not this is an Apple/Beats product, or a third party product
///    * name - A human readable string containing the name of the device
///    * batteryPercentSingle - For some devices this will contain the percentage of the battery (e.g. Beats headphones)
///    * batteryPercentCombined - We do not currently understand what this field represents, please report if you find a non-zero value here
///    * batteryPercentCase - Battery percentage of AirPods cases (note that this will often read 0 - the AirPod case sleeps aggressively)
///    * batteryPercentLeft - Battery percentage of the left AirPod if it is out of the case
///    * batteryPercentRight - Battery percentage of the right AirPod if it is out of the case
///    * buttonMode - We do not currently understand what this field represents, please report if you find a value other than 1
///    * micMode - For AirPods this corresponds to the microphone option in the device's Bluetooth options
///    * leftDoubleTap - For AirPods this corresponds to the left double tap action in the device's Bluetooth options
///    * rightDoubleTap - For AirPods this corresponds to the right double tap action in the device's Bluetooth options
///    * primaryBud - For AirPods this is either "left" or "right" depending on which bud is currently considered the primary device
///    * primaryInEar - For AirPods this is "YES" or "NO" depending on whether or not the primary bud is currently in an ear
///    * secondaryInEar - For AirPods this is "YES" or "NO" depending on whether or not the secondary bud is currently in an ear
///    * isInEarDetectionSupported - Whether or not this device can detect when it is currently in an ear
///    * isEnhancedDoubleTapSupported - Whether or not this device supports double tapping
///    * isANCSupported - We believe this likely indicates whether or not this device supports Active Noise Cancelling (e.g. Beats Solo)
///  * Please report any crashes from this function - it's likely that there are Bluetooth devices we haven't tested which may return weird data
///  * Many/Most/All non-Apple party products will likely return zeros for all of the battery related fields here, as will Apple HID devices. It seems that these private APIs mostly exist to support Apple/Beats headphones.
static int battery_private(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    NSMutableArray *privateInfo = [[NSMutableArray alloc] init];

    NSDictionary *devices = [IOBluetoothDevice connectedDevices];
    for (IOBluetoothDevice *device in devices) {
        NSMutableDictionary *deviceInfo = [[NSMutableDictionary alloc] init];
        deviceInfo[@"name"] = device.name;
        //NSLog(@"Found: %@ %i:%i", device.name, device.vendorID, device.productID);
        deviceInfo[@"vendorID"] = [NSString stringWithFormat:@"%i", device.vendorID];
        deviceInfo[@"productID"] = [NSString stringWithFormat:@"%i", device.productID];
        deviceInfo[@"isApple"] = [NSString stringWithFormat:@"%@", device.isAppleDevice ? @"YES" : @"NO"];
        deviceInfo[@"address"] = device.addressString;

        deviceInfo[@"buttonMode"] = [NSString stringWithFormat:@"%i", device.buttonMode];

        deviceInfo[@"batteryPercentCombined"] = [NSString stringWithFormat:@"%i", device.batteryPercentCombined];
        deviceInfo[@"batteryPercentSingle"] = [NSString stringWithFormat:@"%i", device.batteryPercentSingle];

        deviceInfo[@"batteryPercentCase"] = [NSString stringWithFormat:@"%i", device.batteryPercentCase];
        deviceInfo[@"batteryPercentRight"] = [NSString stringWithFormat:@"%i", device.batteryPercentRight];
        deviceInfo[@"batteryPercentLeft"] = [NSString stringWithFormat:@"%i", device.batteryPercentLeft];

        deviceInfo[@"primaryBud"] = [NSString stringWithFormat:@"%@", (device.primaryBud == 1) ? @"left" : @"right"];
        deviceInfo[@"isInEarDetectionSupported"] = [NSString stringWithFormat:@"%@", device.isInEarDetectionSupported ? @"YES" : @"NO"];
        deviceInfo[@"secondaryInEar"] = [NSString stringWithFormat:@"%@", device.secondaryInEar ? @"NO" : @"YES"];
        deviceInfo[@"primaryInEar"] = [NSString stringWithFormat:@"%@", device.primaryInEar ? @"NO" : @"YES"];

        deviceInfo[@"isEnhancedDoubleTapSupported"] = [NSString stringWithFormat:@"%@", device.isEnhancedDoubleTapSupported ? @"YES" : @"NO"];
        deviceInfo[@"rightDoubleTap"] = [NSString stringWithFormat:@"%i", device.rightDoubleTap];
        deviceInfo[@"leftDoubleTap"] = [NSString stringWithFormat:@"%i", device.leftDoubleTap];

        deviceInfo[@"micMode"] = [NSString stringWithFormat:@"%i", device.micMode];
        deviceInfo[@"isANCSupported"] = [NSString stringWithFormat:@"%@", device.isANCSupported ? @"YES" : @"NO"];

        // Store the device
        [privateInfo addObject:deviceInfo];
    }
    [skin pushNSObject:privateInfo];
    return 1;
}

static int battery_externalAdapterDetails(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    CFDictionaryRef psuInfo = IOPSCopyExternalPowerAdapterDetails();
    if (psuInfo) {
        [skin pushNSObject:(__bridge_transfer NSArray *)psuInfo withOptions:LS_NSDescribeUnknownTypes] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static int battery_powerSources(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    CFTypeRef sourcesBlob = IOPSCopyPowerSourcesInfo() ;
    if (sourcesBlob) {
        CFArrayRef sourcesList = IOPSCopyPowerSourcesList(sourcesBlob) ;
        if (sourcesList) {
            lua_newtable(L) ;
            for (CFIndex i = 0 ; i < CFArrayGetCount(sourcesList) ; i++) {
                CFDictionaryRef powerSource = IOPSGetPowerSourceDescription(sourcesBlob, CFArrayGetValueAtIndex(sourcesList, i)) ;
                if (powerSource) {
                    [skin pushNSObject:(__bridge NSDictionary *)powerSource withOptions:LS_NSDescribeUnknownTypes] ;
                } else {
                    [skin pushNSObject:[NSString stringWithFormat:@"unable to get description of power source %ld", i + 1]] ;
                }
                lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
            CFRelease(sourcesList) ;
            CFRelease(sourcesBlob) ;
            return 1 ;
        } else {
            CFRelease(sourcesBlob) ;
            lua_pushnil(L) ;
            lua_pushstring(L, "error retrieving power sources list") ;
            return 2 ;
        }
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "error retrieving power sources info") ;
        return 2 ;
    }
}

static int battery_appleSmartBattery(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    io_service_t entry = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("AppleSmartBattery")) ;
    if (entry) {
        CFMutableDictionaryRef battery ;
        IORegistryEntryCreateCFProperties(entry, &battery, NULL, 0) ;
        [skin pushNSObject:(__bridge_transfer NSDictionary *)battery withOptions:LS_NSDescribeUnknownTypes] ;
        IOObjectRelease(entry) ;
        return 1 ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "unable to retrieve AppleSmartBattery IOService") ;
        return 2 ;
    }
}

static int battery_iopmBatteryInfo(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    mach_port_t masterPort;
    CFArrayRef batteryInfo;

    if (kIOReturnSuccess == IOMainPort(MACH_PORT_NULL, &masterPort)) {
        if (kIOReturnSuccess == IOPMCopyBatteryInfo(masterPort, &batteryInfo)) {
            [skin pushNSObject:(__bridge_transfer NSArray *)batteryInfo] ;
            return 1 ;
        } else {
            if (batteryInfo) CFRelease(batteryInfo) ;
            lua_pushnil(L) ;
            lua_pushstring(L, "unable to get IOPM Battery Info") ;
            return 2 ;
        }
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "unable to get IO Master Port") ;
        return 2 ;
    }
}

static const luaL_Reg battery_lib[] = {
    {"timeRemaining",               battery_timeremaining},
    {"powerSource",                 battery_powerSource},
    {"otherBatteryInfo",            battery_others},
    {"privateBluetoothBatteryInfo", battery_private},
    {"warningLevel",                battery_batteryWarningLevel},

    {"_adapterDetails",             battery_externalAdapterDetails},
    {"_powerSources",               battery_powerSources},
    {"_appleSmartBattery",          battery_appleSmartBattery},
    {"_iopmBatteryInfo",            battery_iopmBatteryInfo},

    {NULL, NULL}
};

int luaopen_hs_libbattery(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibrary:"hs.battery" functions:battery_lib metaFunctions:nil];

    return 1;
}
