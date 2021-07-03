#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>
#import <IOKit/graphics/IOGraphicsLib.h>
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG "hs.screen"

#define get_screen_arg(L, idx) (__bridge NSScreen*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Private API declarations

extern void CoreDisplay_Display_SetUserBrightness(CGDirectDisplayID id, double brightness)
    __attribute__((weak_import));
extern double CoreDisplay_Display_GetUserBrightness(CGDirectDisplayID)
    __attribute__((weak_import));

extern int DisplayServicesGetBrightness(CGDirectDisplayID display, float *brightness) __attribute__((weak_import));
extern int DisplayServicesSetBrightness(CGDirectDisplayID display, float brightness) __attribute__((weak_import));

#pragma mark - Module
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

/// hs.screen:id() -> number
/// Method
/// Returns a screen's unique ID
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the ID of the screen
static int screen_id(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    NSScreen* screen = get_screen_arg(L, 1);
    lua_pushinteger(L, [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] intValue]);

    return 1;
}

/// hs.screen:name() -> string or nil
/// Method
/// Returns the preferred name for the screen set by the manufacturer
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the name of the screen, or nil if an error occurred
static int screen_name(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    NSScreen* screen = get_screen_arg(L, 1);
    if (@available(macOS 10.15, *)) {
        [skin pushNSObject:screen.localizedName] ;
    } else {
        CGDirectDisplayID screen_id = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] intValue];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        CFDictionaryRef deviceInfo = IODisplayCreateInfoDictionary(CGDisplayIOServicePort(screen_id), kIODisplayOnlyPreferredName);
#pragma clang diagnostic pop
        NSDictionary *localizedNames = [(__bridge NSDictionary *)deviceInfo objectForKey:(NSString *)[NSString stringWithUTF8String:kDisplayProductName]];

        if ([localizedNames count])
            lua_pushstring(L, [[localizedNames objectForKey:[[localizedNames allKeys] objectAtIndex:0]] UTF8String]);
        else
            lua_pushnil(L);

        CFRelease(deviceInfo);
    }

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

// IOKit private APIs
enum {
    // from <IOKit/graphics/IOGraphicsTypesPrivate.h>
    kIOFBSetTransform = 0x00000400,
};

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
///   * freq - A number containing the vertical refresh rate in Hz
///   * depth - A number containing the bit depth
///   * desc - A string containing a representation of the mode as used in `hs.screen:availableModes()` - e.g. "1920x1080@2x 60Hz 4bpp"
static int screen_currentMode(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    NSScreen* screen = get_screen_arg(L, 1);
    CGDirectDisplayID screen_id = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] intValue];
    int currentModeNumber;
    CGSGetCurrentDisplayMode(screen_id, &currentModeNumber);
    CGSDisplayMode mode;
    CGSGetDisplayModeDescriptionOfLength(screen_id, currentModeNumber, &mode, sizeof(mode));

    lua_newtable(L);

    lua_pushinteger(L, mode.width);
    lua_setfield(L, -2, "w");

    lua_pushinteger(L, mode.height);
    lua_setfield(L, -2, "h");

    lua_pushnumber(L, (double)mode.density);
    lua_setfield(L, -2, "scale");

    lua_pushnumber(L, mode.freq);
    lua_setfield(L, -2, "freq");

    lua_pushnumber(L, mode.depth);
    lua_setfield(L, -2, "depth");

    lua_pushstring(L, [[NSString stringWithFormat:@"%dx%d@%.0fx %huHz %ubpp", mode.width, mode.height, (double)mode.density, mode.freq, mode.depth] UTF8String]);
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
///   * freq - A number containing the vertical refresh rate in Hz
///   * depth - A number containing the bit depth of the display mode
///
/// Notes:
///  * Prior to 0.9.83, only 32-bit colour modes would be returned, but now all colour depths are returned. This has necessitated changing the naming of the modes in the returned table.
///  * "points" are not necessarily the same as pixels, because they take the scale factor into account (e.g. "1440x900@2x" is a 2880x1800 screen resolution, with a scaling factor of 2, i.e. with HiDPI pixel-doubled rendering enabled), however, they are far more useful to work with than native pixel modes, when a Retina screen is involved. For non-retina screens, points and pixels are equivalent.
static int screen_availableModes(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    NSScreen* screen = get_screen_arg(L, 1);
    CGDirectDisplayID screen_id = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] intValue];

    int i, numberOfDisplayModes;
    CGSGetNumberOfDisplayModes(screen_id, &numberOfDisplayModes);

    lua_newtable(L);

    for (i = 0; i < numberOfDisplayModes; i++)
    {
        CGSDisplayMode mode;
        CGSGetDisplayModeDescriptionOfLength(screen_id, i, &mode, sizeof(mode));

        //NSLog(@"Found a mode: %dx%d@%.0fx, %huHz, %dbit", mode.width, mode.height, (double)mode.density, mode.freq, mode.depth);
        lua_newtable(L);

        lua_pushinteger(L, mode.width);
        lua_setfield(L, -2, "w");

        lua_pushinteger(L, mode.height);
        lua_setfield(L, -2, "h");

        lua_pushnumber(L, (double)mode.density);
        lua_setfield(L, -2, "scale");

        lua_pushnumber(L, mode.freq);
        lua_setfield(L, -2, "freq");

        lua_pushnumber(L, mode.depth);
        lua_setfield(L, -2, "depth");

        // Now push this mode table into the list-of-modes table
        lua_setfield(L, -2, [[NSString stringWithFormat:@"%dx%d@%.0fx %huHz %ubpp", mode.width, mode.height, (double)mode.density, mode.freq, mode.depth] UTF8String]);
    }

    return 1;
}

static int handleDisplayUpdate(lua_State* L, CGDisplayConfigRef config, char *name) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    CGError anError = CGCompleteDisplayConfiguration(config, kCGConfigurePermanently);
    if (anError == kCGErrorSuccess) {
        lua_pushboolean(L, true);
    } else {
        [skin logBreadcrumb:[NSString stringWithFormat:@"%s failed: %d", name, anError]];
        lua_pushboolean(L, false);
    }
    return 1;
}

/// hs.screen:setMode(width, height, scale, frequency, depth) -> boolean
/// Method
/// Sets the screen to a new mode
///
/// Parameters:
///  * width - A number containing the width in points of the new mode
///  * height - A number containing the height in points of the new mode
///  * scale - A number containing the scaling factor of the new mode (typically 1 for native pixel resolutions, 2 for HiDPI/Retina resolutions)
///  * frequency - A number containing the vertical refresh rate, in Hertz of the new mode
///  * depth - A number containing the bit depth of the new mode
///
/// Returns:
///  * A boolean, true if the requested mode was set, otherwise false
///
/// Notes:
///  * The available widths/heights/scales can be seen in the output of `hs.screen:availableModes()`, however, it should be noted that the CoreGraphics subsystem seems to list more modes for a given screen than it is actually prepared to set, so you may find that seemingly valid modes still return false. It is not currently understood why this is so!
static int screen_setMode(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TNUMBER, LS_TNUMBER, LS_TNUMBER, LS_TNUMBER, LS_TBREAK];

    NSScreen* screen = get_screen_arg(L, 1);
    long width = (long)lua_tointeger(L, 2);
    long height = (long)lua_tointeger(L, 3);
    lua_Number scale = lua_tonumber(L, 4);
    uint16_t freq = (uint16_t) lua_tointeger(L, 5);
    uint32_t depth = (uint32_t)lua_tointeger(L, 6);

    CGDirectDisplayID screen_id = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] intValue];

    int i, numberOfDisplayModes;
    CGSGetNumberOfDisplayModes(screen_id, &numberOfDisplayModes);

    for (i = 0; i < numberOfDisplayModes; i++) {
        CGSDisplayMode mode;
        CGSGetDisplayModeDescriptionOfLength(screen_id, i, &mode, sizeof(mode));

        if (mode.depth == depth && mode.freq == freq && mode.width == width && mode.height == height && (int)mode.density == (int)scale) {
            CGDisplayConfigRef config;
            CGBeginDisplayConfiguration(&config);
            CGSConfigureDisplayMode(config, screen_id, i);
            return handleDisplayUpdate(L, config, "CGConfigureDisplayOrigin");
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
static int screen_gammaRestore(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TANY|LS_TOPTIONAL, LS_TBREAK];

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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    NSScreen* screen = get_screen_arg(L, 1);
    CGDirectDisplayID screen_id = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] intValue];
    uint32_t gammaCapacity = CGDisplayGammaTableCapacity(screen_id);
    uint32_t sampleCount;

    CGGammaValue *redTable = malloc(sizeof(CGGammaValue) * gammaCapacity);
    CGGammaValue *greenTable = malloc(sizeof(CGGammaValue) * gammaCapacity);
    CGGammaValue *blueTable = malloc(sizeof(CGGammaValue) * gammaCapacity);

    if (CGGetDisplayTransferByTable(screen_id, gammaCapacity, redTable, greenTable, blueTable, &sampleCount) != kCGErrorSuccess) {
        free(redTable);
        free(greenTable);
        free(blueTable);
        lua_pushnil(L);
        return 1;
    }

    lua_newtable(L);

    lua_pushstring(L, "blackpoint");
    lua_newtable(L);
        lua_pushstring(L, "red");
        lua_pushnumber(L, (lua_Number)redTable[0]);
        lua_settable(L, -3);

        lua_pushstring(L, "green");
        lua_pushnumber(L, (lua_Number)greenTable[0]);
        lua_settable(L, -3);

        lua_pushstring(L, "blue");
        lua_pushnumber(L, (lua_Number)blueTable[0]);
        lua_settable(L, -3);

        lua_pushstring(L, "alpha");
        lua_pushnumber(L, 1.0);
        lua_settable(L, -3);
    lua_settable(L, -3);

    lua_pushstring(L, "whitepoint");
    lua_newtable(L);
        lua_pushstring(L, "red");
        lua_pushnumber(L, (lua_Number)redTable[sampleCount-1]);
        lua_settable(L, -3);

        lua_pushstring(L, "green");
        lua_pushnumber(L, (lua_Number)greenTable[sampleCount-1]);
        lua_settable(L, -3);

        lua_pushstring(L, "blue");
        lua_pushnumber(L, (lua_Number)blueTable[sampleCount-1]);
        lua_settable(L, -3);
    lua_settable(L, -3);

    free(redTable);
    free(greenTable);
    free(blueTable);

    return 1;
}

void storeInitialScreenGamma(CGDirectDisplayID display) {
    uint32_t capacity = CGDisplayGammaTableCapacity(display);
    uint32_t count = 0;
    int i = 0;
    CGGammaValue *redTable = malloc(sizeof(CGGammaValue) * capacity);
    CGGammaValue *greenTable = malloc(sizeof(CGGammaValue) * capacity);
    CGGammaValue *blueTable = malloc(sizeof(CGGammaValue) * capacity);

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
        [LuaSkin logBreadcrumb:[NSString stringWithFormat:@"storeInitialScreenGamma: ERROR %i on display %i", result, display]];
    }

    free(redTable);
    free(greenTable);
    free(blueTable);

    return;
}

void getAllInitialScreenGammas(void) {
    // Get the number of displays
    CGDisplayCount numDisplays;
    CGGetActiveDisplayList(0, NULL, &numDisplays);

    // Fetch the gamma for each display
    CGDirectDisplayID *displays = malloc(sizeof(CGDirectDisplayID) * numDisplays);
    CGGetActiveDisplayList(numDisplays, displays, NULL);

    // Iterate each display and store its gamma
    //NSLog(@"getAllInitialScreenGammas(): Found %i displays", numDisplays);
    for (int i = 0; i < (int)numDisplays; ++i) {
        storeInitialScreenGamma(displays[i]);
    }

    free(displays);

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
        // A display was added, remember its initial gamma
        storeInitialScreenGamma(display);
    } else if (flags & kCGDisplayRemoveFlag) {
        // A display was removed, forget its initial and current gammas
        [originalGammas removeObjectForKey:[NSNumber numberWithInt:display]];
        [currentGammas removeObjectForKey:[NSNumber numberWithInt:display]];
    } else if (flags & kCGDisplayDisabledFlag) {
        // A display was disabled, forget its current gamma
        [currentGammas removeObjectForKey:[NSNumber numberWithInt:display]];
    } else if ((flags & kCGDisplayEnabledFlag) || (flags & kCGDisplayBeginConfigurationFlag)) {
        // NOOP
        ;
    } else {
        // Some kind of display reconfiguration that didn't involve any hardware coming or going, re-apply a gamma if we have one
        // We seem to have to wait a few seconds for this to work, so we'll dispatch a delayed call, but run it on the main thread
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
///
/// Notes:
///  * If the whitepoint and blackpoint specified, are very similar, it will be impossible to read the screen. You should exercise caution, and may wish to bind a hotkey to `hs.screen.restoreGamma()` when experimenting
static int screen_gammaSet(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TTABLE, LS_TBREAK];

    NSScreen* screen = get_screen_arg(L, 1);
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

    lua_getfield(L, 3, "red");
    blackPoint[0] = lua_tonumber(L, -1);
    lua_pop(L, 1);

    lua_getfield(L, 3, "green");
    blackPoint[1] = lua_tonumber(L, -1);
    lua_pop(L, 1);

    lua_getfield(L, 3, "blue");
    blackPoint[2] = lua_tonumber(L, -1);
    lua_pop(L, 1);

    //NSLog(@"screen_gammaSet: Fetching original gamma for display: %i", screen_id);
    NSDictionary *originalGamma = [originalGammas objectForKey:[NSNumber numberWithInt:screen_id]];
    if (!originalGamma) {
        [skin logBreadcrumb:[NSString stringWithFormat:@"screen_gammaSet: unable to fetch original gamma for display: %i", screen_id]];
        lua_pushboolean(L, false);
        return 1;
    }
    NSArray *redArray = [originalGamma objectForKey:@"red"];
    NSArray *greenArray = [originalGamma objectForKey:@"green"];
    NSArray *blueArray = [originalGamma objectForKey:@"blue"];
    int count = (int)[redArray count];
//    NSLog(@"screen_gammaSet: Found %i entries in the original gamma table", count);

    CGGammaValue *redTable = malloc(sizeof(CGGammaValue) * count);
    CGGammaValue *greenTable = malloc(sizeof(CGGammaValue) * count);
    CGGammaValue *blueTable = malloc(sizeof(CGGammaValue) * count);

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

    free(redTable);
    free(greenTable);
    free(blueTable);

    if (result != kCGErrorSuccess) {
        [skin logBreadcrumb:[NSString stringWithFormat:@"screen_gammaSet: ERROR: %i on display %i", result, screen_id]];
        lua_pushboolean(L, false);
        return 1;
    }

    lua_pushboolean(L, true);
    return 1;
}

/// hs.screen:getBrightness() -> number or nil
/// Method
/// Gets the screen's brightness
///
/// Parameters:
///  * None
///
/// Returns:
///  * A floating point number between 0 and 1, containing the current brightness level, or nil if the display does not support brightness queries
static int screen_getBrightness(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    NSScreen* screen = get_screen_arg(L, 1);
    CGDirectDisplayID screen_id = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] intValue];

    if (DisplayServicesGetBrightness != NULL) {
        float brightness ;
        int err = DisplayServicesGetBrightness(screen_id, &brightness) ;
        if (err == kCGErrorSuccess) {
            lua_pushnumber(L, (lua_Number)brightness) ;
        } else {
            lua_pushnil(L);
        }
    } else if (CoreDisplay_Display_GetUserBrightness != NULL) {
        // Preferred API - interacts better with Night Shift, but is semi-private
        double brightness = CoreDisplay_Display_GetUserBrightness(screen_id);
        lua_pushnumber(L, brightness);
    } else {
        // Legacy API for people on older macOS
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        io_service_t service = CGDisplayIOServicePort(screen_id);
#pragma clang diagnostic pop
        CGDisplayErr err;

        float brightness;
        err = IODisplayGetFloatParameter(service, kNilOptions, CFSTR(kIODisplayBrightnessKey), &brightness);
        if (err != kIOReturnSuccess) {
            lua_pushnil(L);
        } else {
            lua_pushnumber(L, (lua_Number)brightness);
        }
    }
    return 1;
}

/// hs.screen:setBrightness(brightness) -> `hs.screen` object
/// Method
/// Sets the screen's brightness
///
/// Parameters:
///  * brightness - A floating point number between 0 and 1
///
/// Returns:
///  * The `hs.screen` object
static int screen_setBrightness(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK];

    NSScreen* screen = get_screen_arg(L, 1);
    CGDirectDisplayID screen_id = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] intValue];

    double brightness = lua_tonumber(L, 2);
    if (DisplayServicesSetBrightness != NULL) {
        DisplayServicesSetBrightness(screen_id, brightness) ;
    } else if (CoreDisplay_Display_SetUserBrightness != NULL) {
        // Preferred API - interacts better with Night Shift, but is semi-private
        CoreDisplay_Display_SetUserBrightness(screen_id, brightness);
    } else {
        // Legacy API for people on older macOS
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        io_service_t service = CGDisplayIOServicePort(screen_id);
#pragma clang diagnostic pop
        IODisplaySetFloatParameter(service, kNilOptions, CFSTR(kIODisplayBrightnessKey), brightness);
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.screen:getUUID() -> string
/// Method
/// Gets the UUID of an `hs.screen` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the UUID, or nil if an error occurred.
static int screen_getUUID(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    NSScreen *screen = get_screen_arg(L, 1);
    CGDirectDisplayID screen_id = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] intValue];

    CFUUIDRef cf_uuid = CGDisplayCreateUUIDFromDisplayID(screen_id);
    if (!cf_uuid) {
        lua_pushnil(L);
        return 1;
    }

    NSString *uuid = (__bridge_transfer NSString *)CFUUIDCreateString(NULL, cf_uuid);
    CFRelease(cf_uuid);

    [skin pushNSObject:uuid];
    return 1;
}

// CoreGraphics private APIs
CG_EXTERN bool CGDisplayUsesForceToGray(void);
CG_EXTERN void CGDisplayForceToGray(bool forceToGray);
CG_EXTERN bool CGDisplayUsesInvertedPolarity(void);
CG_EXTERN void CGDisplaySetInvertedPolarity(bool invertedPolarity);

/// hs.screen.getForceToGray() -> boolean
/// Method
/// Gets the screen's ForceToGray setting
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if the ForceToGray mode is set, otherwise false
static int screen_getForceToGray(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    bool isGrayscale = CGDisplayUsesForceToGray();
    lua_pushboolean(L, isGrayscale ? true : false);

    return 1;
}

/// hs.screen.setForceToGray(ForceToGray) -> None
/// Method
/// Sets the screen's ForceToGray mode
///
/// Parameters:
///  * ForceToGray - A boolean if ForceToGray mode should be enabled
///
/// Returns:
///  * None
static int screen_setForceToGray(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBOOLEAN, LS_TBREAK];

    int forceGrayscale = lua_toboolean(L, 1);
    CGDisplayForceToGray(forceGrayscale ? true : false);

    return 0;
}

/// hs.screen.getInvertedPolarity() -> boolean
/// Method
/// Gets the screen's InvertedPolarity setting
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if the InvertedPolarity mode is set, otherwise false
static int screen_getInvertedPolarity(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    bool isInvertedPolarity = CGDisplayUsesInvertedPolarity();
    lua_pushboolean(L, isInvertedPolarity ? true : false);

    return 1;
}

/// hs.screen.setInvertedPolarity(InvertedPolarity) -> None
/// Method
/// Sets the screen's InvertedPolarity mode
///
/// Parameters:
///  * InvertedPolarity - A boolean if InvertedPolarity mode should be enabled
///
/// Returns:
///  * None
static int screen_setInvertedPolarity(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBOOLEAN, LS_TBREAK];

    int forceInvertedPolarity = lua_toboolean(L, 1);
    CGDisplaySetInvertedPolarity(forceInvertedPolarity ? true : false);

    return 0;
}

void screen_gammaReapply(CGDirectDisplayID display) {
    NSDictionary *gammas = [currentGammas objectForKey:[NSNumber numberWithInt:display]];
    if (!gammas) {
        return;
    }

    NSArray *red =   [gammas objectForKey:@"red"];
    NSArray *green = [gammas objectForKey:@"green"];
    NSArray *blue =  [gammas objectForKey:@"blue"];

    int count = (int)[red count];

    CGGammaValue *redTable = malloc(sizeof(CGGammaValue) * count);
    CGGammaValue *greenTable = malloc(sizeof(CGGammaValue) * count);
    CGGammaValue *blueTable = malloc(sizeof(CGGammaValue) * count);

    for (int i = 0; i < count; i++) {
        redTable[i]   = [[red objectAtIndex:i] floatValue];
        greenTable[i] = [[green objectAtIndex:i] floatValue];
        blueTable[i]  = [[blue objectAtIndex:i] floatValue];
    }

    CGError result = CGSetDisplayTransferByTable(display, count, redTable, greenTable, blueTable);

    if (result != kCGErrorSuccess) {
        [LuaSkin logBreadcrumb:[NSString stringWithFormat:@"screen_gammaReapply: ERROR: %i on display: %i", result, display]];
    } else {
        //NSLog(@"screen_gammaReapply: Success");
    }

    free(redTable);
    free(greenTable);
    free(blueTable);

    return;
}

static int screen_gc(lua_State* L) {
    NSScreen* screen __unused = (__bridge_transfer NSScreen*)*((void**)luaL_checkudata(L, 1, USERDATA_TAG));
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

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
}

/// hs.screen.allScreens() -> hs.screen[]
/// Constructor
/// Returns all the screens
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing one or more `hs.screen` objects
static int screen_allScreens(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    lua_newtable(L);

    int i = 1;
    for (NSScreen* screen in [NSScreen screens]) {
        lua_pushinteger(L, i++);
        new_screen(L, screen);
        lua_settable(L, -3);
    }

    return 1;
}

/// hs.screen.mainScreen() -> screen
/// Constructor
/// Returns the 'main' screen, i.e. the one containing the currently focused window
///
/// Parameters:
///  * None
///
/// Returns:
///  * An `hs.screen` object
static int screen_mainScreen(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    new_screen(L, [NSScreen mainScreen]);

    return 1;
}

/// hs.screen:setPrimary() -> boolean
/// Method
/// Sets the screen to be the primary display (i.e. contain the menubar and dock)
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if the operation succeeded, otherwise false
static int screen_setPrimary(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    int deltaX, deltaY;

    CGDisplayErr dErr;
    CGDisplayCount maxDisplays = 32;
    CGDisplayCount displayCount, i;

    CGDirectDisplayID *onlineDisplays = malloc(sizeof(CGDirectDisplayID) * maxDisplays);
    CGDisplayConfigRef config;

    NSScreen* screen = get_screen_arg(L, 1);
    CGDirectDisplayID targetDisplay = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] unsignedIntValue];
    CGDirectDisplayID mainDisplay = CGMainDisplayID();

    if (targetDisplay == mainDisplay) {
        // NO-OP, we're already on the main display
        free(onlineDisplays);
        lua_pushboolean(L, true);
        return 1;
    }

    dErr = CGGetOnlineDisplayList(maxDisplays, onlineDisplays, &displayCount);
    if (dErr != kCGErrorSuccess) {
        free(onlineDisplays);
        lua_pushboolean(L, false);
        return 1;
    }

    deltaX = -CGRectGetMinX(CGDisplayBounds(targetDisplay));
    deltaY = -CGRectGetMinY(CGDisplayBounds(targetDisplay));

    dErr = CGBeginDisplayConfiguration (&config);
    if (dErr != kCGErrorSuccess) {
        free(onlineDisplays);
        lua_pushboolean(L, false);
        return 1;
    }

    for (i = 0; i < displayCount; i++) {
        CGDirectDisplayID dID = onlineDisplays[i];

        dErr = CGConfigureDisplayOrigin(config, dID,
                                        CGRectGetMinX(CGDisplayBounds(dID)) + deltaX,
                                        CGRectGetMinY(CGDisplayBounds(dID)) + deltaY
                                       );
        if (dErr != kCGErrorSuccess) {
            free(onlineDisplays);
            CGCancelDisplayConfiguration(config);
            lua_pushboolean(L, false);
            return 1;
        }
    }

    CGCompleteDisplayConfiguration (config, kCGConfigureForSession);

    free(onlineDisplays);

    lua_pushboolean(L, true);
    return 1;
}

/// hs.screen:rotate([degrees]) -> bool or rotation angle
/// Method
/// Gets/Sets the rotation of a screen
///
/// Parameters:
///  * degrees - An optional number indicating how many degrees clockwise, to rotate. If no number is provided, the current rotation will be returned. This number must be one of:
///   * 0
///   * 90
///   * 180
///   * 270
///
/// Returns:
///  * If the rotation is being set, a boolean, true if the operation succeeded, otherwise false. If the rotation is being queried, a number will be returned
static int screen_rotate(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER|LS_TOPTIONAL, LS_TBREAK];

    NSScreen* screen = get_screen_arg(L, 1);
    CGDisplayCount maxDisplays = 32;
    CGDisplayCount displayCount, i;
    CGDirectDisplayID *onlineDisplays = NULL;

    int rotation = -1;

    if (lua_type(L, 2) == LUA_TNUMBER) {
        switch ((int)lua_tointeger(L, 2)) {
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
        }
    }

    CGDirectDisplayID screenID = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] unsignedIntValue];

    if (rotation == -1) {
        double currentRotation = CGDisplayRotation(screenID);
        NSLog(@"Found rotation: %f", currentRotation);
        lua_pushinteger(L, (int)currentRotation);
        return 1;
    }

    onlineDisplays = malloc(sizeof(CGDirectDisplayID) * maxDisplays);
    if (CGGetOnlineDisplayList(maxDisplays, onlineDisplays, &displayCount) != kCGErrorSuccess) goto cleanup;

    for (i = 0; i < displayCount; i++) {
        CGDirectDisplayID dID = onlineDisplays[i];
        if (dID == screenID) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            io_service_t service = CGDisplayIOServicePort(dID);
#pragma clang diagnostic pop
            IOOptionBits options = (kIOFBSetTransform | (rotation) << 16);
            if (IOServiceRequestProbe(service, options) != kCGErrorSuccess) goto cleanup;
            break;
        }
    }

    free(onlineDisplays);

    lua_pushboolean(L, true);
    return 1;

cleanup:
    free(onlineDisplays);
    lua_pushboolean(L, false);
    return 1;
}

/// hs.screen:setOrigin(x, y) -> bool
/// Method
/// Sets the origin of a screen in the global display coordinate space. The origin of the main or primary display is (0,0). The new origin is placed as close as possible to the requested location, without overlapping or leaving a gap between displays. If you use this function to change the origin of a mirrored display, the display may be removed from the mirroring set.
///
/// Parameters:
///  * x - The desired x-coordinate for the upper-left corner of the display.
///  * y - The desired y-coordinate for the upper-left corner of the display.
///
/// Returns:
///  * true if the operation succeeded, otherwise false
static int screen_setOrigin(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TNUMBER, LS_TBREAK];

    NSScreen* screen = get_screen_arg(L, 1);
    int x = (int)lua_tointeger(L, 2);
    int y = (int)lua_tointeger(L, 3);

    CGDisplayCount maxDisplays = 32;
    CGDisplayCount displayCount, i;
    CGDirectDisplayID *onlineDisplays = NULL;
    CGDirectDisplayID screenID = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] unsignedIntValue];
    onlineDisplays = malloc(sizeof(CGDirectDisplayID) * maxDisplays);
    if (CGGetOnlineDisplayList(maxDisplays, onlineDisplays, &displayCount) != kCGErrorSuccess) goto cleanup;

    CGDisplayConfigRef config;
    CGBeginDisplayConfiguration(&config);
    for (i = 0; i < displayCount; i++) {
        CGDirectDisplayID dID = onlineDisplays[i];
        if (dID == screenID) {
            CGConfigureDisplayOrigin(config, dID, x, y);
        }
    }

    free(onlineDisplays);
    return handleDisplayUpdate(L, config, "CGConfigureDisplayOrigin");

cleanup:
    free(onlineDisplays);
    lua_pushboolean(L, false);
    return 1;
}

/// hs.screen:mirrorOf(aScreen[, permanent]) -> bool
/// Method
/// Make this screen mirror another
///
/// Parameters:
///  * aScreen - an hs.screen object you wish to mirror
///  * permament - an optional bool, true if this should be configured permanently, false if it should apply just for this login session. Defaults to false.
///
/// Returns:
///  * true if the operation succeeded, otherwise false
static int screen_mirrorOf(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN|LS_TOPTIONAL, LS_TBREAK];

    NSScreen *mirrorTarget = get_screen_arg(L, 1);
    NSScreen *mirrorSource = get_screen_arg(L, 2);

    BOOL permanent = lua_toboolean(L, 3);

    CGDirectDisplayID sourceID = [[[mirrorSource deviceDescription] objectForKey:@"NSScreenNumber"] unsignedIntValue];
    CGDirectDisplayID targetID = [[[mirrorTarget deviceDescription] objectForKey:@"NSScreenNumber"] unsignedIntValue];

    CGDisplayConfigRef config;
    CGError result;

    CGBeginDisplayConfiguration(&config);
    result = CGConfigureDisplayMirrorOfDisplay(config, targetID, sourceID);
    CGCompleteDisplayConfiguration(config, permanent ? kCGConfigurePermanently : kCGConfigureForSession);

    lua_pushboolean(L, result == kCGErrorSuccess);
    return 1;
}

/// hs.screen:mirrorStop([permanent]) -> bool
/// Method
/// Stops this screen mirroring another
///
/// Parameters:
///  * permanent - an optional bool, true if this should be configured permanently, false if it should apply just for this login session. Defaults to false.
///
/// Returns:
///  * true if the operation succeeded, otherwise false
static int screen_mirrorStop(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN|LS_TOPTIONAL, LS_TBREAK];

    NSScreen *screen = get_screen_arg(L, 1);

    BOOL permanent = lua_toboolean(L, 2);

    CGDirectDisplayID screenID = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] unsignedIntValue];

    CGDisplayConfigRef config;
    CGError result;

    CGBeginDisplayConfiguration(&config);
    result = CGConfigureDisplayMirrorOfDisplay(config, screenID, kCGNullDirectDisplay);
    CGCompleteDisplayConfiguration(config, permanent ? kCGConfigurePermanently : kCGConfigureForSession);

    lua_pushboolean(L, result == kCGErrorSuccess);
    return 1;
}

NSRect screenRectToNSRect(lua_State *L, int idx) {
    NSRect rect = NSZeroRect;
    CGFloat x = -1;
    CGFloat y = -1;
    CGFloat w = -1;
    CGFloat h = -1;

    if (lua_isnoneornil(L, idx) || lua_type(L, idx) != LUA_TTABLE) {
        goto cleanup;
    }

    lua_getfield(L, idx, "x");
    if (lua_type(L, -1) == LUA_TNUMBER) {
        x = lua_tonumber(L, -1);
    }

    lua_getfield(L, idx, "y");
    if (lua_type(L, -1) == LUA_TNUMBER) {
        y = lua_tonumber(L, -1);
    }

    lua_getfield(L, idx, "w");
    if (lua_type(L, -1) == LUA_TNUMBER) {
        w = lua_tonumber(L, -1);
    }

    lua_getfield(L, idx, "h");
    if (lua_type(L, -1) == LUA_TNUMBER) {
        h = lua_tonumber(L, -1);
    }

    lua_pop(L, 4);

    if ((int)x == -1 || (int)y == -1 || (int)w == -1 || (int)h == -1) {
        goto cleanup;
    }

    rect = NSMakeRect(x, y, w, h);

cleanup:
    return rect;
}

NSImage *screenToNSImage(NSScreen *screen, NSRect screenRect) {
    CGDirectDisplayID screenID = 0;
    CGImageRef cgImage = NULL;
    NSImage *theImage = nil;

    screenID = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] unsignedIntValue];
    cgImage = CGDisplayCreateImageForRect(screenID, (NSIsEmptyRect(screenRect)) ? CGRectMake(0, 0, [screen frame].size.width, [screen frame].size.height) : screenRect);
    if (!cgImage) goto cleanup;

    theImage = [[NSImage alloc] initWithCGImage:cgImage size:NSZeroSize];

cleanup:
    if (cgImage) {
        CGImageRelease(cgImage);
    }

    return theImage;
}

/// hs.screen:snapshot([rect]) -> object
/// Method
/// Captures an image of the screen
///
/// Parameters:
///  * rect - An optional `rect-table` containing a portion of the screen to capture. Defaults to the whole screen
///
/// Returns:
///  * An `hs.image` object, or nil if an error occurred
static int screen_snapshot(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE|LS_TNIL|LS_TOPTIONAL, LS_TBREAK];

    NSScreen *screen = get_screen_arg(L, 1);
    NSRect rect = screenRectToNSRect(L, 2);
    NSImage *image = screenToNSImage(screen, rect);
    if (image) {
        [skin pushNSObject:image];
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.screen:desktopImageURL([imageURL])
/// Method
/// Gets/Sets the desktop background image for a screen
///
/// Parameters:
///  * imageURL - An optional file:// URL to an image file to set as the background. If omitted, the current file URL is returned
///
/// Returns:
///  * the `hs.screen` object if a new URL was set, otherwise a string containing the current URL
///
/// Notes:
///  * If the user has set a folder of pictures to be alternated as the desktop background, the path to that folder will be returned.
static int screen_desktopImageURL(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK];

    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSScreen *screen = get_screen_arg(L, 1);

    NSString *url = nil;
    if (lua_type(L, 2) == LUA_TSTRING) {
        url = [skin toNSObjectAtIndex:2];
    }

    if (url) {
        NSError *error;
        NSURL *realURL = [NSURL URLWithString:url];

        if (realURL) {
            [workspace setDesktopImageURL:realURL forScreen:screen options:@{} error:&error];
            if (error) {
                [skin logError:[error localizedDescription]];
            }
        }
        lua_pushvalue(L, 1);
    } else {
        lua_pushstring(L, [[[workspace desktopImageURLForScreen:screen] absoluteString] UTF8String]);
    }

    return 1;
}

/// hs.screen.accessibilitySettings() -> table
/// Function
/// Gets the current state of the screen-related accessibility settings
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the following keys, and corresponding boolean values for whether the user has enabled these options:
///    * ReduceMotion (only available on macOS 10.12 or later)
///    * ReduceTransparency
///    * IncreaseContrast
///    * InvertColors (only available on macOS 10.12 or later)
///    * DifferentiateWithoutColor
static int screen_accessibilitySettings(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    NSMutableDictionary *settings = [[NSMutableDictionary alloc] initWithCapacity:5];

    if ([[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 12, 0}]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wpartial-availability"
        [settings setObject:[NSNumber numberWithBool:ws.accessibilityDisplayShouldInvertColors] forKey:@"InvertColors"];
        [settings setObject:[NSNumber numberWithBool:ws.accessibilityDisplayShouldReduceMotion] forKey:@"ReduceMotion"];
#pragma clang diagnostic pop
    }

    [settings setObject:[NSNumber numberWithBool:ws.accessibilityDisplayShouldReduceTransparency] forKey:@"ReduceTransparency"];
    [settings setObject:[NSNumber numberWithBool:ws.accessibilityDisplayShouldIncreaseContrast] forKey:@"IncreaseContrast"];
    [settings setObject:[NSNumber numberWithBool:ws.accessibilityDisplayShouldDifferentiateWithoutColor] forKey:@"DifferentiateWithoutColor"];

    [skin pushNSObject:settings];
    return 1;
}

static int screens_gc(lua_State* L) {
    CGDisplayRemoveReconfigurationCallback(displayReconfigurationCallback, NULL);
    screen_gammaRestore(L);

    return 0;
}

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    NSString *theName = @"(un-named screen)" ;
    NSScreen *screen = get_screen_arg(L, 1);

    if (@available(macOS 10.15, *)) {
        theName = screen.localizedName ;
    } else {
        CGDirectDisplayID screen_id = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] intValue];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        CFDictionaryRef deviceInfo = IODisplayCreateInfoDictionary(CGDisplayIOServicePort(screen_id), kIODisplayOnlyPreferredName);
#pragma clang diagnostic pop
        NSDictionary *localizedNames = [(__bridge NSDictionary *)deviceInfo objectForKey:(NSString *)[NSString stringWithUTF8String:kDisplayProductName]];
        if ([localizedNames count])
            theName = [localizedNames objectForKey:[[localizedNames allKeys] objectAtIndex:0]] ;
        CFRelease(deviceInfo);
    }

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, theName, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static const luaL_Reg screenlib[] = {
    {"allScreens", screen_allScreens},
    {"mainScreen", screen_mainScreen},
    {"restoreGamma", screen_gammaRestore},
    {"accessibilitySettings", screen_accessibilitySettings},
    {"getForceToGray", screen_getForceToGray},
    {"setForceToGray", screen_setForceToGray},
    {"getInvertedPolarity", screen_getInvertedPolarity},
    {"setInvertedPolarity", screen_setInvertedPolarity},

    {NULL, NULL}
};

static const luaL_Reg screen_objectlib[] = {
    {"_frame", screen_frame},
    {"_visibleframe", screen_visibleframe},
    {"id", screen_id},
    {"name", screen_name},
    {"availableModes", screen_availableModes},
    {"currentMode", screen_currentMode},
    {"setMode", screen_setMode},
    {"snapshot", screen_snapshot},
    {"getGamma", screen_gammaGet},
    {"setGamma", screen_gammaSet},
    {"getBrightness", screen_getBrightness},
    {"setBrightness", screen_setBrightness},
    {"getUUID", screen_getUUID},
    {"rotate", screen_rotate},
    {"setPrimary", screen_setPrimary},
    {"desktopImageURL", screen_desktopImageURL},
    {"setOrigin", screen_setOrigin},
    {"mirrorOf", screen_mirrorOf},
    {"mirrorStop", screen_mirrorStop},

    {"__tostring", userdata_tostring},
    {"__gc", screen_gc},
    {"__eq", screen_eq},

    {NULL, NULL}
};

static const luaL_Reg metalib[] = {
    {"__gc", screens_gc},

    {NULL, NULL}
};

int luaopen_hs_screen_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    // Start off by initialising gamma related structures, populating them and registering appropriate callbacks
    originalGammas = [[NSMutableDictionary alloc] init];
    currentGammas = [[NSMutableDictionary alloc] init];
    getAllInitialScreenGammas();
    notificationQueue = dispatch_queue_create("org.hammerspoon.Hammerspoon.gammaReapplyNotificationQueue", NULL);
    CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallback, NULL);

    [skin registerLibrary:USERDATA_TAG functions:screenlib metaFunctions:metalib];
    [skin registerObject:USERDATA_TAG objectFunctions:screen_objectlib];

    return 1;
}
