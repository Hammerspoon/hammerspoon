#import "../drawing.h"

static int refTable ;
static int colorCollectionsTable ;

/// hs.drawing.color.lists() -> table
/// Function
/// Returns a table containing the system color lists and hs.drawing.color collections with their defined colors.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table whose keys are made from the currently defined system color lists and hs.drawing.color collections.  Each color list key refers to a table whose keys make up the colors provided by the specific color list.
///
/// Notes:
///  * Where possible, each color node is provided as its RGB color representation.  Where this is not possible, the color node contains the keys `list` and `name` which identify the indicated color.  This means that you can use the following wherever a color parameter is expected: `hs.drawing.color.lists()["list-name"]["color-name"]`
///  * This function provides a tostring metatable method which allows listing the defined color lists in the Hammerspoon console with: `hs.drawing.color.lists()`
///  * See also `hs.drawing.color.colorsFor`
static int getColorLists(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TBREAK] ;

    lua_newtable(L) ;
    for (NSColorList *colorList in [NSColorList availableColorLists]) {
        [[LuaSkin shared] pushNSObject:colorList] ;
        lua_setfield(L, -2, [[colorList name] UTF8String]) ;
    }
    return 1 ;
}

/// hs.drawing.color.asRGB(color) -> table | string
/// Function
/// Returns a table containing the RGB representation of the specified color.
///
/// Parameters:
///  * color - a table specifying a color as described in the module definition (see `hs.drawing.color` in the online help or Dash documentation)
///
/// Returns:
///  * a table containing the red, blue, green, and alpha keys representing the specified color as RGB or a string describing the color's colorspace if conversion is not possible.
///
/// Notes:
///  * See also `hs.drawing.color.asHSB`
static int colorAsRGB(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TTABLE, LS_TBREAK] ;
    NSColor *theColor = [[LuaSkin shared] luaObjectAtIndex:1 toClass:"NSColor"] ;

    NSColor *safeColor = [theColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace] ;

    if (safeColor) {
        lua_newtable(L) ;
          lua_pushnumber(L, [safeColor redComponent])   ; lua_setfield(L, -2, "red") ;
          lua_pushnumber(L, [safeColor greenComponent]) ; lua_setfield(L, -2, "green") ;
          lua_pushnumber(L, [safeColor blueComponent])  ; lua_setfield(L, -2, "blue") ;
          lua_pushnumber(L, [safeColor alphaComponent]) ; lua_setfield(L, -2, "alpha") ;
    } else {
        lua_pushstring(L, [[NSString stringWithFormat:@"unable to convert colorspace from %@ to NSCalibratedRGBColorSpace", [theColor colorSpaceName]] UTF8String]) ;
    }

    return 1 ;
}

/// hs.drawing.color.asHSB(color) -> table | string
/// Function
/// Returns a table containing the HSB representation of the specified color.
///
/// Parameters:
///  * color - a table specifying a color as described in the module definition (see `hs.drawing.color` in the online help or Dash documentation)
///
/// Returns:
///  * a table containing the hue, saturation, brightness, and alpha keys representing the specified color as HSB or a string describing the color's colorspace if conversion is not possible.
///
/// Notes:
///  * See also `hs.drawing.color.asRGB`
static int colorAsHSB(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TTABLE, LS_TBREAK] ;
    NSColor *theColor = [[LuaSkin shared] luaObjectAtIndex:1 toClass:"NSColor"] ;

    NSColor *safeColor = [theColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace] ;

    if (safeColor) {
        lua_newtable(L) ;
          lua_pushnumber(L, [safeColor hueComponent])        ; lua_setfield(L, -2, "hue") ;
          lua_pushnumber(L, [safeColor saturationComponent]) ; lua_setfield(L, -2, "saturation") ;
          lua_pushnumber(L, [safeColor brightnessComponent]) ; lua_setfield(L, -2, "brightness") ;
          lua_pushnumber(L, [safeColor alphaComponent])      ; lua_setfield(L, -2, "alpha") ;
    } else {
        lua_pushstring(L, [[NSString stringWithFormat:@"unable to convert colorspace from %@ to NSCalibratedRGBColorSpace", [theColor colorSpaceName]] UTF8String]) ;
    }

    return 1 ;
}

// [[LuaSkin shared] pushNSObject:NSColor]
// C-API
// Pushes the provided NSColor onto the Lua Stack as an array meeting the color table description provided in `hs.drawing.color`
static int NSColor_tolua(lua_State *L, id obj) {
    NSColor *theColor = obj ;
    NSColor *safeColor = [theColor colorUsingColorSpaceName:NSCalibratedRGBColorSpace] ;

    if (safeColor) {
        lua_newtable(L) ;
          lua_pushnumber(L, [safeColor redComponent])   ; lua_setfield(L, -2, "red") ;
          lua_pushnumber(L, [safeColor greenComponent]) ; lua_setfield(L, -2, "green") ;
          lua_pushnumber(L, [safeColor blueComponent])  ; lua_setfield(L, -2, "blue") ;
          lua_pushnumber(L, [safeColor alphaComponent]) ; lua_setfield(L, -2, "alpha") ;
    } else if ([[theColor colorSpaceName] isEqualToString:NSNamedColorSpace]) {
        lua_newtable(L) ;
          [[LuaSkin shared] pushNSObject:[theColor catalogNameComponent]] ;
          lua_setfield(L, -2, "list") ;
          [[LuaSkin shared] pushNSObject:[theColor colorNameComponent]] ;
          lua_setfield(L, -2, "name") ;
    } else {
        lua_pushstring(L, [[NSString stringWithFormat:@"unable to convert colorspace from %@ to NSCalibratedRGBColorSpace", [theColor colorSpaceName]] UTF8String]) ;
    }

    return 1 ;
}

// [[LuaSkin shared] pushNSObject:NSColorList]
// C-API
// Pushes the provided NSColorList onto the Lua Stack as a table of color tables meeting the color table description provided in `hs.drawing.color`
static int NSColorList_tolua(lua_State *L, id obj) {
    NSColorList *colorList = obj ;

    lua_newtable(L) ;
    for (id key in [colorList allKeys]) {
        [[LuaSkin shared] pushNSObject:[colorList colorWithKey:key]] ;
        lua_setfield(L, -2, [key UTF8String]) ;
    }

    return 1 ;
}

#define COLOR_LOOP_LEVEL 10
static id table_toNSColorHelper(lua_State *L, int idx, int level) {
    LuaSkin *skin = [LuaSkin shared] ;
    CGFloat red = 0.0, green = 0.0, blue = 0.0, alpha = 1.0 ;
    CGFloat hue = 0.0, saturation = 0.0, brightness = 0.0 ;
    CGFloat white = 0.0 ;

    BOOL RGBColor = YES ;

// arbitrary cutoff to prevent infinite loop in table lookups
    if (level < COLOR_LOOP_LEVEL) {
        NSString *colorList, *colorName ;

        switch (lua_type(L, idx)) {
            case LUA_TTABLE:
                if (lua_getfield(L, idx, "list") == LUA_TSTRING)
                    colorList = [skin toNSObjectAtIndex:-1] ;
                lua_pop(L, 1) ;
                if (lua_getfield(L, idx, "name") == LUA_TSTRING)
                    colorName = [skin toNSObjectAtIndex:-1] ;
                lua_pop(L, 1) ;

                if (lua_getfield(L, idx, "red") == LUA_TNUMBER)
                    red = lua_tonumber(L, -1);
                lua_pop(L, 1);
                if (lua_getfield(L, idx, "green") == LUA_TNUMBER)
                    green = lua_tonumber(L, -1);
                lua_pop(L, 1);
                if (lua_getfield(L, idx, "blue") == LUA_TNUMBER)
                    blue = lua_tonumber(L, -1);
                lua_pop(L, 1);

                if (lua_getfield(L, idx, "hue") == LUA_TNUMBER) {
                    hue = lua_tonumber(L, -1);
                    RGBColor = NO ;
                }
                lua_pop(L, 1);
                if (lua_getfield(L, idx, "saturation") == LUA_TNUMBER)
                    saturation = lua_tonumber(L, -1);
                lua_pop(L, 1);
                if (lua_getfield(L, idx, "brightness") == LUA_TNUMBER)
                    brightness = lua_tonumber(L, -1);
                lua_pop(L, 1);

                if (lua_getfield(L, idx, "white") == LUA_TNUMBER)
                    white = lua_tonumber(L, -1);
                lua_pop(L, 1);

                if (lua_getfield(L, idx, "alpha") == LUA_TNUMBER)
                    alpha = lua_tonumber(L, -1);
                lua_pop(L, 1);

                break;
            default:
                [skin logAtLevel:LS_LOG_ERROR
                     withMessage:[NSString stringWithFormat:@"returning BLACK, unexpected type passed as a color: %s", lua_typename(L, lua_type(L, idx))]
                    fromStackPos:1] ;
        }

        if (colorList && colorName) {
            NSColor *holding = [[NSColorList colorListNamed:colorList] colorWithKey:colorName] ;
            if (holding) return holding ;
            if (colorCollectionsTable != LUA_NOREF) {
                [skin pushLuaRef:refTable ref:colorCollectionsTable] ;
                if (lua_getfield(L, -1, [colorList UTF8String]) == LUA_TTABLE) {
                    if (lua_getfield(L, -1, [colorName UTF8String]) == LUA_TTABLE) {
                        holding = table_toNSColorHelper(L, lua_absindex(L, -1), level + 1) ;
                    }
                    lua_pop(L, 1) ; // the colorName entry
                }
                lua_pop(L, 2) ;     // the colorList entry and the lookup table
            }
            if (holding) return holding ;
        }
    } else {
        [skin logAtLevel:LS_LOG_ERROR
             withMessage:[NSString stringWithFormat:@"returning BLACK, color list/name dereference depth > %d: loop?", COLOR_LOOP_LEVEL]
            fromStackPos:1] ;
    }

    if (RGBColor) {
        if (white != 0.0)
            return [NSColor colorWithCalibratedWhite:white alpha:alpha] ;
        else
            return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
    } else {
        return [NSColor colorWithCalibratedHue:hue saturation:saturation brightness:brightness alpha:alpha] ;
    }
}

// [[LuaSkin shared] luaObjectAtIndex:idx toClass:"NSColor"]
// C-API
// Converts the table at the specified index on the Lua Stack into an NSColor and returns the NSColor.  A description of how the table should be defined can be found in `hs.drawing.color`
static id table_toNSColor(lua_State *L, int idx) {
    return table_toNSColorHelper(L, idx, 0) ;
}

// register the lookup table for Lua defined color tables
static int registerColorCollectionsTable(lua_State *L) {
    [[LuaSkin shared] checkArgs:LS_TTABLE, LS_TBREAK] ;

    lua_pushvalue(L, 1) ;
    colorCollectionsTable = [[LuaSkin shared] luaRef:refTable] ;
    return 0 ;
}

static luaL_Reg moduleLib[] = {
    {"lists", getColorLists},
    {"asRGB", colorAsRGB},
    {"asHSB", colorAsHSB},

    {"_registerColorCollectionsTable", registerColorCollectionsTable},

    {NULL,    NULL}
};

int luaopen_hs_drawing_color_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibrary:moduleLib metaFunctions:nil] ; // or module_metaLib
    colorCollectionsTable = LUA_NOREF ;

    [skin registerPushNSHelper:NSColor_tolua      forClass:"NSColor"] ;
    [skin registerLuaObjectHelper:table_toNSColor forClass:"NSColor"] ;

    [skin registerPushNSHelper:NSColorList_tolua  forClass:"NSColorList"] ;

    return 1;
}
