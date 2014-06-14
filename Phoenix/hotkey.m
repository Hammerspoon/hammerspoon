#import <Carbon/Carbon.h>
#import "PHKeyTranslator.h"
#import "lua/lauxlib.h"






typedef struct _luahotkey_callback_data {
    lua_State* L;
    int i;
} luahotkey_callback_data;

static OSStatus hotkey_callback(EventHandlerCallRef inHandlerCallRef, EventRef inEvent, void *inUserData) {
    EventHotKeyID eventID;
    GetEventParameter(inEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(eventID), NULL, &eventID);
    
    luahotkey_callback_data* cb = inUserData;
    lua_State* L = cb->L;
    
    // push callback function
    lua_rawgeti(L, LUA_REGISTRYINDEX, cb->i);
    
    // push arg
    lua_pushnumber(L, eventID.id);
    
    if (lua_pcall(L, 1, 1, 0) == LUA_OK) {
        int handled = lua_toboolean(L, -1);
        return (handled ? noErr : eventNotHandledErr);
    }
    else {
        return noErr;
    }
}

static int hk_handle_callback(lua_State *L) {
    lua_gettable(L, lua_upvalueindex(1));  // [n, key]
    lua_getfield(L, -1, "fn");             // [n, key, fn]
    lua_pcall(L, 0, 1, 0);                 // [n, key, handled?]
    return 1;
}

static int hk_enable(lua_State *L) {
    // stack = [self]
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lua_getfield(L, 1, "_keys");                 // push keys table
        lua_pushcclosure(L, hk_handle_callback, 1);  // push closure (pops keys table)
        int i = luaL_ref(L, LUA_REGISTRYINDEX);      // reference closure (pops closure)
        
        luahotkey_callback_data* cb = malloc(sizeof(luahotkey_callback_data));
        cb->L = L;
        cb->i = i;
        
        EventTypeSpec hotKeyPressedSpec = { .eventClass = kEventClassKeyboard, .eventKind = kEventHotKeyPressed };
        InstallEventHandler(GetEventDispatcherTarget(), hotkey_callback, 1, &hotKeyPressedSpec, cb, NULL);
    });
    
    
    /*
     self._id = #self._keys + 1
     self._keys[self._id] = self
     [...]
     self._carbonkey = carbonkey
     */
    
    lua_getfield(L, 1, "_keys");       // [self, _keys]
    lua_len(L, -1);                    // [self, _keys, len]
    int uid = lua_tonumber(L, -1) + 1;
    lua_pop(L, 1);                     // [self, _keys]
    lua_pushnumber(L, uid);            // [self, _keys, uid]
    lua_pushvalue(L, 1);               // [self, _keys, uid, self]
    lua_settable(L, -3);               // [self, _keys]
    lua_pushnumber(L, uid);            // [self, _keys, uid]
    lua_setfield(L, 1, "_id");         // [self, _keys]
    lua_pop(L, 1);                     // [self]
    
    // push key (string)
    lua_getfield(L, 1, "key");
    const char* strkey = lua_tostring(L, 2);
    
    // push mods (table)
    lua_getfield(L, 1, "mods");
    
    UInt32 mods = 0;
    
    lua_pushnil(L);
    while (lua_next(L, 3) != 0) {
        const char* mod = lua_tostring(L, -1);
        NSString* nsmod = [[NSString stringWithUTF8String:mod] lowercaseString];
        
        if ([nsmod isEqualToString: @"shift"]) mods |= shiftKey;
        if ([nsmod isEqualToString: @"ctrl"]) mods |= controlKey;
        if ([nsmod isEqualToString: @"alt"]) mods |= optionKey;
        if ([nsmod isEqualToString: @"cmd"]) mods |= cmdKey;
        
        lua_pop(L, 1);
    }
    
    UInt32 key = [PHKeyTranslator codeFor:[NSString stringWithUTF8String:strkey]];
    
    EventHotKeyID hotKeyID = { .signature = 'PHNX', .id = uid };
    EventHotKeyRef carbonHotKey = NULL;
    RegisterEventHotKey(key, mods, hotKeyID, GetEventDispatcherTarget(), kEventHotKeyExclusive, &carbonHotKey);
    
    lua_pushlightuserdata(L, carbonHotKey);
    lua_setfield(L, 1, "_carbonkey");
    
    return 1;
}

static int hk_disable(lua_State *L) {
    // stack = [self]
    
    lua_getfield(L, 1, "_carbonkey");
    EventHotKeyRef carbonHotKey = lua_touserdata(L, -1);
    UnregisterEventHotKey(carbonHotKey);
    lua_pop(L, 1);
    
    lua_getfield(L, 1, "_keys");    // [self, self._keys]
    lua_getfield(L, 1, "_id");      // [self, self._keys, self._id]
    lua_pushnil(L);                 // [self, self._keys, self._id, nil]
    lua_settable(L, -3);            // [self, self._keys]
    lua_pop(L, 1);
    
    return 0;
}

static const luaL_Reg hotkey_lib[] = {
    {"enable", hk_enable},
    {"disable", hk_disable},
    {NULL, NULL}
};

void phoenix_push_hotkey_lib(lua_State * L) {
    luaL_newlib(L, hotkey_lib);
}
