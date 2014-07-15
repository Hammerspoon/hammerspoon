#import <Carbon/Carbon.h>
#import "helpers.h"
void hydra_pushkeycodestable(lua_State* L);

/// hotkey
///
/// Create and manage global hotkeys.
///
/// The `mods` field is case-insensitive and may contain any of the following strings: "cmd", "ctrl", "alt", or "shift".
///
/// The `key` field is case-insensitive and may be any single-character string; it may also be any of the following strings:
///
///     F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12, F13, F14, F15,
///     F16, F17, F18, F19, F20, PAD, PAD*, PAD+, PAD/, PAD-, PAD=,
///     PAD0, PAD1, PAD2, PAD3, PAD4, PAD5, PAD6, PAD7, PAD8, PAD9,
///     PAD_CLEAR, PAD_ENTER, RETURN, TAB, SPACE, DELETE, ESCAPE, HELP,
///     HOME, PAGE_UP, FORWARD_DELETE, END, PAGE_DOWN, LEFT, RIGHT, DOWN, UP

/// hotkey.keycodes
/// A mapping from string representation of a key to its keycode, and vice versa; not generally useful yet.
/// For example: keycodes[1] == "s", and keycodes["s"] == 1, and so on

typedef struct _hotkey_t {
    UInt32 mods;
    UInt32 keycode;
    UInt32 uid;
    int fnref;
    BOOL enabled;
    EventHotKeyRef carbonHotKey;
} hotkey_t;



/// hotkey.new(mods, key, fn) -> hotkey
/// Creates a new hotkey that can be enabled.
static int hotkey_new(lua_State* L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    const char* key = [[[NSString stringWithUTF8String:luaL_checkstring(L, 2)] lowercaseString] UTF8String];
    luaL_checktype(L, 3, LUA_TFUNCTION);
    
    hotkey_t* hotkey = lua_newuserdata(L, sizeof(hotkey_t));
    memset(hotkey, 0, sizeof(hotkey_t));
    
    // set global 'hotkey' as its metatable
    luaL_getmetatable(L, "hotkey");
    lua_setmetatable(L, -2);
    
    // store function
    lua_pushvalue(L, 3);
    hotkey->fnref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    // get keycode
    lua_getglobal(L, "hotkey");
    lua_getfield(L, -1, "keycodes");
    lua_pushstring(L, key);
    lua_gettable(L, -2);
    hotkey->keycode = lua_tonumber(L, -1);
    lua_pop(L, 3);
    
    // save mods
    lua_pushnil(L);
    while (lua_next(L, 1) != 0) {
        NSString* mod = [[NSString stringWithUTF8String:luaL_checkstring(L, -1)] lowercaseString];
        if ([mod isEqualToString: @"cmd"]) hotkey->mods |= cmdKey;
        else if ([mod isEqualToString: @"ctrl"]) hotkey->mods |= controlKey;
        else if ([mod isEqualToString: @"alt"]) hotkey->mods |= optionKey;
        else if ([mod isEqualToString: @"shift"]) hotkey->mods |= shiftKey;
        lua_pop(L, 1);
    }
    
    return 1;
}

/// hotkey:enable() -> self
/// Registers the hotkey's fn as the callback when the user presses key while holding mods.
static int hotkey_enable(lua_State* L) {
    hotkey_t* hotkey = luaL_checkudata(L, 1, "hotkey");
    lua_settop(L, 1);
    
    if (hotkey->enabled)
        return 1;
    
    hotkey->enabled = YES;
    
    // store hotkey in 'hotkey.keys'
    lua_getglobal(L, "hotkey");
    lua_getfield(L, -1, "_keys");
    lua_pushvalue(L, -3);
    hotkey->uid = luaL_ref(L, -2);
    lua_pop(L, 2);
    
    // start the event watcher!
    EventHotKeyID hotKeyID = { .signature = 'HDRA', .id = hotkey->uid };
    hotkey->carbonHotKey = NULL;
    RegisterEventHotKey(hotkey->keycode, hotkey->mods, hotKeyID, GetEventDispatcherTarget(), kEventHotKeyExclusive, &hotkey->carbonHotKey);
    
    lua_pushvalue(L, 1);
    return 1;
}

/// hotkey:disable() -> self
/// Disables the given hotkey; does not remove it from hotkey.keys.
static int hotkey_disable(lua_State* L) {
    hotkey_t* hotkey = luaL_checkudata(L, 1, "hotkey");
    lua_settop(L, 1);
    
    if (!hotkey->enabled)
        return 1;
    
    // remove from keys table
    lua_getglobal(L, "hotkey");
    lua_getfield(L, -1, "_keys");
    luaL_unref(L, -1, hotkey->uid);
    lua_pop(L, 2);
    
    UnregisterEventHotKey(hotkey->carbonHotKey);
    
    return 1;
}

static int hotkey_gc(lua_State* L) {
    hotkey_t* hotkey = luaL_checkudata(L, 1, "hotkey");
    luaL_unref(L, LUA_REGISTRYINDEX, hotkey->fnref);
    return 0;
}

static const luaL_Reg hotkeylib[] = {
    {"new", hotkey_new},
    {"enable", hotkey_enable},
    {"disable", hotkey_disable},
    {"__gc", hotkey_gc},
    {NULL, NULL}
};

static OSStatus hotkey_callback(EventHandlerCallRef inHandlerCallRef, EventRef inEvent, void *inUserData) {
    EventHotKeyID eventID;
    GetEventParameter(inEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(eventID), NULL, &eventID);
    
    lua_State* L = inUserData;
    
    lua_getglobal(L, "hotkey");
    lua_getfield(L, -1, "_keys");
    lua_rawgeti(L, -1, eventID.id);
    hotkey_t* hotkey = lua_touserdata(L, -1);
    lua_pop(L, 3);
    
    lua_rawgeti(L, LUA_REGISTRYINDEX, hotkey->fnref);
    if (lua_pcall(L, 0, 0, 0))
        hydra_handle_error(L);
    
    return noErr;
}

int luaopen_hotkey(lua_State* L) {
    luaL_newlib(L, hotkeylib);
    
    // hotkey._keys = {}
    lua_newtable(L);
    lua_setfield(L, -2, "_keys");
    
    // watch for events
    EventTypeSpec hotKeyPressedSpec[] = {
        {kEventClassKeyboard, kEventHotKeyPressed},
//        {kEventClassKeyboard, kEventHotKeyReleased},
    };
    InstallEventHandler(GetEventDispatcherTarget(), hotkey_callback, sizeof(hotKeyPressedSpec) / sizeof(EventTypeSpec), hotKeyPressedSpec, L, NULL);
    
    // put hotkey in registry; necessary for luaL_checkudata()
    lua_pushvalue(L, -1);
    lua_setfield(L, LUA_REGISTRYINDEX, "hotkey");
    
    // hotkey.__index = hotkey
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    
    // hotkey.keycodes = {...}
    hydra_pushkeycodestable(L);
    lua_setfield(L, -2, "keycodes");
    
    return 1;
}
