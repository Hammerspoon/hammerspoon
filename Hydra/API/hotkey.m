#import <Carbon/Carbon.h>
#import "helpers.h"

void hydra_pushkeycodestable(lua_State* L);

static int hotkey_closure_ref;

static OSStatus hotkey_callback(EventHandlerCallRef inHandlerCallRef, EventRef inEvent, void *inUserData) {
    EventHotKeyID eventID;
    GetEventParameter(inEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(eventID), NULL, &eventID);
    
    lua_State* L = inUserData;
    lua_rawgeti(L, LUA_REGISTRYINDEX, hotkey_closure_ref);
    
    lua_pushnumber(L, eventID.id);
    
    if (lua_pcall(L, 1, 0, 0))
        hydra_handle_error(L);
    
    return noErr;
}

// args: [fn(int)]
// ret: []
static int hotkey_setup(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);
    hotkey_closure_ref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    EventTypeSpec hotKeyPressedSpec = { .eventClass = kEventClassKeyboard, .eventKind = kEventHotKeyPressed };
    InstallEventHandler(GetEventDispatcherTarget(), hotkey_callback, 1, &hotKeyPressedSpec, L, NULL);
    
    return 0;
}

// args: [uid, key, ctrl, cmd, alt, shift]
// ret: [carbonkey]
static int hotkey_register(lua_State* L) {
    UInt32 uid = luaL_checknumber(L, 1);
    UInt32 keycode = luaL_checknumber(L, 2);
    BOOL ctrl  = lua_toboolean(L, 3);
    BOOL cmd   = lua_toboolean(L, 4);
    BOOL alt   = lua_toboolean(L, 5);
    BOOL shift = lua_toboolean(L, 6);
    
    UInt32 mods = 0;
    if (ctrl)  mods |= controlKey;
    if (cmd)   mods |= cmdKey;
    if (alt)   mods |= optionKey;
    if (shift) mods |= shiftKey;
    
    EventHotKeyID hotKeyID = { .signature = 'HDRA', .id = uid };
    EventHotKeyRef carbonHotKey = NULL;
    RegisterEventHotKey(keycode, mods, hotKeyID, GetEventDispatcherTarget(), kEventHotKeyExclusive, &carbonHotKey);
    
    lua_pushlightuserdata(L, carbonHotKey);
    return 1;
}

// args: [carbonkey]
// ret: []
static int hotkey_unregister(lua_State* L) {
    EventHotKeyRef carbonHotKey = lua_touserdata(L, 1);
    UnregisterEventHotKey(carbonHotKey);
    return 0;
}

static const luaL_Reg hotkeylib[] = {
    {"_setup", hotkey_setup},
    {"_register", hotkey_register},
    {"_unregister", hotkey_unregister},
    {NULL, NULL}
};

int luaopen_hotkey(lua_State* L) {
    luaL_newlib(L, hotkeylib);
    
    hydra_pushkeycodestable(L);
    lua_setfield(L, -2, "keycodes");
    
    return 1;
}
