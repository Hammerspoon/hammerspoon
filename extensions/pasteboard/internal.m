#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

NSPasteboard *lua_to_pasteboard(lua_State* L, int idx) {
    if (!lua_isnoneornil(L, idx)) {
        return [NSPasteboard pasteboardWithName:[NSString stringWithUTF8String:luaL_checkstring(L, idx)]];
    } else {
        return [NSPasteboard generalPasteboard];
    }

}

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
    NSPasteboard *thePasteboard = [NSPasteboard pasteboardWithName:[NSString stringWithUTF8String:luaL_checkstring(L, 1)]];
    [thePasteboard releaseGlobally];

    return 0;
}

// Functions for returned object when module loads
static const luaL_Reg pasteboardLib[] = {
    {"changeCount",      pasteboard_changeCount},
    {"getContents",      pasteboard_getContents},
    {"getImageContents", pasteboard_getImageContents},
    {"setContents",      pasteboard_setContents},
    {"setImageContents", pasteboard_setImageContents},
    {"clearContents",    pasteboard_clearContents},
    {"pasteboardTypes",  pasteboard_pasteboardTypes},
    {"contentTypes",     pasteboard_pasteboardItemTypes},
    {"deletePasteboard", pasteboard_delete},
    {NULL,      NULL}
};

int luaopen_hs_pasteboard_internal(lua_State* L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    [skin registerLibrary:pasteboardLib metaFunctions:nil];

    return 1;
}

