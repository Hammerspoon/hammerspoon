#import <Carbon/Carbon.h>
#import "lua/lua.h"

#import "lua/lauxlib.h"

UInt32 PHKeyCodeForString(NSString* str);

typedef OSStatus(^SDHotKeyClosure)(UInt32 uid);

static OSStatus SDHotkeyCallback(EventHandlerCallRef inHandlerCallRef, EventRef inEvent, void *inUserData) {
    EventHotKeyID eventID;
    GetEventParameter(inEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(eventID), NULL, &eventID);
    
    SDHotKeyClosure block = (__bridge SDHotKeyClosure)inUserData;
    return block(eventID.id);
}

// args: [fn(uid) -> consume?]
// returns: []
int hotkey_setup(lua_State *L) {
    int i = luaL_ref(L, LUA_REGISTRYINDEX); // enclose fn
    
    SDHotKeyClosure blk = ^OSStatus(UInt32 uid){
        lua_rawgeti(L, LUA_REGISTRYINDEX, i); // push closure-ized block
        lua_pushnumber(L, uid);
        
        if (lua_pcall(L, 1, 1, 0) == LUA_OK) {
            int handled = lua_toboolean(L, -1);
            return (handled ? noErr : eventNotHandledErr);
        }
        else {
            return noErr;
        }
    };
    
    EventTypeSpec hotKeyPressedSpec = { .eventClass = kEventClassKeyboard, .eventKind = kEventHotKeyPressed };
    InstallEventHandler(GetEventDispatcherTarget(), SDHotkeyCallback, 1, &hotKeyPressedSpec, (__bridge_retained void*)[blk copy], NULL);
    return 0;
}

// args: [cmd?, ctrl?, alt?, shift?, key_str]
// returns: [uid, carbon_hotkey]
int hotkey_register(lua_State *L) {
    BOOL cmd        = lua_toboolean(L, 1);
    BOOL ctrl       = lua_toboolean(L, 2);
    BOOL alt        = lua_toboolean(L, 3);
    BOOL shift      = lua_toboolean(L, 4);
    const char* key = lua_tostring(L, 5);
    
    static UInt32 highestUID;
    UInt32 uid = ++highestUID;
    
    UInt32 mods = 0;
    if (cmd)   mods |= cmdKey;
    if (ctrl)  mods |= controlKey;
    if (alt)   mods |= optionKey;
    if (shift) mods |= shiftKey;
    
    UInt32 code = PHKeyCodeForString([NSString stringWithUTF8String:key]);
    
    EventHotKeyID hotKeyID = { .signature = 'PHNX', .id = uid };
    EventHotKeyRef carbonHotKey = NULL;
    RegisterEventHotKey(code, mods, hotKeyID, GetEventDispatcherTarget(), kEventHotKeyExclusive, &carbonHotKey);
    
    lua_pushnumber(L, uid);
    lua_pushlightuserdata(L, carbonHotKey);
    return 2;
}

// args: [carbon_hotkey]
// returns: []
int hotkey_unregister(lua_State *L) {
    EventHotKeyRef carbonHotKey = lua_touserdata(L, 1);
    UnregisterEventHotKey(carbonHotKey);
    return 0;
}
