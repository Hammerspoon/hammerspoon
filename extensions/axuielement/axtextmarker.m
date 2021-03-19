/// === hs.axuielement.axtextmarker ===
///
/// This submodule allows hs.axuielement to support using AXTextMarker and AXTextMarkerRange objects as parameters for parameterized Accessibility attributes with applications that support them.
///
/// Most Accessibility object values correspond to the common data types found in most programming languages -- strings, numbers, tables (arrays and dictionaries), etc. AXTextMarker and AXTextMarkerRange types are application specific and do not have a direct mapping to a simple data type. The description I've found most apt comes from comments within the Chromium source for the Mac version of their browser:
///
/// > // A serialization of a position as POD. Not for sharing on disk or sharing
/// > // across thread or process boundaries, just for passing a position to an
/// > // API that works with positions as opaque objects.
///
/// This submodule allows Lua to represent these as userdata which can be passed in to parameterized attributes for the appliction from which they were retrieved. Examples are expected to be added to the Hammerspoon wiki soon.
///
/// As this submodule utilizes private and undocumented functions in the HIServices framework, if you receive an error using any of these functions or methods indicating an undefined CF function (the function or method will return nil and a string of the format "CF function AX... undefined"), please make sure to include the output of the following in any issue you submit to the Hammerspoon github page (enter these into the Hammerspoon console):
///
///     hs.inspect(hs.axuielement.axtextmarker._functionCheck())
///     hs.inspect(hs.processInfo)
///     hs.host.operatingSystemVersionString()

#import "common.h"

static LSRefTable refTable = LUA_NOREF ;

#pragma mark - Support Functions

int pushAXTextMarker(lua_State *L, AXTextMarkerRef theElement) {
    AXTextMarkerRef* thePtr = lua_newuserdata(L, sizeof(AXTextMarkerRef)) ;
    *thePtr = CFRetain(theElement) ;
    luaL_getmetatable(L, AXTEXTMARKER_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

int pushAXTextMarkerRange(lua_State *L, AXTextMarkerRangeRef theElement) {
    AXTextMarkerRangeRef* thePtr = lua_newuserdata(L, sizeof(AXTextMarkerRangeRef)) ;
    *thePtr = CFRetain(theElement) ;
    luaL_getmetatable(L, AXTEXTMRKRNG_TAG) ;
    lua_setmetatable(L, -2) ;
    return 1 ;
}

#pragma mark - Module Functions

/// hs.axuielement.axtextmarker.newMarker(string) -> axTextMarkerObject | nil, errorString
/// Constructor
/// Creates a new AXTextMarker object from the string of binary data provided
///
/// Parameters:
///  * `string` - a string containing 1 or more bytes of data for the AXTextMarker object
///
/// Returns:
///  * a new axTextMarkerObject or nil and a string description if there was an error
///
/// Notes:
///  * This function is included primarily for testing and debugging purposes -- in general you will probably never use this constructor; AXTextMarker objects appear to be mostly application dependant and have no meaning external to the application from which it was created.
static int axtextmarker_newMarker(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    if (AXTextMarkerCreate != NULL) {
        NSData *bytesAsData = [skin toNSObjectAtIndex:1 withOptions:LS_NSLuaStringAsDataOnly] ;
        AXTextMarkerRef marker = AXTextMarkerCreate(kCFAllocatorDefault, bytesAsData.bytes, (CFIndex)bytesAsData.length) ;
        if (marker) {
            pushAXTextMarker(L, marker) ;
            CFRelease(marker) ;
        } else {
            lua_pushnil(L) ;
            lua_pushstring(L, "unable to create marker with specified data string") ;
            return 2 ;
        }
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "CF function AXTextMarkerCreate undefined") ;
        return 2 ;
    }
    return 1 ;
}

/// hs.axuielement.axtextmarker.newRange(startMarker, endMarker) -> axTextMarkerRangeObject | nil, errorString
/// Constructor
/// Creates a new AXTextMarkerRange object from the start and end markers provided
///
/// Parameters:
///  * `startMarker` - an axTextMarkerObject representing the start of the range to be created
///  * `endMarker`   - an axTextMarkerObject representing the end of the range to be created
///
/// Returns:
///  * a new axTextMarkerRangeObject or nil and a string description if there was an error
///
/// Notes:
///  * this constructor can be used to create a range from axTextMarkerObjects obtained from an application to specify a new range for a paramterized attribute. As a simple example (it is hoped that more will be added to the Hammerspoon wiki shortly):
///
///     ```
///     s = hs.axuielement.applicationElement(hs.application("Safari"))
///     -- for a window displaying the DuckDuckGo main search page, this gets the
///     -- primary display area. Other pages may vary and you should build your
///     -- object as necessary for your target.
///     c = s("AXMainWindow")("AXSections")[1].SectionObject[1][1]
///     start = c("AXStartTextMarker") -- get the text marker for the start of this element
///     ending = c("AXNextLineEndTextMarkerForTextMarker", start) -- get the next end of line marker
///     print(c("AXStringForTextMarkerRange", hs.axuielement.axtextmarker.newRange(start, ending)))
///     -- outputs "Privacy, simplified." to the Hammerspoon console
///     ```
///
///  * The specific attributes and parameterized attributes supported by a given application differ and can be discovered with the `hs.axuielement:getAttributeNames` and `hs.axuielement:getParameterizedAttributeNames` methods.
static int axtextmarker_newRange(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, AXTEXTMARKER_TAG, LS_TUSERDATA, AXTEXTMARKER_TAG, LS_TBREAK] ;
    AXTextMarkerRef startMarker = get_axtextmarkerref(L, 1, AXTEXTMARKER_TAG) ;
    AXTextMarkerRef endMarker   = get_axtextmarkerref(L, 2, AXTEXTMARKER_TAG) ;

    if (AXTextMarkerRangeCreate != NULL) {
        AXTextMarkerRangeRef range = AXTextMarkerRangeCreate(kCFAllocatorDefault, startMarker, endMarker) ;
        if (range) {
            pushAXTextMarkerRange(L, range) ;
            CFRelease(range) ;
        } else {
            lua_pushnil(L) ;
            lua_pushstring(L, "invalid start or end marker for range") ;
            return 2 ;
        }
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "CF function AXTextMarkerRangeCreate undefined") ;
        return 2 ;
    }
    return 1 ;
}

// hs.axuielement.axtextmarker._markerID() -> integer | nil, errorString
// Function
// Returns the CFTypeID for the AXTextMarkerRef type
//
// This is for debugging purposes and is not publicaly documented
static int axtextmarker_AXTextMarkerGetTypeID(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    if (AXTextMarkerGetTypeID != NULL) {
        lua_pushinteger(L, (lua_Integer)AXTextMarkerGetTypeID()) ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "CF function AXTextMarkerGetTypeID undefined") ;
        return 2 ;
    }
    return 1 ;
}

// hs.axuielement.axtextmarker._rangeID() -> integer | nil, errorString
// Function
// Returns the CFTypeID for the AXTextMarkerRangeRef type
//
// This is for debugging purposes and is not publicaly documented
static int axtextmarker_AXTextMarkerRangeGetTypeID(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    if (AXTextMarkerRangeGetTypeID != NULL) {
        lua_pushinteger(L, (lua_Integer)AXTextMarkerRangeGetTypeID()) ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "CF function AXTextMarkerRangeGetTypeID undefined") ;
        return 2 ;
    }
    return 1 ;
}

/// hs.axuielement.axtextmarker._functionCheck() -> table
/// Function
/// Returns a table of the AXTextMarker and AXTextMarkerRange functions that have been discovered and are used within this module.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a table with key-value pairs where the keys correspond to the undocumented Core Foundation functions required by this module to support AXTextMarker and AXTextMarkerRange and the value will be a boolean indicating whether the function exists in the currently loaded frameworks.
///
/// Notes:
///  * the functions are defined within the HIServices framework which is part of the ApplicationServices framework, so it is expected that the necessary functions will always be available; however, if you ever receive an error message from a function or method within this submodule of the form "CF function AX... undefined", please see the submodule heading documentation for a description of the information, including that which this function provides, that should be included in any error report you submit.
///
/// * This is for debugging purposes and is not expected to be used often.
static int axtextmarker_availabilityCheck(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;

    lua_newtable(L) ;
    lua_pushboolean(L, (AXTextMarkerGetTypeID != NULL)) ;            lua_setfield(L, -2, "AXTextMarkerGetTypeID") ;
    lua_pushboolean(L, (AXTextMarkerCreate != NULL)) ;               lua_setfield(L, -2, "AXTextMarkerCreate") ;
    lua_pushboolean(L, (AXTextMarkerGetLength != NULL)) ;            lua_setfield(L, -2, "AXTextMarkerGetLength") ;
    lua_pushboolean(L, (AXTextMarkerGetBytePtr != NULL)) ;           lua_setfield(L, -2, "AXTextMarkerGetBytePtr") ;
    lua_pushboolean(L, (AXTextMarkerRangeGetTypeID != NULL)) ;       lua_setfield(L, -2, "AXTextMarkerRangeGetTypeID") ;
    lua_pushboolean(L, (AXTextMarkerRangeCreate != NULL)) ;          lua_setfield(L, -2, "AXTextMarkerRangeCreate") ;
    lua_pushboolean(L, (AXTextMarkerRangeCopyStartMarker != NULL)) ; lua_setfield(L, -2, "AXTextMarkerRangeCopyStartMarker") ;
    lua_pushboolean(L, (AXTextMarkerRangeCopyEndMarker != NULL)) ;   lua_setfield(L, -2, "AXTextMarkerRangeCopyEndMarker") ;
    return 1 ;
}

#pragma mark - Module Methods

/// hs.axuielement.axtextmarker:bytes() -> string | nil, errorString
/// Function
/// Returns a string containing the opaque binary data contained within the axTextMarkerObject
///
/// Parameters:
///  * None
///
/// Returns:
///  *  a string containing the opaque binary data contained within the axTextMarkerObject
///
/// Notes:
///  * the string will likely contain invalid UTF8 code sequences or unprintable ascii values; to see the data in decimal or hexidecimal form you can use:
///
///     string.byte(hs.axuielement.axtextmarker:bytes(), 1, hs.axuielement.axtextmarker:length())
///     -- or
///     hs.utf8.hexDump(hs.axuielement.axtextmarker:bytes())
///
///  * As the data is application specific, it is unlikely that you will use this method often; it is included primarily for testing and debugging purposes.
static int axtextmarker_markerBytes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, AXTEXTMARKER_TAG, LS_TBREAK] ;
    AXTextMarkerRef marker = get_axtextmarkerref(L, 1, AXTEXTMARKER_TAG) ;

    if (AXTextMarkerGetLength != NULL && AXTextMarkerGetBytePtr != NULL) {
        CFIndex length = AXTextMarkerGetLength(marker) ;
        lua_pushlstring(L, AXTextMarkerGetBytePtr(marker), (size_t)length) ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "CF function AXTextMarkerGetLength and/or AXTextMarkerGetBytePtr undefined") ;
        return 2 ;
    }
    return 1 ;
}

/// hs.axuielement.axtextmarker:length() -> integer | nil, errorString
/// Function
/// Returns an integer specifying the number of bytes in the data portion of the axTextMarkerObject.
///
/// Parameters:
///  * None
///
/// Returns:
///  *  an integer specifying the number of bytes in the data portion of the axTextMarkerObject
///
/// Notes:
///  * As the data is application specific, it is unlikely that you will use this method often; it is included primarily for testing and debugging purposes.
static int axtextmarker_markerLength(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, AXTEXTMARKER_TAG, LS_TBREAK] ;
    AXTextMarkerRef marker = get_axtextmarkerref(L, 1, AXTEXTMARKER_TAG) ;

    if (AXTextMarkerGetLength != NULL) {
        lua_pushinteger(L, (lua_Integer)AXTextMarkerGetLength(marker)) ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "CF function AXTextMarkerGetLength undefined") ;
        return 2 ;
    }
    return 1 ;
}

/// hs.axuielement.axtextmarker:startMarker() -> axTextMarkerObject | nil, errorString
/// Function
/// Returns the starting marker for an axTextMarkerRangeObject
///
/// Parameters:
///  * None
///
/// Returns:
///  *  the starting marker for an axTextMarkerRangeObject
static int axtextmarker_rangeStartMarker(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, AXTEXTMRKRNG_TAG, LS_TBREAK] ;
    AXTextMarkerRangeRef range = get_axtextmarkerrangeref(L, 1, AXTEXTMRKRNG_TAG) ;

    if (AXTextMarkerRangeCopyStartMarker != NULL) {
        AXTextMarkerRef marker = AXTextMarkerRangeCopyStartMarker(range) ;
        if (marker) {
            pushAXTextMarker(L, marker) ;
            CFRelease(marker) ;
        } else {
            lua_pushnil(L) ;
            lua_pushstring(L, "startMarker NULL for range") ;
            return 2 ;
        }
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "CF function AXTextMarkerRangeCopyStartMarker undefined") ;
        return 2 ;
    }
    return 1 ;
}

/// hs.axuielement.axtextmarker:endMarker() -> axTextMarkerObject | nil, errorString
/// Function
/// Returns the ending marker for an axTextMarkerRangeObject
///
/// Parameters:
///  * None
///
/// Returns:
///  *  the ending marker for an axTextMarkerRangeObject
static int axtextmarker_rangeEndMarker(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, AXTEXTMRKRNG_TAG, LS_TBREAK] ;
    AXTextMarkerRangeRef range = get_axtextmarkerrangeref(L, 1, AXTEXTMRKRNG_TAG) ;

    if (AXTextMarkerRangeCopyEndMarker != NULL) {
        AXTextMarkerRef marker = AXTextMarkerRangeCopyEndMarker(range) ;
        if (marker) {
            pushAXTextMarker(L, marker) ;
            CFRelease(marker) ;
        } else {
            lua_pushnil(L) ;
            lua_pushstring(L, "endMarker NULL for range") ;
            return 2 ;
        }
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "CF function AXTextMarkerRangeCopyEndMarker undefined") ;
        return 2 ;
    }
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)",
        (luaL_testudata(L, 1, AXTEXTMARKER_TAG) ? AXTEXTMARKER_TAG : AXTEXTMRKRNG_TAG),
        lua_topointer(L, 1)
    ]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
    if ((luaL_testudata(L, 1, AXTEXTMARKER_TAG) && luaL_testudata(L, 2, AXTEXTMARKER_TAG)) ||
        (luaL_testudata(L, 1, AXTEXTMRKRNG_TAG) && luaL_testudata(L, 2, AXTEXTMRKRNG_TAG))) {
        CFTypeRef theRef1 = *((CFTypeRef*)lua_touserdata(L, 1)) ;
        CFTypeRef theRef2 = *((CFTypeRef*)lua_touserdata(L, 2)) ;
        lua_pushboolean(L, CFEqual(theRef1, theRef2)) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    CFTypeRef theRef = *((CFTypeRef*)lua_touserdata(L, 1)) ;
    CFRelease(theRef) ;
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// static int meta_gc(lua_State* L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg marker_userdata_metaLib[] = {
    {"bytes",      axtextmarker_markerBytes},
    {"length",     axtextmarker_markerLength},

    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
} ;

static const luaL_Reg range_userdata_metaLib[] = {
    {"startMarker", axtextmarker_rangeStartMarker},
    {"endMarker",   axtextmarker_rangeEndMarker},

    {"__tostring",  userdata_tostring},
    {"__eq",        userdata_eq},
    {"__gc",        userdata_gc},
    {NULL,          NULL}
} ;

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"newMarker",      axtextmarker_newMarker},
    {"newRange",       axtextmarker_newRange},

    {"_markerID",      axtextmarker_AXTextMarkerGetTypeID},
    {"_rangeID",       axtextmarker_AXTextMarkerRangeGetTypeID},
    {"_functionCheck", axtextmarker_availabilityCheck},

    {NULL,             NULL}
} ;

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// } ;

int luaopen_hs_axuielement_axtextmarker(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:AXTEXTMARKER_TAG
                                     functions:moduleLib
                                 metaFunctions:nil
                               objectFunctions:marker_userdata_metaLib] ;

    [skin registerObject:AXTEXTMRKRNG_TAG objectFunctions:range_userdata_metaLib] ;

    return 1 ;
}
