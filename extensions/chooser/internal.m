#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import "../Hammerspoon.h"
#import "chooser.h"

#pragma mark - Lua API - Constructors

/// hs.chooser.new(numRows, width[, fontName[, fontSize]]) -> hs.chooser object
/// Constructor
/// Creates a new chooser object
///
/// Parameters:
///  * numRows - The number of results rows to show
///  * width - The width of the chooser window as a percentage of the main screen's width
///  * fontName - An optional font name to use
///  * fontSize - An optional floating point font size to use
///
/// Returns:
///  * An `hs.chooser` object
///
/// Notes:
///  * You can get a list of available font names with `hs.styledtext.fontNames()`
static int chooserNew(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TNUMBER, LS_TNUMBER, LS_TSTRING|LS_TNUMBER|LS_TOPTIONAL, LS_TNUMBER|LS_TOPTIONAL, LS_TBREAK];

    // Create the userdata object
    chooser_userdata_t *userData = lua_newuserdata(L, sizeof(chooser_userdata_t));
    memset(userData, 0, sizeof(chooser_userdata_t));
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    // Parse function arguents
    NSInteger numRows = (NSInteger)lua_tointeger(L, 1);
    CGFloat width = (CGFloat)lua_tonumber(L, 2);

    NSString *chooseFontName = nil;
    CGFloat chooseFontSize = 0.0;

    if (lua_type(L, 3) == LUA_TSTRING) {
        chooseFontName = [skin toNSObjectAtIndex:3];
    } else if (lua_type(L, 3) == LUA_TNUMBER) {
        chooseFontSize = (CGFloat)lua_tonumber(L, 3);
    }
    if (lua_type(L, 4) == LUA_TNUMBER) {
        chooseFontSize = (CGFloat)lua_tonumber(L, 4);
    }

    // Create the HSChooser object with our arguments
    HSChooser *chooser = [[HSChooser alloc] initWithRows:numRows width:width fontName:chooseFontName fontSize:chooseFontSize refTable:&refTable];
    userData->chooser = (__bridge_retained void*)chooser;

    return 1;
}

#pragma mark - Lua API - Methods

/// hs.chooser:show() -> hs.chooser object
/// Method
/// Displays the chooser
///
/// Parameters:
///  * Nonw
///
/// Returns:
///  * The hs.chooser object
static int chooserShow(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

    [chooser show];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:hide() -> hs.chooser object
/// Method
/// Hides the chooser
///
/// Parameters:
///  * None
///
/// Returns:
///  * The hs.chooser object
static int chooserHide(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

    [chooser hide];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:setChoices(choices) -> hs.chooser object
/// Method
/// Sets the choices for a chooser
///
/// Parameters:
///  * choices - Either a function to call when the list of choices is needed, or a table containing static choices, or nil to remove any existing choices
///
/// Returns:
///  * The hs.chooser object
static int chooserSetChoices(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TTABLE | LS_TNIL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

    [chooser clearChoices];

    switch (lua_type(L, 2)) {
        case LUA_TNIL:
            break;

        case LUA_TFUNCTION:
            chooser.choicesCallbackRef = [skin luaRef:refTable atIndex:2];
            break;

        case LUA_TTABLE:
            chooser.choicesCallbackRef = [skin luaUnref:refTable ref:chooser.choicesCallbackRef];
            chooser.currentStaticChoices = [skin toNSObjectAtIndex:2];
            break;

        default:
            NSLog(@"Unknown type in chooserSetChoices. This should be impossible");
            break;
    }

    [chooser updateChoices];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:queryChangedCallback([fn]) -> hs.chooser object
/// Method
/// Sets/clears a callback for when the search query changes
///
/// Parameters:
///  * fn - An optional function that will be called whenever the search query changes. The function should accept a single argument, a string containing the new search query. It should return nothing. If this parameter is omitted, the existing callback will be removed
///
/// Returns:
///  * The hs.chooser object
static int chooserQueryCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

    chooser.queryChangedCallbackRef = [skin luaUnref:refTable ref:chooser.queryChangedCallbackRef];
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        chooser.queryChangedCallbackRef = [skin luaRef:refTable atIndex:2];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:delete()
/// Method
/// Deletes a chooser
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int chooserDelete(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    return userdata_gc(L);
}

#pragma mark - Hammerspoon Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    chooser_userdata_t *userData = lua_touserdata(L, 1);
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, userData]];
    return 1;
}

static int userdata_gc(lua_State* L) {
    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge_transfer HSChooser *)userData->chooser;
    userData->chooser = nil;
    chooser = nil;

    return 0;
}

static const luaL_Reg chooserLib[] = {
    {"new", chooserNew},

    {NULL, NULL}
};

// Metatable for userdata objects
static const luaL_Reg userdataLib[] = {
    {"show", chooserShow},
    {"hide", chooserHide},
    {"choices", chooserSetChoices},
    {"queryChangedCallback", chooserQueryCallback},
    {"delete", chooserDelete},

    {"__tostring", userdata_tostring},
    {"__gc", userdata_gc},
    {NULL, NULL}
};

int luaopen_hs_chooser_internal(__unused lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:chooserLib
                                 metaFunctions:nil // metalib
                               objectFunctions:userdataLib];

    return 1;
}
