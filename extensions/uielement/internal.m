@import Cocoa ;
@import Carbon ;
@import LuaSkin ;
#import "HSuicore.h"

#define get_element(L, idx) *((AXUIElementRef*)lua_touserdata(L, idx))

static const char* USERDATA_TAG = "hs.uielement";
static LSRefTable refTable = LUA_NOREF;
#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

/// hs.uielement.focusedElement() -> element or nil
/// Function
/// Gets the currently focused UI element
///
/// Parameters:
///  * None
///
/// Returns:
///  * An `hs.uielement` object or nil if no object could be found
static int uielement_focusedElement(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];
    HSuielement *element = [HSuielement focusedElement];
    [skin pushNSObject:element];
    return 1;
}

/// hs.uielement:isWindow() -> bool
/// Method
/// Returns whether the UI element represents a window.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if the UI element is a window, otherwise false
static int uielement_iswindow(lua_State* L) {
    // NOTE: If you find yourself modifying this method, you should check hs.application and hs.window, since they contain clones of it
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSuielement *element = [skin toNSObjectAtIndex:1];
    lua_pushboolean(L, element.isWindow);
    return 1;
}

/// hs.uielement:role() -> string
/// Method
/// Returns the role of the element.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the role of the UI element
static int uielement_role(lua_State* L) {
    // NOTE: If you find yourself modifying this method, you should check hs.application and hs.window, since they contain clones of it
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSuielement *element = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:element.role];
    return 1;
}

/// hs.uielement:selectedText() -> string or nil
/// Method
/// Returns the selected text in the element
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the selected text, or nil if none could be found
///
/// Notes:
///  * Many applications (e.g. Safari, Mail, Firefox) do not implement the necessary accessibility features for this to work in their web views
static int uielement_selectedText(lua_State* L) {
    // NOTE: If you find yourself modifying this method, you should check hs.application and hs.window, since they contain clones of it
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSuielement *element = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:element.selectedText];
    return 1;
}

/// hs.uielement:newWatcher(handler[, userData]) -> hs.uielement.watcher or nil
/// Method
/// Creates a new watcher
///
/// Parameters:
///  * A function to be called when a watched event occurs.  The function will be passed the following arguments:
///    * element: The element the event occurred on. Note this is not always the element being watched.
///    * event: The name of the event that occurred.
///    * watcher: The watcher object being created.
///    * userData: The userData you included, if any.
///  * an optional userData object which will be included as the final argument to the callback function when it is called.
///
/// Returns:
///  * An `hs.uielement.watcher` object, or `nil` if an error occurred
static int uielement_newWatcher(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION, LS_TANY|LS_TOPTIONAL, LS_TBREAK];

    HSuielement *uiElement = [skin toNSObjectAtIndex:1];
    HSuielementWatcher *watcher = [uiElement newWatcherAtIndex:2 withUserdataAtIndex:3 withLuaState:L];
    [skin pushNSObject:watcher];

    return 1;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSuielement(lua_State *L, id obj) {
    HSuielement *value = obj;
    value.selfRefCount++;
    void** valuePtr = lua_newuserdata(L, sizeof(HSuielement *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSuielementFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    HSuielement *value;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSuielement, L, idx, USERDATA_TAG);
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                        lua_typename(L, lua_type(L, idx))]];
    }
    return value;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int uielement_eq(lua_State* L) {
    BOOL isEqual = NO;
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L];
        HSuielement *element1 = [skin toNSObjectAtIndex:1];
        HSuielement *element2 = [skin toNSObjectAtIndex:2];
        isEqual = CFEqual(element1.elementRef, element2.elementRef);
    }
    lua_pushboolean(L, isEqual);
    return 1;
}

// Clean up a bare uielement if it isn't needed anymore.
static int uielement_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSuielement *element = get_objectFromUserdata(__bridge_transfer HSuielement, L, 1, USERDATA_TAG);
    if (element) {
        element.selfRefCount--;
        if (element.selfRefCount == 0) {
            element = nil;
        }
    }

    // Remove the Metatable so future use of the variable in Lua won't think it's valid
    lua_pushnil(L);
    lua_setmetatable(L, 1);
    return 0;
}

static const luaL_Reg moduleLib[] = {
    {"focusedElement", uielement_focusedElement},

    {NULL, NULL}
};

static const luaL_Reg module_metaLib[] = {
    {NULL, NULL}
};

static const luaL_Reg userdata_metaLib[] = {
    {"role", uielement_role},
    {"isWindow", uielement_iswindow},
    {"selectedText", uielement_selectedText},
    {"newWatcher", uielement_newWatcher},
    {"__eq", uielement_eq},
    {"__gc", uielement_gc},

    {NULL, NULL}
};

int luaopen_hs_uielement_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibrary:USERDATA_TAG functions:moduleLib metaFunctions:module_metaLib];
    [skin registerObject:USERDATA_TAG objectFunctions:userdata_metaLib];
    [skin registerPushNSHelper:pushHSuielement         forClass:"HSuielement"];
    [skin registerLuaObjectHelper:toHSuielementFromLua forClass:"HSuielement"
                                            withUserdataMapping:USERDATA_TAG];

    return 1;
}
