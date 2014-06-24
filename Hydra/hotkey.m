#import <Carbon/Carbon.h>
#import "hydra.h"
UInt32 PHKeyCodeForString(NSString* str);


// args: [self]
// ret: [self]
int hotkey_enable(lua_State* L) {
    lua_getfield(L, 1, "__uid");
    UInt32 uid = lua_tonumber(L, -1);
    
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

// args: [self]
// ret: [self]
int hotkey_disable(lua_State* L) {
    lua_getfield(L, 1, "__carbonkey");
    EventHotKeyRef carbonHotKey = lua_touserdata(L, -1);
    UnregisterEventHotKey(carbonHotKey);
    
    lua_pushvalue(L, 1);
    return 1;
}

static const luaL_Reg hotkeylib[] = {
    {"_enable", hotkey_enable},
    {"_disable", hotkey_disable},
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
        lua_getglobal(L, "api");
        lua_getfield(L, -1, "hotkey");
        lua_getfield(L, -1, "keys");
        
        lua_pushnumber(L, uid);
        lua_gettable(L, -2);
        
        lua_getfield(L, -1, "fn");
        
        if (lua_pcall(L, 0, 0, 0))
            hydra_handle_error(L);
        
        lua_pop(L, 4);
        
        return noErr;
    };
    
    EventTypeSpec hotKeyPressedSpec = { .eventClass = kEventClassKeyboard, .eventKind = kEventHotKeyPressed };
    InstallEventHandler(GetEventDispatcherTarget(), hotkey_callback, 1, &hotKeyPressedSpec, NULL, NULL);
}

int luaopen_hotkey(lua_State* L) {
    luaL_newlib(L, hotkeylib);
    
    hydra_add_doc_group(L, "hotkey", "Manage global hotkeys.");
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        setup_hotkey_callback(L);
    });
    
    return 1;
}
