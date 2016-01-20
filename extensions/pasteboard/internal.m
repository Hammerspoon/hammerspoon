#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

#pragma mark - Support Functions and Classes

NSPasteboard *lua_to_pasteboard(lua_State* L, int idx) {
    LuaSkin *skin = [LuaSkin shared] ;
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
//     LuaSkin *skin = [LuaSkin shared] ;
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
//     LuaSkin *skin = [LuaSkin shared] ;
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

/// hs.pasteboard.getImageContents([name]) -> hs.image object or nil
/// Function
/// Gets the first image of the pasteboard
///
/// Parameters:
///  * name - An optional string containing the name of the pasteboard. Defaults to the system pasteboard
///
/// Returns:
///  * An `hs.image` object from the first pasteboard image, or nil if an error occurred
static int pasteboard_getImageContents(lua_State* L) {
    NSImage *image = [[NSImage alloc] initWithData:[lua_to_pasteboard(L, 1) dataForType:NSPasteboardTypePNG]];

    if (image && image.valid) {
        [[LuaSkin shared] pushNSObject:image];
    } else {
        return luaL_error(L, "No valid image data in pasteboard");
    }

    return 1;
}

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
    id str = [[LuaSkin shared] toNSObjectAtIndex:-1 withOptions:LS_NSPreserveLuaStringExactly] ;
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

/// hs.pasteboard.setImageContents(contents[, name]) -> boolean
/// Function
/// Sets the contents of the pasteboard to a PNG image
///
/// Parameters:
///  * contents - An image to be placed in the pasteboard
///  * name - An optional string containing the name of the pasteboard. Defaults to the system pasteboard
///
/// Returns:
///  * True if the operation succeeded, otherwise false
static int pasteboard_setImageContents(lua_State* L) {
    [[LuaSkin shared] checkArgs:LS_TUSERDATA, "hs.image", LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSImage*  theImage = [[LuaSkin shared] luaObjectAtIndex:1 toClass:"NSImage"] ;
    NSPasteboard* thePasteboard = lua_to_pasteboard(L, 2);

    NSData *tiffRep = [theImage TIFFRepresentation];
    if (!tiffRep)  return luaL_error(L, "Can't create internal image representation");

    NSBitmapImageRep *rep = [NSBitmapImageRep imageRepWithData:tiffRep];
    if (!rep)  return luaL_error(L, "Can't wrap internal image representation");

    NSData* pngImageData = [rep representationUsingType:NSPNGFileType properties:@{}];

    [thePasteboard clearContents];
    BOOL result = [thePasteboard setData:pngImageData forType:NSPasteboardTypePNG];

    lua_pushboolean(L, result);
    return 1;
}

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
    if ([[thePasteboard pasteboardItems] count] > 0) {
        NSPasteboardItem* item = [[thePasteboard pasteboardItems] objectAtIndex:0];
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
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TBREAK] ; // prevents nil from being specified
    luaL_checkstring(L, 1) ; // coerce number to string
    NSString *pbName = [skin toNSObjectAtIndex:1] ;
    if ([pbName isEqualToString:NSGeneralPboard] ||
        [pbName isEqualToString:NSFontPboard]    ||
        [pbName isEqualToString:NSRulerPboard]   ||
        [pbName isEqualToString:NSFindPboard]    ||
        [pbName isEqualToString:NSDragPboard]) return luaL_error(L, "cannot delete a system pasteboard") ;

    NSPasteboard *thePasteboard = [NSPasteboard pasteboardWithName:pbName];
    [thePasteboard releaseGlobally];
    return 0;
}

#pragma mark - Experimental and WhatFors

static int allPBItemTypes(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSPasteboard* thePasteboard = lua_to_pasteboard(L, 1);
    lua_newtable(L) ;
    NSArray *items = [thePasteboard pasteboardItems] ;
    for(NSUInteger i = 0 ; i < [items count]; i++) {
        lua_newtable(L) ;
        NSPasteboardItem* item = [items objectAtIndex:i];
        for (NSString* type in [item types]) {
            [skin pushNSObject:type] ; lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    return 1;
}

static int readStringObjects(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL | LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    if ((lua_type(L, 1) == LUA_TBOOLEAN) && (lua_gettop(L) != 1))
        return luaL_argerror(L, 1, "string or nil expected") ;

    NSPasteboard* pb = (lua_type(L, 1) == LUA_TBOOLEAN) ?
                          [NSPasteboard generalPasteboard] : lua_to_pasteboard(L, 1);
    BOOL getAll = (lua_type(L, lua_gettop(L)) == LUA_TBOOLEAN) ?
                          (BOOL)lua_toboolean(L, lua_gettop(L)) : NO ;

    NSArray *results = [pb readObjectsForClasses:@[[NSString class]] options:@{}] ;
    if (results) {
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

static int readAttributedStringObjects(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL | LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    if ((lua_type(L, 1) == LUA_TBOOLEAN) && (lua_gettop(L) != 1))
        return luaL_argerror(L, 1, "string or nil expected") ;

    NSPasteboard* pb = (lua_type(L, 1) == LUA_TBOOLEAN) ?
                          [NSPasteboard generalPasteboard] : lua_to_pasteboard(L, 1);
    BOOL getAll = (lua_type(L, lua_gettop(L)) == LUA_TBOOLEAN) ?
                          (BOOL)lua_toboolean(L, lua_gettop(L)) : NO ;

    NSArray *results = [pb readObjectsForClasses:@[[NSAttributedString class]] options:@{}] ;
    if (results) {
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

static int readSoundObjects(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL | LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    if ((lua_type(L, 1) == LUA_TBOOLEAN) && (lua_gettop(L) != 1))
        return luaL_argerror(L, 1, "string or nil expected") ;

    NSPasteboard* pb = (lua_type(L, 1) == LUA_TBOOLEAN) ?
                          [NSPasteboard generalPasteboard] : lua_to_pasteboard(L, 1);
    BOOL getAll = (lua_type(L, lua_gettop(L)) == LUA_TBOOLEAN) ?
                          (BOOL)lua_toboolean(L, lua_gettop(L)) : NO ;

    NSArray *results = [pb readObjectsForClasses:@[[NSSound class]] options:@{}] ;
    if (results) {
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

static int readImageObjects(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL | LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    if ((lua_type(L, 1) == LUA_TBOOLEAN) && (lua_gettop(L) != 1))
        return luaL_argerror(L, 1, "string or nil expected") ;

    NSPasteboard* pb = (lua_type(L, 1) == LUA_TBOOLEAN) ?
                          [NSPasteboard generalPasteboard] : lua_to_pasteboard(L, 1);
    BOOL getAll = (lua_type(L, lua_gettop(L)) == LUA_TBOOLEAN) ?
                          (BOOL)lua_toboolean(L, lua_gettop(L)) : NO ;

    NSArray *results = [pb readObjectsForClasses:@[[NSImage class]] options:@{}] ;
    if (results) {
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

static int readURLObjects(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL | LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    if ((lua_type(L, 1) == LUA_TBOOLEAN) && (lua_gettop(L) != 1))
        return luaL_argerror(L, 1, "string or nil expected") ;

    NSPasteboard* pb = (lua_type(L, 1) == LUA_TBOOLEAN) ?
                          [NSPasteboard generalPasteboard] : lua_to_pasteboard(L, 1);
    BOOL getAll = (lua_type(L, lua_gettop(L)) == LUA_TBOOLEAN) ?
                          (BOOL)lua_toboolean(L, lua_gettop(L)) : NO ;

    NSArray *results = [pb readObjectsForClasses:@[[NSURL class]] options:@{}] ;
    if (results) {
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

static int readColorObjects(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL | LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBOOLEAN | LS_TOPTIONAL,
                    LS_TBREAK] ;
    if ((lua_type(L, 1) == LUA_TBOOLEAN) && (lua_gettop(L) != 1))
        return luaL_argerror(L, 1, "string or nil expected") ;

    NSPasteboard* pb = (lua_type(L, 1) == LUA_TBOOLEAN) ?
                          [NSPasteboard generalPasteboard] : lua_to_pasteboard(L, 1);
    BOOL getAll = (lua_type(L, lua_gettop(L)) == LUA_TBOOLEAN) ?
                          (BOOL)lua_toboolean(L, lua_gettop(L)) : NO ;

    NSArray *results = [pb readObjectsForClasses:@[[NSColor class]] options:@{}] ;
    if (results) {
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
    LuaSkin *skin = [LuaSkin shared] ;
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

static int writeObjects(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    int objectsIndex = lua_gettop(L) ;
    NSPasteboard* pboard ;
    if (objectsIndex == 1) {
        [skin checkArgs:LS_TANY, LS_TBREAK] ;
        pboard = [NSPasteboard generalPasteboard] ;
    } else {
        [skin checkArgs:LS_TNUMBER | LS_TSTRING | LS_TNIL, LS_TANY, LS_TBREAK] ;
        pboard = lua_to_pasteboard(L, 1) ;
    }

    NSMutableArray *objects = [[NSMutableArray alloc] init] ;
    if ((lua_type(L, objectsIndex) != LUA_TTABLE) ||
        ((lua_type(L, objectsIndex) == LUA_TTABLE) && ([skin maxNatIndex:objectsIndex] == 0))) {
        id obj = convertToPasteboardWritableObject(L, objectsIndex) ;
        if (obj) {
            [objects addObject:obj] ;
        } else {
            return luaL_error(L, "writeObjects error") ;
        }
    } else {
        NSUInteger count = (NSUInteger)[skin maxNatIndex:objectsIndex] ;
        for (NSUInteger i = 0 ; i < count ; i++) {
            lua_rawgeti(L, objectsIndex, (lua_Integer)(i + 1)) ;
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

// static int pasteboard_setImageContents2(lua_State* L) {
//     [[LuaSkin shared] checkArgs:LS_TUSERDATA, "hs.image", LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
//     NSImage*  theImage = [[LuaSkin shared] luaObjectAtIndex:1 toClass:"NSImage"] ;
//     NSPasteboard* thePasteboard = lua_to_pasteboard(L, 2);
//
//     [thePasteboard clearContents];
//     BOOL result = [thePasteboard writeObjects:@[ theImage ]] ;
//
//     lua_pushboolean(L, result);
//     return 1;
// }

static int newUniquePasteboard(__unused lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TBREAK] ;
    [skin pushNSObject:[[NSPasteboard pasteboardWithUniqueName] name]] ;
    return 1 ;
}

static int typesOnPasteboard(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
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
    {"getImageContents", pasteboard_getImageContents},
    {"setContents",      pasteboard_setContents},
    {"setImageContents", pasteboard_setImageContents},

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

    {NULL,      NULL}
};

int luaopen_hs_pasteboard_internal(lua_State* L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    [skin registerLibrary:pasteboardLib metaFunctions:nil];

//     pushPasteboardTypesTable(L) ; lua_setfield(L, -2, "types") ;
//     pushPasteboardNamesTable(L) ; lua_setfield(L, -2, "names") ;

    return 1;
}

