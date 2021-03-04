@import Cocoa;
@import LuaSkin;

#pragma mark - Support Functions and Classes

NSPasteboard *lua_to_pasteboard(lua_State* L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    if (!lua_isnoneornil(L, idx)) {
        luaL_checkstring(L, idx) ; // force number to string
        return [NSPasteboard pasteboardWithName:[skin toNSObjectAtIndex:idx]];
    } else {
        return [NSPasteboard generalPasteboard];
    }

}

// Not sure that this is really useful with the way we are using the pasteboard, and it
// just adds to the confusion ...
//
// #pragma mark - Module Constants
//
// static int pushPasteboardTypesTable(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     lua_newtable(L) ;
//     [skin pushNSObject:NSPasteboardTypeString] ;                 lua_setfield(L, -2, "string") ;
//     [skin pushNSObject:NSPasteboardTypePDF] ;                    lua_setfield(L, -2, "PDF") ;
//     [skin pushNSObject:NSPasteboardTypeTIFF] ;                   lua_setfield(L, -2, "TIFF") ;
//     [skin pushNSObject:NSPasteboardTypePNG] ;                    lua_setfield(L, -2, "PNG") ;
//     [skin pushNSObject:NSPasteboardTypeRTF] ;                    lua_setfield(L, -2, "RTF") ;
//     [skin pushNSObject:NSPasteboardTypeRTFD] ;                   lua_setfield(L, -2, "RTFD") ;
//     [skin pushNSObject:NSPasteboardTypeHTML] ;                   lua_setfield(L, -2, "HTML") ;
//     [skin pushNSObject:NSPasteboardTypeTabularText] ;            lua_setfield(L, -2, "tabularText") ;
//     [skin pushNSObject:NSPasteboardTypeFont] ;                   lua_setfield(L, -2, "font") ;
//     [skin pushNSObject:NSPasteboardTypeRuler] ;                  lua_setfield(L, -2, "ruler") ;
//     [skin pushNSObject:NSPasteboardTypeColor] ;                  lua_setfield(L, -2, "color") ;
//     [skin pushNSObject:NSPasteboardTypeSound] ;                  lua_setfield(L, -2, "sound") ;
//     [skin pushNSObject:NSPasteboardTypeMultipleTextSelection] ;  lua_setfield(L, -2, "multipleTextSelection") ;
//     [skin pushNSObject:NSPasteboardTypeFindPanelSearchOptions] ; lua_setfield(L, -2, "findPanelSearchOptions") ;
//     [skin pushNSObject:NSPasteboardTypeTextFinderOptions] ;      lua_setfield(L, -2, "textFinderOptions") ;
//     return 1 ;
// }
//
// static int pushPasteboardNamesTable(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     lua_newtable(L) ;
//     [skin pushNSObject:NSGeneralPboard] ; lua_setfield(L, -2, "general") ;
//     [skin pushNSObject:NSFontPboard] ;    lua_setfield(L, -2, "font") ;
//     [skin pushNSObject:NSRulerPboard] ;   lua_setfield(L, -2, "ruler") ;
//     [skin pushNSObject:NSFindPboard] ;    lua_setfield(L, -2, "find") ;
//     [skin pushNSObject:NSDragPboard] ;    lua_setfield(L, -2, "drag") ;
//     return 1 ;
// }

#pragma mark - Module Functions

/// hs.pasteboard.getContents([name]) -> string or nil
/// Function
/// Gets the contents of the pasteboard
///
/// Parameters:
///  * name - An optional string containing the name of the pasteboard. Defaults to the system pasteboard
///
/// Returns:
///  * A string containing the contents of the pasteboard, or nil if an error occurred
static int pasteboard_getContents(lua_State* L) {
        lua_pushstring(L, [[lua_to_pasteboard(L, 1) stringForType:NSPasteboardTypeString] UTF8String]);
    return 1;
}

// /// hs.pasteboard.getImageContents([name]) -> hs.image object or nil
// /// Function
// /// Gets the first image of the pasteboard
// ///
// /// Parameters:
// ///  * name - An optional string containing the name of the pasteboard. Defaults to the system pasteboard
// ///
// /// Returns:
// ///  * An `hs.image` object from the first pasteboard image, or nil if an error occurred
// static int pasteboard_getImageContents(lua_State* L) {
//     NSImage *image = [[NSImage alloc] initWithData:[lua_to_pasteboard(L, 1) dataForType:NSPasteboardTypePNG]];
//
//     if (image && image.valid) {
//         [[LuaSkin sharedWithState:L] pushNSObject:image];
//     } else {
//         return luaL_error(L, "No valid image data in pasteboard");
//     }
//
//     return 1;
// }

/// hs.pasteboard.setContents(contents[, name]) -> boolean
/// Function
/// Sets the contents of the pasteboard
///
/// Parameters:
///  * contents - A string to be placed in the pasteboard
///  * name - An optional string containing the name of the pasteboard. Defaults to the system pasteboard
///
/// Returns:
///  * True if the operation succeeded, otherwise false
static int pasteboard_setContents(lua_State* L) {
//     NSString* str = [NSString stringWithUTF8String:luaL_checkstring(L, 1)];
    NSPasteboard* thePasteboard = lua_to_pasteboard(L, 2);

    luaL_tolstring(L, 1, NULL) ;
    id str = [[LuaSkin sharedWithState:L] toNSObjectAtIndex:-1 withOptions:LS_NSPreserveLuaStringExactly] ;
    [thePasteboard clearContents];
    BOOL result = NO ;
    if ([str isKindOfClass:[NSString class]]) {
        result = [thePasteboard setString:str forType:NSPasteboardTypeString];
    } else {
        result = [thePasteboard setData:str forType:NSPasteboardTypeString];
    }

    lua_pushboolean(L, result);
    return 1;
}

// /// hs.pasteboard.setImageContents(contents[, name]) -> boolean
// /// Function
// /// Sets the contents of the pasteboard to a PNG image
// ///
// /// Parameters:
// ///  * contents - An image to be placed in the pasteboard
// ///  * name - An optional string containing the name of the pasteboard. Defaults to the system pasteboard
// ///
// /// Returns:
// ///  * True if the operation succeeded, otherwise false
// static int pasteboard_setImageContents(lua_State* L) {
//     [[LuaSkin sharedWithState:L] checkArgs:LS_TUSERDATA, "hs.image", LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
//     NSImage*  theImage = [[LuaSkin sharedWithState:L] luaObjectAtIndex:1 toClass:"NSImage"] ;
//     NSPasteboard* thePasteboard = lua_to_pasteboard(L, 2);
//
//     NSData *tiffRep = [theImage TIFFRepresentation];
//     if (!tiffRep)  return luaL_error(L, "Can't create internal image representation");
//
//     NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:tiffRep];
//     if (!rep)  return luaL_error(L, "Can't wrap internal image representation");
//
//     NSData* pngImageData = [rep representationUsingType:NSPNGFileType properties:@{}];
//
//     [thePasteboard clearContents];
//     BOOL result = [thePasteboard setData:pngImageData forType:NSPasteboardTypePNG];
//
//     lua_pushboolean(L, result);
//     return 1;
// }

/// hs.pasteboard.clearContents([name])
/// Function
/// Clear the contents of the pasteboard
///
/// Parameters:
///  * name - An optional string containing the name of the pasteboard. Defaults to the system pasteboard
///
/// Returns:
///  * None
static int pasteboard_clearContents(lua_State* L) {
    NSPasteboard* thePasteboard = lua_to_pasteboard(L, 1);
    [thePasteboard clearContents];

    return 0;
}

/// hs.pasteboard.pasteboardTypes([name]) -> table
/// Function
/// Return the pasteboard type identifier strings for the specified pasteboard.
///
/// Parameters:
///  * name - An optional string containing the name of the pasteboard. Defaults to the system pasteboard
///
/// Returns:
///  * a table containing the pasteboard type identifier strings
static int pasteboard_pasteboardTypes(lua_State* L) {
    NSPasteboard* thePasteboard = lua_to_pasteboard(L, 1);

    lua_newtable(L) ;
        for (NSString* type in [thePasteboard types]) {
            lua_pushstring(L, [type UTF8String]) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }

    return 1;
}

/// hs.pasteboard.contentTypes([name]) -> table
/// Function
/// Return the UTI strings of the data types for the first pasteboard item on the specified pasteboard.
///
/// Parameters:
///  * name - An optional string containing the name of the pasteboard. Defaults to the system pasteboard
///
/// Returns:
///  * a table containing the UTI strings of the data types for the first pasteboard item.
static int pasteboard_pasteboardItemTypes(lua_State* L) {
    NSPasteboard* thePasteboard = lua_to_pasteboard(L, 1);

    lua_newtable(L) ;
// make sure there is something on the pasteboard...
    NSArray *items = [thePasteboard pasteboardItems] ;
    if (items && [items count] > 0) {
        NSPasteboardItem* item = [items objectAtIndex:0];
        for (NSString* type in [item types]) {
            lua_pushstring(L, [type UTF8String]) ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    }
    return 1;
}

/// hs.pasteboard.changeCount([name]) -> number
/// Function
/// Gets the number of times the pasteboard owner has changed
///
/// Parameters:
///  * name - An optional string containing the name of the pasteboard. Defaults to the system pasteboard
///
/// Returns:
///  * A number containing a count of the times the pasteboard owner has changed
///
/// Notes:
///  * This is useful for seeing if the pasteboard has been updated by another process
static int pasteboard_changeCount(lua_State* L) {
    lua_pushinteger(L, [lua_to_pasteboard(L, 1) changeCount]);
    return 1;
}

/// hs.pasteboard.deletePasteboard(name)
/// Function
/// Deletes a custom pasteboard
///
/// Parameters:
///  * name - A string containing the name of the pasteboard
///
/// Returns:
///  * None
///
/// Notes:
///  * You can not delete the system pasteboard, this function should only be called on custom pasteboards you have created
static int pasteboard_delete(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TBREAK] ; // prevents nil from being specified
    luaL_checkstring(L, 1) ; // coerce number to string
    NSString *pbName = [skin toNSObjectAtIndex:1] ;
    if ([pbName isEqualToString:NSPasteboardNameGeneral] ||
        [pbName isEqualToString:NSPasteboardNameFont]    ||
        [pbName isEqualToString:NSPasteboardNameRuler]   ||
        [pbName isEqualToString:NSPasteboardNameFind]    ||
        [pbName isEqualToString:NSPasteboardNameDrag]) return luaL_error(L, "cannot delete a system pasteboard") ;

    NSPasteboard *thePasteboard = [NSPasteboard pasteboardWithName:pbName];
    [thePasteboard releaseGlobally];
    return 0;
}

#pragma mark - Experimental and WhatFors

/// hs.pasteboard.allContentTypes([name]) -> table
/// Function
/// An array whose elements are a table containing the content types for each element on the clipboard.
///
/// Parameters:
///  * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
///
/// Returns:
///  * an array with each index representing an object on the pasteboard.  If the pasteboard contains only one element, this is equivalent to `{ hs.pasteboard.contentTypes(name) }`.
static int allPBItemTypes(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSPasteboard* thePasteboard = lua_to_pasteboard(L, 1);
    lua_newtable(L) ;
    NSArray *items = [thePasteboard pasteboardItems] ;
    if (items) {
        for(NSUInteger i = 0 ; i < [items count]; i++) {
            lua_newtable(L) ;
            NSPasteboardItem* item = [items objectAtIndex:i];
            for (NSString* type in [item types]) {
                [skin pushNSObject:type] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
            }
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
    }
    return 1;
}

/// hs.pasteboard.readString([name], [all]) -> string or array of strings
/// Function
/// Returns one or more strings from the clipboard, or nil if no compatible objects are present.
///
/// Parameters:
///  * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
///  * all  - an optional boolean indicating whether or not all (true) of the urls on the clipboard should be returned, or just the first (false).  Defaults to false.
///
/// Returns:
///  * By default the first string on the clipboard, or a table of all strings on the clipboard if the `all` parameter is provided and set to true.  Returns nil if no strings are present.
///
/// Notes:
///  * almost all string and styledText objects are internally convertible and will be available with this method as well as [hs.pasteboard.readStyledText](#readStyledText). If the item is actually an `hs.styledtext` object, the string will be just the text of the object.
static int readStringObjects(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL | LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;

    NSPasteboard* pb ;
    BOOL getAll = NO ;

    if (lua_gettop(L) >= 1 && lua_isboolean(L, -1)) {
        getAll = (BOOL)lua_toboolean(L, -1) ;
        lua_pop(L, 1) ;
    }
    if (lua_gettop(L) >= 1) {
        if (lua_isboolean(L, 1))
            return luaL_argerror(L, 1, "string or nil expected") ;
        pb = lua_to_pasteboard(L, 1) ;
    } else {
        pb = [NSPasteboard generalPasteboard] ;
    }

    NSArray *results = [pb readObjectsForClasses:@[[NSString class]] options:@{}] ;
    if (results && ([results count] != 0)) {
        if (getAll) {
            [skin pushNSObject:results] ;
        } else {
            [skin pushNSObject:[results firstObject]] ;
        }
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.pasteboard.readDataForUTI([name], uti) -> string
/// Function
/// Returns the first item on the pasteboard with the specified UTI as raw data
///
/// Parameters:
///  * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
///  * uti  - a string specifying the UTI of the pasteboard item to retrieve.
///
/// Returns:
///  * a lua string containing the raw data of the specified pasteboard item
///
/// Notes:
///  * The UTI's of the items on the pasteboard can be determined with the [hs.pasteboard.allContentTypes](#allContentTypes) and [hs.pasteboard.contentTypes](#contentTypes) functions.
static int readItemForType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSPasteboard *pb ;
    NSString     *type ;
    if (lua_gettop(L) == 1) {
        [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
        pb   = [NSPasteboard generalPasteboard] ;
        type = [skin toNSObjectAtIndex:1] ;
    } else {
        [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL, LS_TSTRING, LS_TBREAK] ;
        pb = lua_to_pasteboard(L, 1) ;
        type = [skin toNSObjectAtIndex:2] ;
    }
    if (pb && type) {
        @try {
            [skin pushNSObject:[pb dataForType:type]] ;
        } @catch (NSException *exception) {
            return luaL_error(L, [[exception reason] UTF8String]) ;
        }
    } else if (!pb) {
        return luaL_error(L, "unable to get pasteboard") ;
    } else {
        return luaL_error(L, "unable to evaluate type string") ;
    }
    return 1 ;
}

/// hs.pasteboard.readPListForUTI([name], uti) -> any
/// Function
/// Returns the first item on the pasteboard with the specified UTI as a property list item
///
/// Parameters:
///  * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
///  * uti  - a string specifying the UTI of the pasteboard item to retrieve.
///
/// Returns:
///  * a lua item representing the property list value of the pasteboard item specified
///
/// Notes:
///  * The UTI's of the items on the pasteboard can be determined with the [hs.pasteboard.allContentTypes](#allContentTypes) and [hs.pasteboard.contentTypes](#contentTypes) functions.
///  * Property lists consist only of certain types of data: tables, strings, numbers, dates, binary data, and Boolean values.
static int readPropertyListForType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSPasteboard *pb ;
    NSString     *type ;
    if (lua_gettop(L) == 1) {
        [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
        pb   = [NSPasteboard generalPasteboard] ;
        type = [skin toNSObjectAtIndex:1] ;
    } else {
        [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL, LS_TSTRING, LS_TBREAK] ;
        pb = lua_to_pasteboard(L, 1) ;
        type = [skin toNSObjectAtIndex:2] ;
    }
    if (pb && type) {
        // uses dataForType: which is documented to throw exceptions for errors
        @try {
            [skin pushNSObject:[pb propertyListForType:type]] ;
        } @catch (NSException *exception) {
            return luaL_error(L, [[exception reason] UTF8String]) ;
        }
    } else if (!pb) {
        return luaL_error(L, "unable to get pasteboard") ;
    } else {
        return luaL_error(L, "unable to evaluate type string") ;
    }
    return 1 ;
}

/// hs.pasteboard.readArchiverDataForUTI([name], uti) -> any
/// Function
/// Returns the first item on the pasteboard with the specified UTI. The data on the pasteboard must be encoded as a keyed archive object conforming to NSKeyedArchiver.
///
/// Parameters:
///  * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
///  * uti  - a string specifying the UTI of the pasteboard item to retrieve.
///
/// Returns:
///  * a lua item representing the archived data if it can be decoded. Generates an error if the data is in the wrong format.
///
/// Notes:
///  * NSKeyedArchiver specifies an architecture-independent format that is often used in OS X applications to store and transmit objects between applications and when storing data to a file. It works by recording information about the object types and key-value pairs which make up the objects being stored.
///  * Only objects which have conversion functions built in to Hammerspoon can be converted. A string representation describing unrecognized types wil be returned. If you find a common data type that you believe may be of interest to Hammerspoon users, feel free to contribute a conversion function or make a request in the Hammerspoon Google group or Github site.
///  * Some applications may define their own classes which can be archived.  Hammerspoon will be unable to recognize these types if the application does not make the object type available in one of its frameworks.  You *may* be able to load the necessary framework with `package.loadlib("/Applications/appname.app/Contents/Frameworks/frameworkname.framework/frameworkname", "*")` before retrieving the data, but a full representation of the data in Hammerspoon is probably not possible without support from the Application's developers.
static int readArchivedDataForType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSPasteboard *pb ;
    NSString     *type ;
    if (lua_gettop(L) == 1) {
        [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
        pb   = [NSPasteboard generalPasteboard] ;
        type = [skin toNSObjectAtIndex:1] ;
    } else {
        [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL, LS_TSTRING, LS_TBREAK] ;
        pb = lua_to_pasteboard(L, 1) ;
        type = [skin toNSObjectAtIndex:2] ;
    }
    if (pb && type) {
        // uses dataForType: which is documented to throw exceptions for errors
        @try {
            NSData *holding = [pb dataForType:type] ;
            id realItem = [NSKeyedUnarchiver unarchiveObjectWithData:holding] ;
            [skin pushNSObject:realItem withOptions:LS_NSDescribeUnknownTypes] ;
        } @catch (NSException *exception) {
            return luaL_error(L, [[exception reason] UTF8String]) ;
        }
    } else if (!pb) {
        return luaL_error(L, "unable to get pasteboard") ;
    } else {
        return luaL_error(L, "unable to evaluate type string") ;
    }
    return 1 ;
}

/// hs.pasteboard.writeArchiverDataForUTI([name], uti, data, [add]) -> boolean
/// Function
/// Sets the pasteboard to the contents of the data and assigns its type to the specified UTI. The data will be encoded as an archive conforming to NSKeyedArchiver.
///
/// Parameters:
///  * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
///  * uti  - a string specifying the UTI of the pasteboard item to set.
///  * data - any type representable in Lua which will be converted into the appropriate NSObject types and archived with NSKeyedArchiver.  All Lua basic types are supported as well as those NSObject types handled by Hammerspoon modules (NSColor, NSStyledText, NSImage, etc.)
///  * add  - an optional boolean value specifying if data with other UTI values should retain.  This value must be strictly either true or false if given, to avoid ambiguity with preceding parameters.
///
/// Returns:
///  * True if the operation succeeded, otherwise false (which most likely means ownership of the pasteboard has changed)
///
/// Notes:
///  * NSKeyedArchiver specifies an architecture-independent format that is often used in OS X applications to store and transmit objects between applications and when storing data to a file. It works by recording information about the object types and key-value pairs which make up the objects being stored.
///  * Only objects which have conversion functions built in to Hammerspoon can be converted.
///
///  * A full list of NSObjects supported directly by Hammerspoon is planned in a future Wiki article.
static int writeArchivedDataForType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSPasteboard *pb ;
    BOOL          add = NO ;
    NSString     *type ;
    id           data ;
    if (lua_gettop(L) >= 3) {
        if (lua_isboolean(L, -1)) {
            add = (BOOL)lua_toboolean(L, -1) ;
            lua_settop(L, -2) ;
        } else if (lua_isnil(L, -1)) {
            lua_settop(L, -2) ;
        }
    }
    if (lua_gettop(L) == 2) {
        [skin checkArgs:LS_TSTRING, LS_TANY, LS_TBREAK] ;
        pb   = [NSPasteboard generalPasteboard] ;
        type = [skin toNSObjectAtIndex:1] ;
        data = [skin toNSObjectAtIndex:2 withOptions:LS_NSPreserveLuaStringExactly] ;
    } else {
        [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL, LS_TSTRING, LS_TANY, LS_TBREAK] ;
        pb = lua_to_pasteboard(L, 1) ;
        type = [skin toNSObjectAtIndex:2] ;
        data = [skin toNSObjectAtIndex:3 withOptions:LS_NSPreserveLuaStringExactly] ;
    }
    if (pb && type && data) {
        // uses setData:forType: which is documented to throw exceptions for errors
        @try {
            NSData *encoded = [NSKeyedArchiver archivedDataWithRootObject:data];
            if (!add) {
                [pb clearContents] ;
            }
            lua_pushboolean(L, [pb setData:encoded forType:type]) ;
        } @catch (NSException *exception) {
            return luaL_error(L, [[exception reason] UTF8String]) ;
        }
    } else if (!pb) {
        return luaL_error(L, "unable to get pasteboard") ;
    } else if (!type) {
        return luaL_error(L, "unable to evaluate type string") ;
    } else {
        return luaL_error(L, "unable to evaluate data string") ;
    }
    return 1 ;
}

/// hs.pasteboard.writeDataForUTI([name], uti, data, [add]) -> boolean
/// Function
/// Sets the pasteboard to the contents of the data and assigns its type to the specified UTI.
///
/// Parameters:
///  * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
///  * uti  - a string specifying the UTI of the pasteboard item to set.
///  * data - a string specifying the raw data to assign to the pasteboard.
///  * add  - an optional boolean value specifying if data with other UTI values should retain.  This value must be strictly either true or false if given, to avoid ambiguity with preceding parameters.
///
/// Returns:
///  * True if the operation succeeded, otherwise false (which most likely means ownership of the pasteboard has changed)
///
/// Notes:
///  * The UTI's of the items on the pasteboard can be determined with the [hs.pasteboard.allContentTypes](#allContentTypes) and [hs.pasteboard.contentTypes](#contentTypes) functions.
static int writeItemForType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSPasteboard *pb ;
    BOOL          add = NO ;
    NSString     *type ;
    NSData       *data ;
    if (lua_gettop(L) >= 3) {
        if (lua_isboolean(L, -1)) {
            add = (BOOL)lua_toboolean(L, -1) ;
            lua_settop(L, -2) ;
        } else if (lua_isnil(L, -1)) {
            lua_settop(L, -2) ;
        }
    }
    if (lua_gettop(L) == 2) {
        [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TBREAK] ;
        pb   = [NSPasteboard generalPasteboard] ;
        type = [skin toNSObjectAtIndex:1] ;
        data = [skin toNSObjectAtIndex:2 withOptions:LS_NSLuaStringAsDataOnly] ;
    } else {
        [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL, LS_TSTRING, LS_TSTRING, LS_TBREAK] ;
        pb = lua_to_pasteboard(L, 1) ;
        type = [skin toNSObjectAtIndex:2] ;
        data = [skin toNSObjectAtIndex:3 withOptions:LS_NSLuaStringAsDataOnly] ;
    }
    if (pb && type && data) {
        @try {
            if (!add) {
                [pb clearContents] ;
            }
            lua_pushboolean(L, [pb setData:data forType:type]) ;
        } @catch (NSException *exception) {
            return luaL_error(L, [[exception reason] UTF8String]) ;
        }
    } else if (!pb) {
        return luaL_error(L, "unable to get pasteboard") ;
    } else if (!type) {
        return luaL_error(L, "unable to evaluate type string") ;
    } else {
        return luaL_error(L, "unable to evaluate data string") ;
    }
    return 1 ;
}

/// hs.pasteboard.writePListForUTI([name], uti, data, [add]) -> boolean
/// Function
/// Sets the pasteboard to the contents of the data and assigns its type to the specified UTI.
///
/// Parameters:
///  * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
///  * uti  - a string specifying the UTI of the pasteboard item to set.
///  * data - a lua type which can be represented as a property list value.
///  * add  - an optional boolean value specifying if data with other UTI values should retain.  This value must be strictly either true or false if given, to avoid ambiguity with preceding parameters.
///
/// Returns:
///  * True if the operation succeeded, otherwise false (which most likely means ownership of the pasteboard has changed)
///
/// Notes:
///  * The UTI's of the items on the pasteboard can be determined with the [hs.pasteboard.allContentTypes](#allContentTypes) and [hs.pasteboard.contentTypes](#contentTypes) functions.
///  * Property lists consist only of certain types of data: tables, strings, numbers, dates, binary data, and Boolean values.
static int writePropertyListForType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSPasteboard *pb ;
    BOOL          add = NO ;
    NSString     *type ;
    id           data ;
    if (lua_gettop(L) >= 3) {
        if (lua_isboolean(L, -1)) {
            add = (BOOL)lua_toboolean(L, -1) ;
            lua_settop(L, -2) ;
        } else if (lua_isnil(L, -1)) {
            lua_settop(L, -2) ;
        }
    }
    if (lua_gettop(L) == 2) {
        [skin checkArgs:LS_TSTRING, LS_TANY, LS_TBREAK] ;
        pb   = [NSPasteboard generalPasteboard] ;
        type = [skin toNSObjectAtIndex:1] ;
        data = [skin toNSObjectAtIndex:2 withOptions:LS_NSPreserveLuaStringExactly] ;
    } else {
        [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL, LS_TSTRING, LS_TANY, LS_TBREAK] ;
        pb = lua_to_pasteboard(L, 1) ;
        type = [skin toNSObjectAtIndex:2] ;
        data = [skin toNSObjectAtIndex:3 withOptions:LS_NSPreserveLuaStringExactly] ;
    }
    if (pb && type && data) {
        // uses setData:forType: which is documented to throw exceptions for errors
        @try {
            if (!add) {
                [pb clearContents] ;
            }
            lua_pushboolean(L, [pb setPropertyList:data forType:type]) ;
        } @catch (NSException *exception) {
            return luaL_error(L, [[exception reason] UTF8String]) ;
        }
    } else if (!pb) {
        return luaL_error(L, "unable to get pasteboard") ;
    } else if (!type) {
        return luaL_error(L, "unable to evaluate type string") ;
    } else {
        return luaL_error(L, "unable to evaluate data string") ;
    }
    return 1 ;
}

/// hs.pasteboard.readStyledText([name], [all]) -> hs.styledtext object or array of hs.styledtext objects
/// Function
/// Returns one or more `hs.styledtext` objects from the clipboard, or nil if no compatible objects are present.
///
/// Parameters:
///  * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
///  * all  - an optional boolean indicating whether or not all (true) of the urls on the clipboard should be returned, or just the first (false).  Defaults to false.
///
/// Returns:
///  * By default the first styledtext object on the clipboard, or a table of all styledtext objects on the clipboard if the `all` parameter is provided and set to true.  Returns nil if no styledtext objects are present.
///
/// Notes:
///  * almost all string and styledText objects are internally convertible and will be available with this method as well as [hs.pasteboard.readString](#readString). If the item on the clipboard is actually just a string, the `hs.styledtext` object representation will have no attributes set
static int readAttributedStringObjects(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL | LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;

    NSPasteboard* pb ;
    BOOL getAll = NO ;

    if (lua_gettop(L) >= 1 && lua_isboolean(L, -1)) {
        getAll = (BOOL)lua_toboolean(L, -1) ;
        lua_pop(L, 1) ;
    }
    if (lua_gettop(L) >= 1) {
        if (lua_isboolean(L, 1))
            return luaL_argerror(L, 1, "string or nil expected") ;
        pb = lua_to_pasteboard(L, 1) ;
    } else {
        pb = [NSPasteboard generalPasteboard] ;
    }

    NSArray *results = [pb readObjectsForClasses:@[[NSAttributedString class]] options:@{}] ;
    if (results && ([results count] != 0)) {
        if (getAll) {
            [skin pushNSObject:results] ;
        } else {
            [skin pushNSObject:[results firstObject]] ;
        }
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.pasteboard.readSound([name], [all]) -> hs.sound object or array of hs.sound objects
/// Function
/// Returns one or more `hs.sound` objects from the clipboard, or nil if no compatible objects are present.
///
/// Parameters:
///  * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
///  * all  - an optional boolean indicating whether or not all (true) of the urls on the clipboard should be returned, or just the first (false).  Defaults to false.
///
/// Returns:
///  * By default the first sound on the clipboard, or a table of all sounds on the clipboard if the `all` parameter is provided and set to true.  Returns nil if no sounds are present.
static int readSoundObjects(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL | LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;

    NSPasteboard* pb ;
    BOOL getAll = NO ;

    if (lua_gettop(L) >= 1 && lua_isboolean(L, -1)) {
        getAll = (BOOL)lua_toboolean(L, -1) ;
        lua_pop(L, 1) ;
    }
    if (lua_gettop(L) >= 1) {
        if (lua_isboolean(L, 1))
            return luaL_argerror(L, 1, "string or nil expected") ;
        pb = lua_to_pasteboard(L, 1) ;
    } else {
        pb = [NSPasteboard generalPasteboard] ;
    }

    NSArray *results = [pb readObjectsForClasses:@[[NSSound class]] options:@{}] ;
    if (results && ([results count] != 0)) {
        if (getAll) {
            [skin pushNSObject:results] ;
        } else {
            [skin pushNSObject:[results firstObject]] ;
        }
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.pasteboard.readImage([name], [all]) -> hs.image object or array of hs.image objects
/// Function
/// Returns one or more `hs.image` objects from the clipboard, or nil if no compatible objects are present.
///
/// Parameters:
///  * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
///  * all  - an optional boolean indicating whether or not all (true) of the urls on the clipboard should be returned, or just the first (false).  Defaults to false.
///
/// Returns:
///  * By default the first image on the clipboard, or a table of all images on the clipboard if the `all` parameter is provided and set to true.  Returns nil if no images are present.
static int readImageObjects(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL | LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;

    NSPasteboard* pb ;
    BOOL getAll = NO ;

    if (lua_gettop(L) >= 1 && lua_isboolean(L, -1)) {
        getAll = (BOOL)lua_toboolean(L, -1) ;
        lua_pop(L, 1) ;
    }
    if (lua_gettop(L) >= 1) {
        if (lua_isboolean(L, 1))
            return luaL_argerror(L, 1, "string or nil expected") ;
        pb = lua_to_pasteboard(L, 1) ;
    } else {
        pb = [NSPasteboard generalPasteboard] ;
    }

    NSArray *results = [pb readObjectsForClasses:@[[NSImage class]] options:@{}] ;
    if (results && ([results count] != 0)) {
        if (getAll) {
            [skin pushNSObject:results] ;
        } else {
            [skin pushNSObject:[results firstObject]] ;
        }
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.pasteboard.readURL([name], [all]) -> string or array of strings representing file or resource urls
/// Function
/// Returns one or more strings representing file or resource urls from the clipboard, or nil if no compatible objects are present.
///
/// Parameters:
///  * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
///  * all  - an optional boolean indicating whether or not all (true) of the urls on the clipboard should be returned, or just the first (false).  Defaults to false.
///
/// Returns:
///  * By default the first url on the clipboard, or a table of all urls on the clipboard if the `all` parameter is provided and set to true.  Returns nil if no urls are present.
static int readURLObjects(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL | LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;

    NSPasteboard* pb ;
    BOOL getAll = NO ;

    if (lua_gettop(L) >= 1 && lua_isboolean(L, -1)) {
        getAll = (BOOL)lua_toboolean(L, -1) ;
        lua_pop(L, 1) ;
    }
    if (lua_gettop(L) >= 1) {
        if (lua_isboolean(L, 1))
            return luaL_argerror(L, 1, "string or nil expected") ;
        pb = lua_to_pasteboard(L, 1) ;
    } else {
        pb = [NSPasteboard generalPasteboard] ;
    }

    NSArray *results = [pb readObjectsForClasses:@[[NSURL class]] options:@{}] ;
    if (results && ([results count] != 0)) {
        if (getAll) {
            [skin pushNSObject:results] ;
        } else {
            [skin pushNSObject:[results firstObject]] ;
        }
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.pasteboard.readColor([name], [all]) -> hs.drawing.color table or array of hs.drawing.color tables
/// Function
/// Returns one or more `hs.drawing.color` tables from the clipboard, or nil if no compatible objects are present.
///
/// Parameters:
///  * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
///  * all  - an optional boolean indicating whether or not all (true) of the colors on the clipboard should be returned, or just the first (false).  Defaults to false.
///
/// Returns:
///  * By default the first color on the clipboard, or a table of all colors on the clipboard if the `all` parameter is provided and set to true.  Returns nil if no colors are present.
static int readColorObjects(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL | LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;

    NSPasteboard* pb ;
    BOOL getAll = NO ;

    if (lua_gettop(L) >= 1 && lua_isboolean(L, -1)) {
        getAll = (BOOL)lua_toboolean(L, -1) ;
        lua_pop(L, 1) ;
    }
    if (lua_gettop(L) >= 1) {
        if (lua_isboolean(L, 1))
            return luaL_argerror(L, 1, "string or nil expected") ;
        pb = lua_to_pasteboard(L, 1) ;
    } else {
        pb = [NSPasteboard generalPasteboard] ;
    }

    NSArray *results = [pb readObjectsForClasses:@[[NSColor class]] options:@{}] ;
    if (results && ([results count] != 0)) {
        if (getAll) {
            [skin pushNSObject:results] ;
        } else {
            [skin pushNSObject:[results firstObject]] ;
        }
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

static id convertToPasteboardWritableObject(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    id object ;
    if ((lua_type(L, idx) == LUA_TSTRING) || (lua_type(L, idx) == LUA_TNUMBER)) {
        luaL_tolstring(L, idx, NULL) ; // force number to be a string, but don't change value in stack
        object = [skin toNSObjectAtIndex:-1] ;
        lua_pop(L, 1) ;
    } else if (lua_type(L, idx) == LUA_TTABLE) {
        if (lua_getfield(L, idx, "url") != LUA_TNIL) {
            if (lua_type(L, -1) == LUA_TSTRING) {
                object = [NSURL URLWithString:[skin toNSObjectAtIndex:-1]] ;
            } else {
                lua_pop(L, 1) ;
                [skin logError:@"url must be a table containing a url key with a string value"] ;
                return nil ;
            }
        } else { // it's a color
            object = [skin luaObjectAtIndex:idx toClass:"NSColor"] ;
        }
        lua_pop(L, 1) ; // the value from the url key check above
    } else if (luaL_testudata(L, idx, "hs.image") ||
               luaL_testudata(L, idx, "hs.sound") ||
               luaL_testudata(L, idx, "hs.styledtext")) {
        object = [skin toNSObjectAtIndex:idx] ;
    } else {
        [skin logError:@"expected string, number, hs.image, hs.sound, hs.styledtext, color table or url table"] ;
        return nil ;
    }
    return object ;
}

/// hs.pasteboard.writeObjects(object, [name]) -> boolean
/// Function
/// Sets the pasteboard contents to the object or objects specified.
///
/// Parameters:
///  * object - an object or table of objects to set the pasteboard to.  The following objects are recognized:
///    * a lua string, which can be received by most applications that can accept text from the clipboard
///    * `hs.styledtext` object, which can be received by most applications that can accept a raw NSAttributedString (often converted internally to RTF, RTFD, HTML, etc.)
///    * `hs.sound` object, which can be received by most applications that can accept a raw NSSound object
///    * `hs.image` object, which can be received by most applications that can accept a raw NSImage object
///    * a table with the `url` key and value representing a file or resource url, which can be received by most applications that can accept an NSURL object to represent a file or a remote resource
///    * a table with keys as described in `hs.drawing.color` to represent a color, which can be received by most applications that can accept a raw NSColor object
///    * an array of one or more of the above objects, allowing you to place more than one object onto the clipboard.
///  * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
///
/// Returns:
///  * true or false indicating whether or not the clipboard contents were updated.
///
/// Notes:
///  * Most applications can only receive the first item on the clipboard.  Multiple items on a clipboard are most often used for intra-application communication where the sender and receiver are specifically written with multiple objects in mind.
static int writeObjects(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSPasteboard* pboard ;
    if (lua_gettop(L) == 1) {
        [skin checkArgs:LS_TANY, LS_TBREAK] ;
        pboard = [NSPasteboard generalPasteboard] ;
    } else {
        [skin checkArgs:LS_TANY, LS_TNUMBER | LS_TSTRING | LS_TNIL, LS_TBREAK] ;
        pboard = lua_to_pasteboard(L, 2) ;
    }

    NSMutableArray *objects = [[NSMutableArray alloc] init] ;
    if ((lua_type(L, 1) != LUA_TTABLE) ||
        ((lua_type(L, 1) == LUA_TTABLE) && ([skin maxNatIndex:1] == 0))) {
        id obj = convertToPasteboardWritableObject(L, 1) ;
        if (obj) {
            [objects addObject:obj] ;
        } else {
            return luaL_error(L, "writeObjects error") ;
        }
    } else {
        NSUInteger count = (NSUInteger)[skin maxNatIndex:1] ;
        for (NSUInteger i = 0 ; i < count ; i++) {
            lua_rawgeti(L, 1, (lua_Integer)(i + 1)) ;
            id obj = convertToPasteboardWritableObject(L, -1) ;
            lua_pop(L, 1) ;
            if (obj) {
                [objects addObject:obj] ;
            } else {
                return luaL_error(L, [[NSString stringWithFormat:@"writeObjects error at index %lu", i + 1]
                                      UTF8String]) ;
            }
        }
    }
    // got objects
    [pboard clearContents];
    lua_pushboolean(L, [pboard writeObjects:objects]) ;
    return 1 ;
}

/// hs.pasteboard.uniquePasteboard() -> string
/// Function
/// Returns the name of a new pasteboard with a name that is guaranteed to be unique with respect to other pasteboards on the computer.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a unique pasteboard name
///
/// Notes:
///  * to properly manage system resources, you should release the created pasteboard with [hs.pasteboard.deletePasteboard](#deletePasteboard) when you are certain that it is no longer necessary.
static int newUniquePasteboard(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    [skin pushNSObject:[[NSPasteboard pasteboardWithUniqueName] name]] ;
    return 1 ;
}

/// hs.pasteboard.typesAvailable([name]) -> table
/// Function
/// Returns a table indicating what content types are available on the pasteboard.
///
/// Parameters:
///  * name - an optional string indicating the pasteboard name.  If nil or not present, defaults to the system pasteboard.
///
/// Returns:
///  * a table which may contain any of the following keys set to the value true:
///    * string     - at least one element which can be represented as a string is on the pasteboard
///    * styledText - at least one element which can be represented as an `hs.styledtext` object is on the pasteboard
///    * sound      - at least one element which can be represented as an `hs.sound` object is on the pasteboard
///    * image      - at least one element which can be represented as an `hs.image` object is on the pasteboard
///    * URL        - at least one element on the pasteboard represents a URL, either to a local file or a remote resource
///    * color      - at least one element on the pasteboard represents a color, representable as a table as described in `hs.drawing.color`
///
/// Notes:
///  * almost all string and styledText objects are internally convertible and will return true for both keys
///    * if the item on the clipboard is actually just a string, the `hs.styledtext` object representation will have no attributes set
///    * if the item is actually an `hs.styledtext` object, the string representation will be the text without any attributes.
static int typesOnPasteboard(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSPasteboard* pboard = lua_to_pasteboard(L, 1);
    lua_newtable(L) ;
    if ([pboard canReadObjectForClasses:@[[NSString class]] options:@{}]) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "string") ;
    }
    if ([pboard canReadObjectForClasses:@[[NSAttributedString class]] options:@{}]) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "styledText") ;
    }
    if ([pboard canReadObjectForClasses:@[[NSSound class]] options:@{}]) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "sound") ;
    }
    if ([pboard canReadObjectForClasses:@[[NSImage class]] options:@{}]) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "image") ;
    }
    if ([pboard canReadObjectForClasses:@[[NSURL class]] options:@{}]) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "URL") ;
    }
    if ([pboard canReadObjectForClasses:@[[NSColor class]] options:@{}]) {
        lua_pushboolean(L, YES) ; lua_setfield(L, -2, "color") ;
    }
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

// Functions for returned object when module loads
static const luaL_Reg pasteboardLib[] = {
    {"changeCount",      pasteboard_changeCount},
    {"clearContents",    pasteboard_clearContents},
    {"deletePasteboard", pasteboard_delete},

    {"getContents",      pasteboard_getContents},
//     {"getImageContents", pasteboard_getImageContents},
    {"setContents",      pasteboard_setContents},
//     {"setImageContents", pasteboard_setImageContents},

    {"pasteboardTypes",  pasteboard_pasteboardTypes},
    {"contentTypes",     pasteboard_pasteboardItemTypes},

    {"allContentTypes",  allPBItemTypes},
    {"uniquePasteboard", newUniquePasteboard},
    {"typesAvailable",   typesOnPasteboard},
    {"readString",       readStringObjects},
    {"readStyledText",   readAttributedStringObjects},
    {"readSound",        readSoundObjects},
    {"readImage",        readImageObjects},
    {"readURL",          readURLObjects},
    {"readColor",        readColorObjects},
    {"writeObjects",     writeObjects},

    {"readDataForUTI",   readItemForType},
    {"writeDataForUTI",  writeItemForType},

    {"readPListForUTI",  readPropertyListForType},
    {"writePListForUTI", writePropertyListForType},

    {"readArchiverDataForUTI", readArchivedDataForType},
    {"writeArchiverDataForUTI", writeArchivedDataForType},

    {NULL,      NULL}
};

int luaopen_hs_pasteboard_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibrary:"hs.pasteboard" functions:pasteboardLib metaFunctions:nil];

//     pushPasteboardTypesTable(L) ; lua_setfield(L, -2, "types") ;
//     pushPasteboardNamesTable(L) ; lua_setfield(L, -2, "names") ;

    return 1;
}

