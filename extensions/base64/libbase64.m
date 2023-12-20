@import Cocoa;
@import LuaSkin;
@import Hammertime;

/// hs.base64.encode(val[,width]) -> str
/// Function
/// Encodes a given string to base64
///
/// Parameters:
///  * val - A string to encode as base64
///  * width - Optional line width to split the string into (usually 64 or 76)
///
/// Returns:
///  * A string containing the base64 representation of the input string
static int base64_encode(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TNUMBER | LS_TSTRING, LS_TNUMBER|LS_TOPTIONAL, LS_TBREAK];
    Base64 *b64 = [[Base64 alloc] init];

    NSUInteger sz ;
    const char *data = luaL_tolstring(L, 1, &sz) ;
    NSData *input = [[NSData alloc] initWithBytes:data length:sz] ;

    NSString *output = nil;
    if (lua_type(L, 2) == LUA_TNUMBER) {
        output = [b64 encodeWithData:input width:lua_tointeger(L, 2)];
    } else {
        output = [b64 encodeWithData:input];
    }
    [skin pushNSObject:output];

    return 1;
}

/// hs.base64.decode(str) -> val
/// Function
/// Decodes a given base64 string
///
/// Parameters:
///  * str - A base64 encoded string
///
/// Returns:
///  * A string containing the decoded data, or nil if it couldn't be decoded
static int base64_decode(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TNUMBER | LS_TSTRING, LS_TBREAK];
    Base64 *b64 = [[Base64 alloc] init];

    const char *data = lua_tostring(L, 1);
    NSString *input = [NSString stringWithUTF8String:data];

    @try {
        NSData *output = [b64 decodeWithInput:input];
        [skin pushNSObject:output];
    } @catch (NSException *e) {
        [skin logError:@"Unable to decode input"];
        lua_pushnil(L);
    }

    return 1;
}

static const luaL_Reg base64_lib[] = {
    {"encode", base64_encode},
    {"decode", base64_decode},
    {NULL,      NULL}
};

int luaopen_hs_libbase64(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibrary:"hs.base64" functions:base64_lib metaFunctions:nil];

    return 1;
}
