@import Cocoa ;
@import LuaSkin ;

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

    uint32_t rand = arc4random();
    double val = ((double)rand / UINT32_MAX);

    lua_pushnumber(L, val);
    return 1;
}

/// hs.math.randomFromRange(start, end) -> integer
/// Function
/// Returns a random integer between the start and end paramters
///
/// Parameters:
///  * start - A number to start the range, must be greater than or equal to zero
///  * end - A number to end the range, must be greater than zero and greater than `start`
///
/// Returns:
///  * A randomly chosen integer between `start` and `end`
static int math_randomFromRange(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER, LS_TNUMBER, LS_TBREAK] ;

    int start = (int)lua_tointeger(L, 1);
    int end = (int)lua_tointeger(L, 2);

    if (start < 0 || end <= 0 || end <= start) {
        [skin logError:[NSString stringWithFormat:@"Please check the docs for hs.math.randomForRange() - your range is not acceptable (%d -> %d)", start, end]];
        lua_pushnil(L);
        return 1;
    }

    int result = arc4random_uniform(end - start + 1) + start;

    lua_pushinteger(L, result);
    return 1;
}

// Functions for returned object when module loads
static const luaL_Reg mathLib[] = {
    {"randomFloat",  math_randomFloat},
    {"randomFromRange",  math_randomFromRange},

    {NULL,      NULL}
};

int luaopen_hs_libmath(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibrary:"hs.math" functions:mathLib metaFunctions:nil];

    return 1;
}
