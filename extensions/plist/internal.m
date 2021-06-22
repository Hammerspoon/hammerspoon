@import Cocoa;
@import LuaSkin;

/// hs.plist.read(filepath) -> table
/// Function
/// Loads a Property List file
///
/// Parameters:
///  * filepath - The path and filename of a plist file to read
///
/// Returns:
///  * The contents of the plist as a Lua table
static int plist_read(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];

    NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:[[skin toNSObjectAtIndex:1] stringByExpandingTildeInPath]];
    [skin pushNSObject:plist];

    return 1;
}

/// hs.plist.readString(value, [binary]) -> table | nil
/// Function
/// Interpretes a property list file within a string into a table.
///
/// Parameters:
///  * value  - The contents of the property list as a string
///  * binary - an optional boolean, specifying whether the value should be treated as raw binary (true) or as an UTF8 encoded string (false). If you do not provide this argument, the function will attempt to auto-detect the type.
///
/// Returns:
///  * The contents of the property list as a Lua table or `nil` if an error occurs
static int plist_readString(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];

    NSString *source = [skin toNSObjectAtIndex:1];
    BOOL binary = (lua_gettop(L) > 1) ? (BOOL)(lua_toboolean(L, 2)) : [source hasPrefix:@"bplist"] ;

    NSData *plistData ;
    if (binary) {
        plistData = [skin toNSObjectAtIndex:1 withOptions:LS_NSLuaStringAsDataOnly] ;
    } else {
        plistData = [source dataUsingEncoding:NSUTF8StringEncoding];
    }

    NSError *error;
    NSPropertyListFormat format;
    NSDictionary* plist = [NSPropertyListSerialization propertyListWithData:plistData options:NSPropertyListImmutable format:&format error:&error];

    if (!plist) {
        [skin logError:[NSString stringWithFormat:@"hs.plist.readString(): %@", error]];
        lua_pushnil(L);
        return 1;
    }

    [skin pushNSObject:plist];

    return 1;
}

/// hs.plist.writeString(data, [binary]) -> string | nil
/// Function
/// Interpretes a property list file within a string into a table.
///
/// Parameters:
///  * data - A Lua table containing the data to write into a plist string
///  * binary - an optional boolean, default false, specifying that the resulting string should be encoded as a binary plist.
///
/// Returns:
///  * A string representing the data as a plist or nil if there was a problem with the date or serialization.
static int plist_writeString(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TTABLE, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];

    id data = [skin toNSObjectAtIndex:1 withOptions:LS_NSPreserveLuaStringExactly];
    BOOL binary = (lua_gettop(L) > 1) ? (BOOL)(lua_toboolean(L, 2)) : NO ;

    if (![NSPropertyListSerialization propertyList:data isValidForFormat:(binary ? NSPropertyListBinaryFormat_v1_0 : NSPropertyListXMLFormat_v1_0)]) {
        [skin logError:@"hs.plist.writeString: data supplied is not in a suitable format to serialize as a plist"];
        lua_pushboolean(L, false);
        return 1;
    }

    NSError *error;
    NSData *output = [NSPropertyListSerialization dataWithPropertyList: data
                                                                format: (binary ? NSPropertyListBinaryFormat_v1_0 : NSPropertyListXMLFormat_v1_0)
                                                               options: 0
                                                                 error: &error];
    if (output == nil) {
        [skin logError:[NSString stringWithFormat:@"hs.plist.writeString: error serializing to plist representation: %@", error.localizedDescription]];
        lua_pushnil(L) ;
        return 1;
    } else {
        [skin pushNSObject:output] ;
    }
    return 1 ;
}

/// hs.plist.write(filepath, data[, binary]) -> boolean
/// Function
/// Writes a Property List file
///
/// Parameters:
///  * filepath - The path and filename of the plist file to write
///  * data - A Lua table containing the data to write into the plist
///  * binary - An optional boolean, if true, the plist will be written as a binary file. Defaults to false
///
/// Returns:
///  * A boolean, true if the plist was written successfully, otherwise false
///
/// Notes:
///  * Only simple types can be converted to plist items:
///   * Strings
///   * Numbers
///   * Booleans
///   * Tables
///  * You should be careful when reading a plist, modifying and writing it - Hammerspoon may not be able to preserve all of the datatypes via Lua
static int plist_write(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TTABLE, LS_TBOOLEAN|LS_TOPTIONAL, LS_TBREAK];

    NSString *filePath = [[skin toNSObjectAtIndex:1] stringByExpandingTildeInPath];
    id data = [skin toNSObjectAtIndex:2 withOptions:LS_NSPreserveLuaStringExactly];
    BOOL binary = NO;

    if (lua_type(L, 3) == LUA_TBOOLEAN) {
        binary = lua_toboolean(L, 3);
    }

    if (![NSPropertyListSerialization propertyList:data isValidForFormat:(binary ? NSPropertyListBinaryFormat_v1_0 : NSPropertyListXMLFormat_v1_0)]) {
        [skin logError:@"hs.plist.write(): Data supplied is not in a suitable format to write to a plist file"];
        lua_pushboolean(L, false);
        return 1;
    }

    NSError *error;
    NSData *output = [NSPropertyListSerialization dataWithPropertyList: data
                                                                format: (binary ? NSPropertyListBinaryFormat_v1_0 : NSPropertyListXMLFormat_v1_0)
                                                               options: 0
                                                                 error: &error];
    if (output == nil) {
        NSLog (@"error serializing to xml: %@", error);
        lua_pushboolean(L, false);
        return 1;
    }

    BOOL writeStatus = [output writeToFile: filePath
                                   options: NSDataWritingAtomic
                                     error: &error];
    if (!writeStatus) {
        NSLog (@"error writing to file: %@", error);
        lua_pushboolean(L, false);
        return 1;
    }

    lua_pushboolean(L, true);
    return 1;
}

static const luaL_Reg plistlib[] = {
    {"read", plist_read},
    {"readString", plist_readString},
    {"writeString", plist_writeString},
    {"write", plist_write},
    {NULL, NULL}
};

int luaopen_hs_plist_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    [skin registerLibrary:"hs.plist" functions:plistlib metaFunctions:nil];

    return 1;
}

