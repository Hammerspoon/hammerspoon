#import <Carbon/Carbon.h>
#import "helpers.h"

/// === hotkey ===
///
/// Create and manage global hotkeys.


typedef struct _hotkey_t {
    UInt32 mods;
    UInt32 keycode;
    UInt32 uid;
    int pressedfn;
    int releasedfn;
    BOOL enabled;
    EventHotKeyRef carbonHotKey;
} hotkey_t;


/// hotkey.keycodes
/// A mapping from string representation of a key to its keycode, and vice versa; not generally useful yet.
/// For example: keycodes[1] == "s", and keycodes["s"] == 1, and so on
void hydra_pushkeycodestable(lua_State* L); // defined in hotkey_translator.m


/// hotkey.new(mods, key, pressedfn, releasedfn = nil) -> hotkey
/// Creates a new hotkey that can be enabled.
///
/// The `mods` parameter is case-insensitive and may contain any of the following strings: "cmd", "ctrl", "alt", or "shift".
///
/// The `key` parameter is case-insensitive and may be any single-character string; it may also be any of the following strings:
///
///     F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12, F13, F14, F15,
///     F16, F17, F18, F19, F20, PAD, PAD*, PAD+, PAD/, PAD-, PAD=,
///     PAD0, PAD1, PAD2, PAD3, PAD4, PAD5, PAD6, PAD7, PAD8, PAD9,
///     PADCLEAR, PADENTER, RETURN, TAB, SPACE, DELETE, ESCAPE, HELP,
///     HOME, PAGEUP, FORWARDDELETE, END, PAGEDOWN, LEFT, RIGHT, DOWN, UP
///
/// The `pressedfn` parameter is the function that will be called when this hotkey is pressed.
///
/// The `releasedfn` parameter is the function that will be called when this hotkey is released; this field is optional (may be nil or omitted).
static int hotkey_new(lua_State* L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    const char* key = [[[NSString stringWithUTF8String:luaL_checkstring(L, 2)] lowercaseString] UTF8String];
    luaL_checktype(L, 3, LUA_TFUNCTION);
    lua_settop(L, 4);
    
    hotkey_t* hotkey = lua_newuserdata(L, sizeof(hotkey_t));
    memset(hotkey, 0, sizeof(hotkey_t));
    
    // push releasedfn
    lua_pushvalue(L, 4);
    hotkey->releasedfn = luaL_ref(L, LUA_REGISTRYINDEX);
    
    // set global 'hotkey' as its metatable
    luaL_getmetatable(L, "hotkey");
    lua_setmetatable(L, -2);
    
    // store function
    lua_pushvalue(L, 3);
    hotkey->pressedfn = luaL_ref(L, LUA_REGISTRYINDEX);
    
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
    hotkey->uid = hydra_store_handler(L, 1);
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
    
    hotkey->enabled = NO;
    hydra_remove_handler(L, hotkey->uid);
    UnregisterEventHotKey(hotkey->carbonHotKey);
    
    return 1;
}

/// hotkey.disableall()
/// Disables all hotkeys; automatically called when user config reloads.
static int hotkey_disableall(lua_State* L) {
    lua_getglobal(L, "hotkey");
    lua_getfield(L, -1, "disable");
    hydra_remove_all_handlers(L, "hotkey");
    return 0;
}

static int hotkey_gc(lua_State* L) {
    hotkey_t* hotkey = luaL_checkudata(L, 1, "hotkey");
    luaL_unref(L, LUA_REGISTRYINDEX, hotkey->pressedfn);
    luaL_unref(L, LUA_REGISTRYINDEX, hotkey->releasedfn);
    return 0;
}

static int hotkey__cachekeycodes(lua_State* L) {
    hydra_pushkeycodestable(L);
    return 1;
}

static const luaL_Reg hotkeylib[] = {
    {"new", hotkey_new},
    {"_cachekeycodes", hotkey__cachekeycodes},
    {"disableall", hotkey_disableall},
    
    {"enable", hotkey_enable},
    {"disable", hotkey_disable},
    {"__gc", hotkey_gc},
    
    {NULL, NULL}
};

static OSStatus hotkey_callback(EventHandlerCallRef inHandlerCallRef, EventRef inEvent, void *inUserData) {
    EventHotKeyID eventID;
    GetEventParameter(inEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(eventID), NULL, &eventID);
    
    lua_State* L = inUserData;
    
    hotkey_t* hotkey = hydra_get_stored_handler(L, eventID.id, "hotkey");
    
    int ref = (GetEventKind(inEvent) == kEventHotKeyPressed ? hotkey->pressedfn : hotkey->releasedfn);
    if (ref != LUA_REFNIL) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
        if (lua_pcall(L, 0, 0, 0))
            hydra_handle_error(L);
    }
    
    return noErr;
}

static void register_for_input_source_changes(lua_State* L) {
    static id observer; observer =
    [[NSNotificationCenter defaultCenter] addObserverForName:NSTextInputContextKeyboardSelectionDidChangeNotification
                                                      object:nil
                                                       queue:nil
                                                  usingBlock:^(NSNotification *note) {
                                                      lua_getglobal(L, "hotkey");
                                                      lua_getfield(L, -1, "_inputsourcechanged");
                                                      if (lua_pcall(L, 0, 0, 0))
                                                          hydra_handle_error(L);
                                                      lua_pop(L, 1);
                                                  }];
}

int luaopen_hotkey(lua_State* L) {
    luaL_newlib(L, hotkeylib);
    
    // watch for hotkey events
    EventTypeSpec hotKeyPressedSpec[] = {{kEventClassKeyboard, kEventHotKeyPressed}, {kEventClassKeyboard, kEventHotKeyReleased}};
    InstallEventHandler(GetEventDispatcherTarget(), hotkey_callback, sizeof(hotKeyPressedSpec) / sizeof(EventTypeSpec), hotKeyPressedSpec, L, NULL);
    
    // register for input source changes lol
    register_for_input_source_changes(L);
    
    // put hotkey in registry; necessary for luaL_checkudata()
    lua_pushvalue(L, -1);
    lua_setfield(L, LUA_REGISTRYINDEX, "hotkey");
    
    // hotkey.__index = hotkey
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    
    return 1;
}
