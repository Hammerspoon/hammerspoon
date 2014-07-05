#import <Carbon/Carbon.h>
#import "helpers.h"
UInt32 PHKeyCodeForString(NSString* str);


// args: [uid, key, ctrl, cmd, alt, shift]
// ret: [carbonkey]
static int hotkey_register(lua_State* L) {
    UInt32 uid = luaL_checknumber(L, 1);
    const char* key = luaL_checkstring(L, 2);
    BOOL ctrl  = lua_toboolean(L, 3);
    BOOL cmd   = lua_toboolean(L, 4);
    BOOL alt   = lua_toboolean(L, 5);
    BOOL shift = lua_toboolean(L, 6);
    
    UInt32 mods = 0;
    if (ctrl)  mods |= controlKey;
    if (cmd)   mods |= cmdKey;
    if (alt)   mods |= optionKey;
    if (shift) mods |= shiftKey;
    
    UInt32 keycode = PHKeyCodeForString([NSString stringWithUTF8String:key]);
    
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
    {"_register", hotkey_register},
    {"_unregister", hotkey_unregister},
    {NULL, NULL}
};

static OSStatus(^hotkey_closure)(UInt32 uid);

static OSStatus hotkey_callback(EventHandlerCallRef inHandlerCallRef, EventRef inEvent, void *inUserData) {
    EventHotKeyID eventID;
    GetEventParameter(inEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(eventID), NULL, &eventID);
    return hotkey_closure(eventID.id);
}

void setup_hotkey_callback(lua_State *L, int idx) {
    lua_pushvalue(L, idx);
    int hotkeyref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    hotkey_closure = ^OSStatus(UInt32 uid) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, hotkeyref);
        lua_getfield(L, -1, "keys");
        lua_rawgeti(L, -1, uid);
        lua_getfield(L, -1, "fn");
        
        if (lua_pcall(L, 0, 0, 0))
            hydra_handle_error(L);
        
        lua_pop(L, 3);
        
        return noErr;
    };
    
    EventTypeSpec hotKeyPressedSpec = { .eventClass = kEventClassKeyboard, .eventKind = kEventHotKeyPressed };
    InstallEventHandler(GetEventDispatcherTarget(), hotkey_callback, 1, &hotKeyPressedSpec, NULL, NULL);
}

int luaopen_hotkey(lua_State* L) {
    hydra_add_doc_group(L, "hotkey", "Manage global hotkeys.");
    
    luaL_newlib(L, hotkeylib);
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        setup_hotkey_callback(L, -1);
    });
    
    return 1;
}
