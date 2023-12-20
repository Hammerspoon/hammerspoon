@import Cocoa ;
@import LuaSkin ;
@import Hammertime ;

#import <stdlib.h>

/// hs.math.randomFloat() -> number
/// Function
/// Returns a random floating point number between 0 and 1
///
/// Parameters:
///  * None
///
/// Returns:
///  * A random number between 0 and 1
static int math_randomFloat(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    Math *math = [[Math alloc] init];
    lua_pushnumber(L, [math randomDouble]);

    return 1;
}

/// hs.math.randomFloatFromRange(start, end) -> number
/// Function
/// Returns a random floating point number in the supplied range
///
/// Parameters:
///  * start - Lower bound of the range
///  * end - Upper bound of the range
///
/// Returns:
///  * A random number
static int math_randomFloatFromRange(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TNUMBER, LS_TNUMBER, LS_TBREAK];

    Math *math = [[Math alloc] init];
//    double start = lua_tonumber(L, 1);
//    double end = lua_tonumber(L, 2);

//    if (![math validateDoubleRangeWithStart:start end:end]) {
//        [skin logError:@"hs.math.randomFloatFromRange: start must be <= end"];
//        lua_pushnil(L);
//        return 1;
//    }

    @try {
        lua_pushnumber(L, [math randomDoubleInRangeWithStart:lua_tonumber(L, 1) end:lua_tonumber(L, 2)]);
    } @catch (NSException *e){
        [skin logError:e.reason];
        lua_pushnil(L);
    }
    return 1;
}

/// hs.math.randomFromRange(start, end) -> integer
/// Function
/// Returns a random integer between the start and end parameters
///
/// Parameters:
///  * start - Lower bound of the range
///  * end - Upper bound of the range
///
/// Returns:
///  * A randomly chosen integer between `start` and `end`
static int math_randomFromRange(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER, LS_TNUMBER, LS_TBREAK] ;

    Math *math = [[Math alloc] init];
    int start = (int)lua_tointeger(L, 1);
    int end = (int)lua_tointeger(L, 2);

    if (![math validateIntRangeWithStart:start end:end]) {
        [skin logError:@"hs.math.randomFromRange: start must be <= end"];
        lua_pushnil(L);
        return 1;
    }

    lua_pushinteger(L, [math randomIntInRangeWithStart:lua_tointeger(L, 1) end:lua_tointeger(L, 2)]);
    return 1;
}

// Functions for returned object when module loads
static const luaL_Reg mathLib[] = {
    {"randomFloat",  math_randomFloat},
    {"randomFloatFromRange", math_randomFloatFromRange},
    {"randomFromRange",  math_randomFromRange},

    {NULL,      NULL}
};

int luaopen_hs_libmath(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibrary:"hs.math" functions:mathLib metaFunctions:nil];

    return 1;
}
