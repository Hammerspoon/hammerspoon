#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import "../Hammerspoon.h"
#import "chooser.h"

#pragma mark - Lua API - Constructors

/// hs.chooser.new(completionFn) -> hs.chooser object
/// Constructor
/// Creates a new chooser object
///
/// Parameters:
///  * completionFn - A function that will be called when the chooser is dismissed. It should accept one parameter, which will be nil if the user dismissed the chooser window, otherwise it will be a table containing whatever information you supplied for the item the user chose.
///
/// Returns:
///  * An `hs.chooser` object
static int chooserNew(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK];

    // Create the userdata object
    chooser_userdata_t *userData = lua_newuserdata(L, sizeof(chooser_userdata_t));
    memset(userData, 0, sizeof(chooser_userdata_t));
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    // Parse function arguents
    lua_pushvalue(L, 1);
    int completionCallbackRef = [skin luaRef:refTable];

    // Create the HSChooser object with our arguments
    HSChooser *chooser = [[HSChooser alloc] initWithRefTable:&refTable completionCallbackRef:completionCallbackRef];
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

/// hs.chooser:choices(choices) -> hs.chooser object
/// Method
/// Sets the choices for a chooser
///
/// Parameters:
///  * choices - Either a function to call when the list of choices is needed, or a table containing static choices, or nil to remove any existing choices. The table (be it provided statically, or returned by the callback) must contain at least the following keys for each choice:
///   * text - A string that will be shown as the main text of the choice
///
/// Returns:
///  * The hs.chooser object
///
/// Notes:
///  * Each choice may also optionally contain the following keys:
///   * subText - A string that will be shown underneath the main text of the choice
///   * image - An `hs.image` image object that will be displayed next to the choice
///  * Any other keys/values in each choice table will be retained by the chooser and returned to the completion callback when a choice is made. This is useful for storing UUIDs or other non-user-facing information, however, it is important to note that you should not store userdata objects in the table - it is run through internal conversion functions, so only basic Lua types should be stored.
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
            // FIXME: We should at least lightly validate that we have an array of dictionaries here
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

/// hs.chooser:bgColor([color]) -> hs.chooser object or color table
/// Method
/// Sets the background color of the chooser
///
/// Parameters:
///  * color - An optional table containing a color specification (see `hs.drawing.color`). If this parameter is omitted, the existing color will be returned
///
/// Returns:
///  * The `hs.chooser` object or a color table
static int chooserSetBgColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

    switch (lua_type(L, 2)) {
        case LUA_TTABLE:
            chooser.bgColor = [skin luaObjectAtIndex:2 toClass:"NSColor"];
            break;

        case LUA_TNONE:
            return ([skin pushNSObject:chooser.bgColor]);

        default:
            NSLog(@"ERROR: Unknown type in hs.chooser:bgColor(). This should not be possible");
            break;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:fgColor(color) -> hs.chooser object
/// Method
/// Sets the foreground color of the chooser
///
/// Parameters:
///  * color - An optional table containing a color specification (see `hs.drawing.color`). If this parameter is omitted, the existing color will be returned
///
/// Returns:
///  * The `hs.chooser` object or a color table
static int chooserSetFgColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

    switch (lua_type(L, 2)) {
        case LUA_TTABLE:
            chooser.fgColor = [skin luaObjectAtIndex:2 toClass:"NSColor"];
            break;

        case LUA_TNONE:
            return ([skin pushNSObject:chooser.fgColor]);

        default:
            NSLog(@"ERROR: Unknown type in hs.chooser:bgColor(). This should not be possible");
            break;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:subTextColor(color) -> hs.chooser object
/// Method
/// Sets the sub-text color of the chooser
///
/// Parameters:
///  * color - An optional table containing a color specification (see `hs.drawing.color`). If this parameter is omitted, the existing color will be returned
///
/// Returns:
///  * The `hs.chooser` object or a color table
static int chooserSetSubTextColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

    switch (lua_type(L, 2)) {
        case LUA_TTABLE:
            chooser.subTextColor = [skin luaObjectAtIndex:2 toClass:"NSColor"];
            break;

        case LUA_TNONE:
            return ([skin pushNSObject:chooser.subTextColor]);

        default:
            NSLog(@"ERROR: Unknown type in hs.chooser:bgColor(). This should not be possible");
            break;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser.searchSubText([searchSubText]) -> hs.chooser object or boolean
/// Method
/// Gets/Sets whether the chooser should search in the sub-text of each item
///
/// Parameters:
///  * searchSubText - An optional boolean, true to search sub-text, false to not search sub-text. If this parameter is omitted, the current configuration value will be returned
///
/// Returns:
///  * The hs.chooser object if a value was set, or a boolean if no parameter was passed
static int chooserSetSearchSubText(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

    switch (lua_type(L, 2)) {
        case LUA_TBOOLEAN:
            chooser.searchSubText = lua_toboolean(L, 2);
            break;

        case LUA_TNONE:
            lua_pushboolean(L, chooser.searchSubText);
            return 1;

        default:
            NSLog(@"ERROR: Unknown type passed to hs.chooser:searchSubText(). This shouldn't be possible");
            break;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:width([percent]) -> hs.chooser object or number
/// Method
/// Gets/Sets the width of the chooser
///
/// Parameters:
///  * percent - An optional number indicating the percentage of the width of the screen that the chooser should occupy. If this parameter is omitted, the current width will be returned
///
/// Returns:
///  * The `hs.chooser` object or a number
static int chooserSetWidth(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

    switch (lua_type(L, 2)) {
        case LUA_TNUMBER:
            chooser.width = (CGFloat)lua_tonumber(L, 2);
            lua_pushvalue(L, 1);
            break;

        case LUA_TNONE:
            lua_pushnumber(L, chooser.width);
        default:
            break;
    }
    lua_pushvalue(L, 1);
    return 1;
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

    {"bgColor", chooserSetBgColor},
    {"fgColor", chooserSetFgColor},
    {"subTextColor", chooserSetSubTextColor},

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
