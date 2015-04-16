#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>
#import <IOKit/graphics/IOGraphicsLib.h>
#import <lauxlib.h>

#define get_screen_arg(L, idx) (__bridge NSScreen*)*((void**)luaL_checkudata(L, idx, "hs.screen"))

static void geom_pushrect(lua_State* L, NSRect rect) {
    lua_newtable(L);
    lua_pushnumber(L, rect.origin.x);    lua_setfield(L, -2, "x");
    lua_pushnumber(L, rect.origin.y);    lua_setfield(L, -2, "y");
    lua_pushnumber(L, rect.size.width);  lua_setfield(L, -2, "w");
    lua_pushnumber(L, rect.size.height); lua_setfield(L, -2, "h");
}

static int screen_frame(lua_State* L) {
    NSScreen* screen = get_screen_arg(L, 1);
    geom_pushrect(L, [screen frame]);
    return 1;
}

static int screen_visibleframe(lua_State* L) {
    NSScreen* screen = get_screen_arg(L, 1);
    geom_pushrect(L, [screen visibleFrame]);
    return 1;
}

static NSMutableDictionary *originalGammas;
static NSMutableDictionary *currentGammas;
static dispatch_queue_t notificationQueue;

/// hs.screen:id(screen) -> number
/// Method
/// Returns a screen's unique ID.
static int screen_id(lua_State* L) {
    NSScreen* screen = get_screen_arg(L, 1);
    lua_pushnumber(L, [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] doubleValue]);
    return 1;
}

/// hs.screen:name(screen) -> string
/// Method
/// Returns the preferred name for the screen set by the manufacturer.
static int screen_name(lua_State* L) {
    NSScreen* screen = get_screen_arg(L, 1);
    CGDirectDisplayID screen_id = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] intValue];

    CFDictionaryRef deviceInfo = IODisplayCreateInfoDictionary(CGDisplayIOServicePort(screen_id), kIODisplayOnlyPreferredName);
    NSDictionary *localizedNames = [(__bridge NSDictionary *)deviceInfo objectForKey:[NSString stringWithUTF8String:kDisplayProductName]];

    if ([localizedNames count])
        lua_pushstring(L, [[localizedNames objectForKey:[[localizedNames allKeys] objectAtIndex:0]] UTF8String]);
    else
        lua_pushnil(L);

    CFRelease(deviceInfo);

    return 1;
}

// CoreGraphics DisplayMode struct used in private APIs
typedef struct {
    uint32_t modeNumber;
    uint32_t flags;
    uint32_t width;
    uint32_t height;
    uint32_t depth;
    uint8_t unknown[170];
    uint16_t freq;
    uint8_t more_unknown[16];
    float density;
} CGSDisplayMode;

// CoreGraphics private APIs with support for scaled (retina) display modes
void CGSGetCurrentDisplayMode(CGDirectDisplayID display, int *modeNum);
void CGSConfigureDisplayMode(CGDisplayConfigRef config, CGDirectDisplayID display, int modeNum);
void CGSGetNumberOfDisplayModes(CGDirectDisplayID display, int *nModes);
void CGSGetDisplayModeDescriptionOfLength(CGDirectDisplayID display, int idx, CGSDisplayMode *mode, int length);

/// hs.screen:currentMode() -> table
/// Method
/// Returns a table describing the current screen mode
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the current screen mode. The keys of the table are:
///   * w - A number containing the width of the screen mode in points
///   * h - A number containing the height of the screen mode in points
///   * scale - A number containing the scaling factor of the screen mode (typically `1` for a native mode, `2` for a HiDPI mode)
///   * desc - A string containing a representation of the mode as used in `hs.screen:availableModes()` - e.g. "1920x1080@2x"
static int screen_currentMode(lua_State* L) {
    NSScreen* screen = get_screen_arg(L, 1);
    CGDirectDisplayID screen_id = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] intValue];
    int currentModeNumber;
    CGSGetCurrentDisplayMode(screen_id, &currentModeNumber);
    CGSDisplayMode mode;
    CGSGetDisplayModeDescriptionOfLength(screen_id, currentModeNumber, &mode, sizeof(mode));

    lua_newtable(L);

    lua_pushnumber(L, (double)mode.width);
    lua_setfield(L, -2, "w");

    lua_pushnumber(L, (double)mode.height);
    lua_setfield(L, -2, "h");

    lua_pushnumber(L, (double)mode.density);
    lua_setfield(L, -2, "scale");

    lua_pushstring(L, [[NSString stringWithFormat:@"%dx%d@%.0fx", mode.width, mode.height, mode.density] UTF8String]);
    lua_setfield(L, -2, "desc");

    return 1;
}

/// hs.screen:availableModes() -> table
/// Method
/// Returns a table containing the screen modes supported by the screen. A screen mode is a combination of resolution, scaling factor and colour depth
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the supported screen modes. The keys of the table take the form of "1440x900@2x" (for a HiDPI mode) or "1680x1050@1x" (for a native DPI mode). The values are tables which contain the keys:
///   * w - A number containing the width of the screen mode in points
///   * h - A number containing the height of the screen mode in points
///   * scale - A number containing the scaling factor of the screen mode (typically `1` for a native mode, `2` for a HiDPI mode)
///
/// Notes:
///  * Only 32-bit colour modes are returned. If you really need to know about 16-bit modes, please file an Issue on GitHub
///  * "points" are not necessarily the same as pixels, because they take the scale factor into account (e.g. "1440x900@2x" is a 2880x1800 screen resolution, with a scaling factor of 2, i.e. with HiDPI pixel-doubled rendering enabled), however, they are far more useful to work with than native pixel modes, when a Retina screen is involved. For non-retina screens, points and pixels are equivalent.
static int screen_availableModes(lua_State* L) {
    NSScreen* screen = get_screen_arg(L, 1);
    CGDirectDisplayID screen_id = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] intValue];

    int i, numberOfDisplayModes;
    CGSGetNumberOfDisplayModes(screen_id, &numberOfDisplayModes);

    lua_newtable(L);

    for (i = 0; i < numberOfDisplayModes; i++)
    {
        CGSDisplayMode mode;
        CGSGetDisplayModeDescriptionOfLength(screen_id, i, &mode, sizeof(mode));

        // NSLog(@"Found a mode: %dx%d@%.0fx, %dbit", mode.width, mode.height, mode.density, (mode.depth == 4) ? 32 : 16);
        if (mode.depth == 4) {
            lua_newtable(L);

            lua_pushnumber(L, (double)mode.width);
            lua_setfield(L, -2, "w");

            lua_pushnumber(L, (double)mode.height);
            lua_setfield(L, -2, "h");

            lua_pushnumber(L, (double)mode.density);
            lua_setfield(L, -2, "scale");

            // Now push this mode table into the list-of-modes table
            lua_setfield(L, -2, [[NSString stringWithFormat:@"%dx%d@%.0fx", mode.width, mode.height, mode.density] UTF8String]);
        }
    }

    return 1;
}

/// hs.screen:setMode(width, height, scale) -> boolean
/// Method
/// Sets the screen to a new mode
///
/// Parameters:
///  * width - A number containing the width in points of the new mode
///  * height - A number containing the height in points of the new mode
///  * scale - A number containing the scaling factor of the new mode (typically 1 for native pixel resolutions, 2 for HiDPI/Retina resolutions)
///
/// Returns:
///  * A boolean, true if the requested mode was set, otherwise false
///
/// Notes:
///  * The available widths/heights/scales can be seen in the output of `hs.screen:availableModes()`, however, it should be noted that the CoreGraphics subsystem seems to list more modes for a given screen than it is actually prepared to set, so you may find that seemingly valid modes still return false. It is not currently understood why this is so!
static int screen_setMode(lua_State* L) {
    NSScreen* screen = get_screen_arg(L, 1);
    long width = luaL_checklong(L, 2);
    long height = luaL_checklong(L, 3);
    lua_Number scale = luaL_checknumber(L, 4);
    CGDirectDisplayID screen_id = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] intValue];

    int i, numberOfDisplayModes;
    CGSGetNumberOfDisplayModes(screen_id, &numberOfDisplayModes);

    for (i = 0; i < numberOfDisplayModes; i++) {
        CGSDisplayMode mode;
        CGSGetDisplayModeDescriptionOfLength(screen_id, i, &mode, sizeof(mode));

        if (mode.depth == 4 && mode.width == width && mode.height == height && mode.density == (float)scale) {
            CGDisplayConfigRef config;
            CGBeginDisplayConfiguration(&config);
            CGSConfigureDisplayMode(config, screen_id, i);
            CGError anError = CGCompleteDisplayConfiguration(config, kCGConfigurePermanently);
            if (anError == kCGErrorSuccess) {
                lua_pushboolean(L, true);
            } else {
                NSLog(@"ERROR: CGSConfigureDisplayMode failed: %d", anError);
                lua_pushboolean(L, false);
            }
            return 1;
        }
    }

    lua_pushboolean(L, false);
    return 1;
}

/// hs.screen.restoreGamma()
/// Function
/// Restore the gamma settings to defaults
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * This returns all displays to the gamma tables specified by the user's selected ColorSync display profiles
static int screen_gammaRestore(lua_State* L __unused) {
    CGDisplayRestoreColorSyncSettings();
    [currentGammas removeAllObjects];
    return 0;
}

/// hs.screen:getGamma() -> [whitepoint, blackpoint] or nil
/// Method
/// Gets the current whitepoint and blackpoint of the screen
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the white point and black point of the screen, or nil if an error occurred. The keys `whitepoint` and `blackpoint` each have values of a table containing the following keys, with corresponding values between 0.0 and 1.0:
///   * red
///   * green
///   * blue
static int screen_gammaGet(lua_State* L) {
    NSScreen* screen = get_screen_arg(L, 1);
    CGDirectDisplayID screen_id = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] intValue];
    uint32_t gammaCapacity = CGDisplayGammaTableCapacity(screen_id);
    uint32_t sampleCount;

    CGGammaValue redTable[gammaCapacity];
    CGGammaValue greenTable[gammaCapacity];
    CGGammaValue blueTable[gammaCapacity];

    if (CGGetDisplayTransferByTable(0, gammaCapacity, redTable, greenTable, blueTable, &sampleCount) != kCGErrorSuccess) {
        lua_pushnil(L);
        return 1;
    }

    lua_newtable(L);

    lua_pushstring(L, "blackpoint");
    lua_newtable(L);
        lua_pushstring(L, "red");
        lua_pushnumber(L, redTable[0]);
        lua_settable(L, -3);

        lua_pushstring(L, "green");
        lua_pushnumber(L, greenTable[0]);
        lua_settable(L, -3);

        lua_pushstring(L, "blue");
        lua_pushnumber(L, blueTable[0]);
        lua_settable(L, -3);

        lua_pushstring(L, "alpha");
        lua_pushnumber(L, 1.0);
        lua_settable(L, -3);
    lua_settable(L, -3);

    lua_pushstring(L, "whitepoint");
    lua_newtable(L);
        lua_pushstring(L, "red");
        lua_pushnumber(L, redTable[sampleCount-1]);
        lua_settable(L, -3);

        lua_pushstring(L, "green");
        lua_pushnumber(L, greenTable[sampleCount-1]);
        lua_settable(L, -3);

        lua_pushstring(L, "blue");
        lua_pushnumber(L, blueTable[sampleCount-1]);
        lua_settable(L, -3);
    lua_settable(L, -3);

    return 1;
}

void storeInitialScreenGamma(CGDirectDisplayID display) {
    uint32_t capacity = CGDisplayGammaTableCapacity(display);
    uint32_t count = 0;
    int i = 0;
    CGGammaValue redTable[capacity];
    CGGammaValue greenTable[capacity];
    CGGammaValue blueTable[capacity];

    CGError result = CGGetDisplayTransferByTable(display, capacity, redTable, greenTable, blueTable, &count);
    if (result == kCGErrorSuccess) {
        //NSLog(@"storeInitialScreenGamma: %i", display);
        NSMutableArray *red = [NSMutableArray arrayWithCapacity:capacity];
        NSMutableArray *green = [NSMutableArray arrayWithCapacity:capacity];
        NSMutableArray *blue = [NSMutableArray arrayWithCapacity:capacity];

        for (i = 0; i < (int)capacity; i++) {
            [red insertObject:[NSNumber numberWithFloat:redTable[i]] atIndex:i];
            [green insertObject:[NSNumber numberWithFloat:greenTable[i]] atIndex:i];
            [blue insertObject:[NSNumber numberWithFloat:blueTable[i]] atIndex:i];
        }

        NSDictionary *gammas = @{@"red":red,
                                 @"green":green,
                                 @"blue":blue};

        [originalGammas setObject:gammas forKey:[NSNumber numberWithInt:display]];
    } else {
        NSLog(@"storeInitialScreenGamma: ERROR: %i on display: %i", result, display);
    }
    return;
}

void getAllInitialScreenGammas() {
    // Get the number of displays
    CGDisplayCount numDisplays;
    CGGetActiveDisplayList(0, NULL, &numDisplays);

    // Fetch the gamma for each display
    CGDirectDisplayID displays[numDisplays];
    CGGetActiveDisplayList(numDisplays, displays, NULL);

    // Iterate each display and store its gamma
    //NSLog(@"getAllInitialScreenGammas(): Found %i displays", numDisplays);
    for (int i = 0; i < (int)numDisplays; ++i) {
        storeInitialScreenGamma(displays[i]);
    }
    return;
}

void screen_gammaReapply(CGDirectDisplayID display);
void displayReconfigurationCallback(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo __unused) {
    /*
    NSLog(@"displayReconfigurationCallback. Display: %i Flags: %i", display, flags);
    if (flags & kCGDisplayAddFlag) {
        NSLog(@"  display added");
    }
    if (flags & kCGDisplayRemoveFlag) {
        NSLog(@"  display removed");
    }
    if (flags & kCGDisplayBeginConfigurationFlag) {
        NSLog(@"  display beginConfiguration");
    }
    if (flags & kCGDisplayMovedFlag) {
        NSLog(@"  display moved");
    }
    if (flags & kCGDisplaySetMainFlag) {
        NSLog(@"  display set main");
    }
    if (flags & kCGDisplaySetModeFlag) {
        NSLog(@"  display set mode");
    }
    if (flags & kCGDisplayEnabledFlag) {
        NSLog(@"  display enabled");
    }
    if (flags & kCGDisplayDisabledFlag) {
        NSLog(@"  display disabled");
    }
    if (flags & kCGDisplayMirrorFlag) {
        NSLog(@"  display mirror");
    }
    if (flags & kCGDisplayUnMirrorFlag) {
        NSLog(@"  display unmirror");
    }
    if (flags & kCGDisplayDesktopShapeChangedFlag) {
        NSLog(@"  display desktopShapeChanged");
    }
    */

    if (flags & kCGDisplayAddFlag) {
        storeInitialScreenGamma(display);
    } else if (flags & kCGDisplayRemoveFlag) {
        [originalGammas removeObjectForKey:[NSNumber numberWithInt:display]];
        [currentGammas removeObjectForKey:[NSNumber numberWithInt:display]];
    } else if (flags & kCGDisplayDisabledFlag) {
        [currentGammas removeObjectForKey:[NSNumber numberWithInt:display]];
    } else if ((flags & kCGDisplayEnabledFlag) || (flags & kCGDisplayBeginConfigurationFlag)) {
        // NOOP
        ;
    } else {
        // Some kind of display reconfiguration that didn't involve any hardware coming or going, re-apply a gamma if we have one
        dispatch_async(notificationQueue, ^(void) {
            [NSThread sleepForTimeInterval:3]; // FIXME: This hard-coded sleep is awful, why do the screens get refreshed after this point?!
            //FIXME: Apply to all screens simultaneously
            screen_gammaReapply(display);
        });
    }

    return;
}

/// hs.screen:setGamma(whitepoint, blackpoint) -> boolean
/// Method
/// Sets the current white point and black point of the screen
///
/// Parameters:
///  * whitepoint - A table containing color component values between 0.0 and 1.0 for each of the keys:
///   * red
///   * green
///   * blue
///  * blackpoint - A table containing color component values between 0.0 and 1.0 for each of the keys:
///   * red
///   * green
///   * blue
///
/// Returns:
///  * A boolean, true if the gamma settings were applied, false if an error occurred
static int screen_gammaSet(lua_State* L) {
    NSScreen* screen = get_screen_arg(L, 1);
    luaL_checktype(L, 2, LUA_TTABLE);
    luaL_checktype(L, 3, LUA_TTABLE);
    CGDirectDisplayID screen_id = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] intValue];

    float whitePoint[3];
    float blackPoint[3];

    // First, fish out the whitepoint
    lua_getfield(L, 2, "red");
    whitePoint[0] = lua_tonumber(L, -1);
    lua_pop(L, 1);

    lua_getfield(L, 2, "green");
    whitePoint[1] = lua_tonumber(L, -1);
    lua_pop(L, 1);

    lua_getfield(L, 2, "blue");
    whitePoint[2] = lua_tonumber(L, -1);
    lua_pop(L, 1);

    if (whitePoint[0] == 0.0 && whitePoint[1] == 0.0 && whitePoint[2] == 0.0) {
        NSLog(@"screen_gammaSet: whitepoint is 0/0/0. Forcing to 1/1/1");
        whitePoint[0] = 1.0;
        whitePoint[1] = 1.0;
        whitePoint[2] = 1.0;
    }

    lua_getfield(L, 3, "red");
    blackPoint[0] = lua_tonumber(L, -1);
    lua_pop(L, 1);

    lua_getfield(L, 3, "green");
    blackPoint[1] = lua_tonumber(L, -1);
    lua_pop(L, 1);

    lua_getfield(L, 3, "blue");
    blackPoint[2] = lua_tonumber(L, -1);
    lua_pop(L, 1);

    if (blackPoint[0] == 1.0 && blackPoint[1] == 1.0 && blackPoint[2] == 1.0) {
        NSLog(@"screen_gammaSet: blackpoint is 1/1/1. Forcing to 0/0/0");
        blackPoint[0] = 0.0;
        blackPoint[1] = 0.0;
        blackPoint[2] = 0.0;
    }

    //NSLog(@"screen_gammaSet: Fetching original gamma for display: %i", screen_id);
    NSDictionary *originalGamma = [originalGammas objectForKey:[NSNumber numberWithInt:screen_id]];
    if (!originalGamma) {
        NSLog(@"screen_gammaSet: unable to fetch original gamma for display: %i", screen_id);
        lua_pushboolean(L, false);
        return 1;
    }
    NSArray *redArray = [originalGamma objectForKey:@"red"];
    NSArray *greenArray = [originalGamma objectForKey:@"green"];
    NSArray *blueArray = [originalGamma objectForKey:@"blue"];
    int count = [redArray count];
//    NSLog(@"screen_gammaSet: Found %i entries in the original gamma table", count);

    CGGammaValue redTable[count];
    CGGammaValue greenTable[count];
    CGGammaValue blueTable[count];
    NSMutableArray *red   = [NSMutableArray arrayWithCapacity:count];
    NSMutableArray *green = [NSMutableArray arrayWithCapacity:count];
    NSMutableArray *blue  = [NSMutableArray arrayWithCapacity:count];

    for (int i = 0; i < count; i++) {
        float origRed   = [[redArray objectAtIndex:i] floatValue];
        float origGreen = [[greenArray objectAtIndex:i] floatValue];
        float origBlue  = [[blueArray objectAtIndex:i] floatValue];

        float newRed   = blackPoint[0] + (whitePoint[0] - blackPoint[0]) * origRed;
        float newGreen = blackPoint[1] + (whitePoint[1] - blackPoint[1]) * origGreen;
        float newBlue  = blackPoint[2] + (whitePoint[2] - blackPoint[2]) * origBlue;

        redTable[i]   = newRed;
        greenTable[i] = newGreen;
        blueTable[i]  = newBlue;

        [red insertObject:[NSNumber numberWithFloat:redTable[i]] atIndex:i];
        [green insertObject:[NSNumber numberWithFloat:greenTable[i]] atIndex:i];
        [blue insertObject:[NSNumber numberWithFloat:blueTable[i]] atIndex:i];

        NSDictionary *gammas = @{@"red":red,
                                 @"green":green,
                                 @"blue":blue};

        [currentGammas setObject:gammas forKey:[NSNumber numberWithInt:screen_id]];

//        NSLog(@"screen_gammaSet: %i: R:%f G:%f B:%f (orig: R:%f G:%f B:%f)", screen_id, newRed, newGreen, newBlue, origRed, origGreen, origBlue);
    }

    CGError result = CGSetDisplayTransferByTable(screen_id, count, redTable, greenTable, blueTable);

    if (result != kCGErrorSuccess) {
        NSLog(@"screen_gammaSet: ERROR: %i on display %i", result, screen_id);
        lua_pushboolean(L, false);
        return 1;
    }

    lua_pushboolean(L, true);
    return 1;
}

void screen_gammaReapply(CGDirectDisplayID display) {
    NSDictionary *gammas = [currentGammas objectForKey:[NSNumber numberWithInt:display]];
    if (!gammas) {
        return;
    }

    NSArray *red =   [gammas objectForKey:@"red"];
    NSArray *green = [gammas objectForKey:@"green"];
    NSArray *blue =  [gammas objectForKey:@"blue"];

    int count = [red count];
    CGGammaValue redTable[count];
    CGGammaValue greenTable[count];
    CGGammaValue blueTable[count];

    for (int i = 0; i < count; i++) {
        redTable[i]   = [[red objectAtIndex:i] floatValue];
        greenTable[i] = [[green objectAtIndex:i] floatValue];
        blueTable[i]  = [[blue objectAtIndex:i] floatValue];
    }

    CGError result = CGSetDisplayTransferByTable(display, count, redTable, greenTable, blueTable);

    if (result != kCGErrorSuccess) {
        NSLog(@"screen_gammaReapply: ERROR: %i on display: %i", result, display);
    } else {
        //NSLog(@"screen_gammaReapply: Success");
    }

    return;
}

static int screen_gc(lua_State* L) {
    NSScreen* screen __unused = get_screen_arg(L, 1);
    return 0;
}

static int screen_eq(lua_State* L) {
    NSScreen* screenA = get_screen_arg(L, 1);
    NSScreen* screenB = get_screen_arg(L, 2);
    lua_pushboolean(L, [screenA isEqual: screenB]);
    return 1;
}

void new_screen(lua_State* L, NSScreen* screen) {
    void** screenptr = lua_newuserdata(L, sizeof(NSScreen**));
    *screenptr = (__bridge_retained void*)screen;

    luaL_getmetatable(L, "hs.screen");
    lua_setmetatable(L, -2);
}

/// hs.screen.allScreens() -> screen[]
/// Constructor
/// Returns all the screens there are.
static int screen_allScreens(lua_State* L) {
    lua_newtable(L);

    int i = 1;
    for (NSScreen* screen in [NSScreen screens]) {
        lua_pushnumber(L, i++);
        new_screen(L, screen);
        lua_settable(L, -3);
    }

    return 1;
}

/// hs.screen.mainScreen() -> screen
/// Constructor
/// Returns the 'main' screen, i.e. the one containing the currently focused window.
static int screen_mainScreen(lua_State* L) {
    new_screen(L, [NSScreen mainScreen]);
    return 1;
}

/// hs.screen:setPrimary(screen) -> nil
/// Function
/// Sets the screen to be the primary display (i.e. contain the menubar and dock)
static int screen_setPrimary(lua_State* L) {
    int deltaX, deltaY;

    CGDisplayErr dErr;
    CGDisplayCount maxDisplays = 32;
    CGDisplayCount displayCount, i;
    CGDirectDisplayID  onlineDisplays[maxDisplays];
    CGDisplayConfigRef config;

    NSScreen* screen = get_screen_arg(L, 1);
    CGDirectDisplayID targetDisplay = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] unsignedIntValue];
    CGDirectDisplayID mainDisplay = CGMainDisplayID();

    if (targetDisplay == mainDisplay)
        return 0;

    dErr = CGGetOnlineDisplayList(maxDisplays, onlineDisplays, &displayCount);
    if (dErr != kCGErrorSuccess) {
        // FIXME: Display some kind of error here
        return 0;
    }

    deltaX = -CGRectGetMinX(CGDisplayBounds(targetDisplay));
    deltaY = -CGRectGetMinY(CGDisplayBounds(targetDisplay));

    CGBeginDisplayConfiguration (&config);

    for (i = 0; i < displayCount; i++) {
        CGDirectDisplayID dID = onlineDisplays[i];

        CGConfigureDisplayOrigin(config, dID,
                                 CGRectGetMinX(CGDisplayBounds(dID)) + deltaX,
                                 CGRectGetMinY(CGDisplayBounds(dID)) + deltaY
                                );
    }

    CGCompleteDisplayConfiguration (config, kCGConfigureForSession);

    return 0;
}

/// hs.screen:rotate(degrees) -> bool
/// Method
/// Rotates the screen
///
/// Parameters:
///  * degrees - A number indicating how many degrees to rotate. This number must be one of:
///   * 0
///   * 90
///   * 180
///   * 270
///
/// Returns:
///  * A boolean, true if the operation succeeded, otherwise false
static int screen_rotate(lua_State* L) {
    NSScreen* screen = get_screen_arg(L, 1);
    CGDisplayCount maxDisplays = 32;
    CGDisplayCount displayCount, i;
    CGDirectDisplayID onlineDisplays[maxDisplays];
    int rot = lua_tointeger(L, 2);
    int rotation;

    switch (rot) {
        case 0:
            rotation = kIOScaleRotate0;
            break;
        case 90:
            rotation = kIOScaleRotate90;
            break;
        case 180:
            rotation = kIOScaleRotate180;
            break;
        case 270:
            rotation = kIOScaleRotate270;
            break;
        default:
            goto cleanup;
            break;
    }

    CGDirectDisplayID screenID = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] unsignedIntValue];
    if (CGGetOnlineDisplayList(maxDisplays, onlineDisplays, &displayCount) != kCGErrorSuccess) goto cleanup;

    for (i = 0; i < displayCount; i++) {
        CGDirectDisplayID dID = onlineDisplays[i];
        if (dID == screenID) {
            io_service_t service = CGDisplayIOServicePort(dID);
            IOOptionBits options = (0x00000400 | (rotation) << 16);
            if (IOServiceRequestProbe(service, options) != kCGErrorSuccess) goto cleanup;
            break;
        }
    }

    lua_pushboolean(L, true);
    return 1;

cleanup:
    lua_pushboolean(L, false);
    return 1;
}

static int screens_gc(lua_State* L __unused) {
    CGDisplayRemoveReconfigurationCallback(displayReconfigurationCallback, NULL);
    screen_gammaRestore(nil);
    return 0;
}

static const luaL_Reg screenlib[] = {
    {"allScreens", screen_allScreens},
    {"mainScreen", screen_mainScreen},
    {"restoreGamma", screen_gammaRestore},
    {"getGamma", screen_gammaGet},
    {"setGamma", screen_gammaSet},
    {"setPrimary", screen_setPrimary},
    {"rotate", screen_rotate},

    {"_frame", screen_frame},
    {"_visibleframe", screen_visibleframe},
    {"id", screen_id},
    {"name", screen_name},
    {"availableModes", screen_availableModes},
    {"currentMode", screen_currentMode},
    {"setMode", screen_setMode},

    {NULL, NULL}
};

static const luaL_Reg metalib[] = {
    {"__gc", screens_gc},

    {}
};

int luaopen_hs_screen_internal(lua_State* L) {
    // Start off by initialising gamma related structures, populating them and registering appropriate callbacks
    originalGammas = [[NSMutableDictionary alloc] init];
    currentGammas = [[NSMutableDictionary alloc] init];
    getAllInitialScreenGammas();
    notificationQueue = dispatch_queue_create("org.hammerspoon.Hammerspoon.gammaReapplyNotificationQueue", NULL);
    CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, NULL);

    luaL_newlib(L, screenlib);
    luaL_newlib(L, metalib);
    lua_setmetatable(L, -2);

    if (luaL_newmetatable(L, "hs.screen")) {
        lua_pushvalue(L, -2);
        lua_setfield(L, -2, "__index");

        lua_pushcfunction(L, screen_gc);
        lua_setfield(L, -2, "__gc");

        lua_pushcfunction(L, screen_eq);
        lua_setfield(L, -2, "__eq");
    }
    lua_pop(L, 1);

    return 1;
}
