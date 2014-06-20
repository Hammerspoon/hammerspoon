#import <Carbon/Carbon.h>
#import "lua/lauxlib.h"
UInt32 PHKeyCodeForString(NSString* str);


// args: [hotkey]
// ret: [hotkey]
int hotkey_enable(lua_State* L) {
    // adds the hotkey to hydra.hotkey.keys and gives it a __uid field
    // this is so the callback can find the hotkey and call its fn
    
    lua_getglobal(L, "hydra");
    lua_getfield(L, -1, "hotkey");
    lua_getfield(L, -1, "keys");
    lua_pushvalue(L, -1); // push keys on twice
    
    int uid = (int)lua_rawlen(L, -1) + 1;
    lua_rawseti(L, -1, uid); // pops keys
    
    lua_pushnumber(L, uid);
    lua_setfield(L, 1, "__uid");
    
    lua_pushnumber(L, uid);
    lua_pushvalue(L, 1);
    lua_settable(L, -3);
    
    lua_pop(L, 3); // not strictly necesary, but meh
    
    
    // start doing the real work!
    
    lua_getfield(L, 1, "mods");
    
    UInt32 mods = 0;
    
    lua_pushnil(L);
    while (lua_next(L, -2) != 0) {
        const char* cmod = lua_tostring(L, -1);
        NSString* mod = [[NSString stringWithUTF8String: cmod ] lowercaseString];
        
        if ([mod isEqualToString: @"ctrl"]) mods |= controlKey;
        else if ([mod isEqualToString: @"cmd"]) mods |= cmdKey;
        else if ([mod isEqualToString: @"alt"]) mods |= optionKey;
        else if ([mod isEqualToString: @"shift"]) mods |= shiftKey;
        
        lua_pop(L, 1);
    }
    
    lua_getfield(L, 1, "key");
    const char* key = lua_tostring(L, -1);
    
    UInt32 keycode = PHKeyCodeForString([NSString stringWithUTF8String:key]);
    
    EventHotKeyID hotKeyID = { .signature = 'PHNX', .id = uid };
    EventHotKeyRef carbonHotKey = NULL;
    RegisterEventHotKey(keycode, mods, hotKeyID, GetEventDispatcherTarget(), kEventHotKeyExclusive, &carbonHotKey);
    
    lua_pushlightuserdata(L, carbonHotKey);
    lua_setfield(L, 1, "__carbonkey");
    
    lua_pushvalue(L, 1);
    return 1;
}

// args: [hotkey]
// ret: [hotkey]
int hotkey_disable(lua_State* L) {
    lua_getfield(L, 1, "__carbonkey");
    EventHotKeyRef carbonHotKey = lua_touserdata(L, -1);
    
    UnregisterEventHotKey(carbonHotKey);
    
    lua_pushvalue(L, 1);
    return 1;
}

// args: [(self), mods, key, fn]
// ret: [hotkey]
int hotkey_new(lua_State* L) {
    lua_newtable(L);
    
    lua_pushvalue(L, 2);
    lua_setfield(L, -2, "mods");
    
    lua_pushvalue(L, 3);
    lua_setfield(L, -2, "key");
    
    lua_pushvalue(L, 4);
    lua_setfield(L, -2, "fn");
    
    if (luaL_newmetatable(L, "hotkey")) {
        lua_getglobal(L, "hydra");
        lua_getfield(L, -1, "hotkey");
        lua_setfield(L, -3, "__index");
        lua_pop(L, 1);
    }
    lua_setmetatable(L, -2);
    
    return 1;
}

// args: [mods, key, fn]
// ret: [hotkey]
int hotkey_bind(lua_State* L) {
    lua_pushnil(L); // fake implicit "self" for __call
    hotkey_new(L);
    return hotkey_enable(L);
}

static const luaL_Reg hotkeylib[] = {
    {"bind", hotkey_bind},
    
    {"enable", hotkey_enable},
    {"disable", hotkey_disable},
    {NULL, NULL}
};

static const luaL_Reg hotkeylib_meta[] = {
    {"__call", hotkey_new},
    {NULL, NULL}
};

static OSStatus(^hotkey_closure)(UInt32 uid);

static OSStatus hotkey_callback(EventHandlerCallRef inHandlerCallRef, EventRef inEvent, void *inUserData) {
    EventHotKeyID eventID;
    GetEventParameter(inEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(eventID), NULL, &eventID);
    return hotkey_closure(eventID.id);
}

void setup_hotkey_callback(lua_State *L) {
    hotkey_closure = ^OSStatus(UInt32 uid) {
        lua_getglobal(L, "hydra");
        lua_getfield(L, -1, "hotkey");
        lua_getfield(L, -1, "keys");
        
        lua_pushnumber(L, uid);
        lua_gettable(L, -2);
        
        lua_getfield(L, -1, "fn");
        lua_pcall(L, 0, 0, 0);
        
        lua_pop(L, 4);
        
        return noErr;
    };
    
    EventTypeSpec hotKeyPressedSpec = { .eventClass = kEventClassKeyboard, .eventKind = kEventHotKeyPressed };
    InstallEventHandler(GetEventDispatcherTarget(), hotkey_callback, 1, &hotKeyPressedSpec, NULL, NULL);
}

int luaopen_hotkey(lua_State* L) {
    luaL_newlib(L, hotkeylib);
    
    lua_newtable(L);
    lua_setfield(L, -2, "keys");
    
    luaL_newlib(L, hotkeylib_meta);
    lua_setmetatable(L, -2);
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        setup_hotkey_callback(L);
    });
    
    return 1;
}
