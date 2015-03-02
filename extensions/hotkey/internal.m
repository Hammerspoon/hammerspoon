#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>

static NSMutableIndexSet* handlers;

static int store_hotkey(lua_State* L, int idx) {
    lua_pushvalue(L, idx);
    int x = luaL_ref(L, LUA_REGISTRYINDEX);
    [handlers addIndex: x];
    return x;
}

static void remove_hotkey(lua_State* L, int x) {
    luaL_unref(L, LUA_REGISTRYINDEX, x);
    [handlers removeIndex: x];
}

static void* push_hotkey(lua_State* L, int x) {
    lua_rawgeti(L, LUA_REGISTRYINDEX, x);
    return lua_touserdata(L, -1);
}

typedef struct _hotkey_t {
    UInt32 mods;
    UInt32 keycode;
    UInt32 uid;
    int pressedfn;
    int releasedfn;
    BOOL enabled;
    EventHotKeyRef carbonHotKey;
} hotkey_t;


static int hotkey_new(lua_State* L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    UInt32 keycode = luaL_checknumber(L, 2);
    luaL_checktype(L, 3, LUA_TFUNCTION);
    luaL_checktype(L, 4, LUA_TFUNCTION);
    lua_settop(L, 4);

    hotkey_t* hotkey = lua_newuserdata(L, sizeof(hotkey_t));
    memset(hotkey, 0, sizeof(hotkey_t));

    hotkey->keycode = keycode;

    // use 'hs.hotkey' metatable
    luaL_getmetatable(L, "hs.hotkey");
    lua_setmetatable(L, -2);

    // store pressedfn
    lua_pushvalue(L, 3);
    hotkey->pressedfn = luaL_ref(L, LUA_REGISTRYINDEX);

    // store releasedfn
    lua_pushvalue(L, 4);
    hotkey->releasedfn = luaL_ref(L, LUA_REGISTRYINDEX);

    // save mods
    lua_pushnil(L);
    while (lua_next(L, 1) != 0) {
        NSString* mod = [[NSString stringWithUTF8String:luaL_checkstring(L, -1)] lowercaseString];
        if ([mod isEqualToString: @"cmd"] || [mod isEqualToString: @"⌘"]) hotkey->mods |= cmdKey;
        else if ([mod isEqualToString: @"ctrl"] || [mod isEqualToString: @"⌃"]) hotkey->mods |= controlKey;
        else if ([mod isEqualToString: @"alt"] || [mod isEqualToString: @"⌥"]) hotkey->mods |= optionKey;
        else if ([mod isEqualToString: @"shift"] || [mod isEqualToString: @"⇧"]) hotkey->mods |= shiftKey;
        lua_pop(L, 1);
    }

    return 1;
}

/// hs.hotkey:enable() -> hotkeyObject
/// Method
/// Enables a hotkey object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The hotkey object
static int hotkey_enable(lua_State* L) {
    hotkey_t* hotkey = luaL_checkudata(L, 1, "hs.hotkey");
    lua_settop(L, 1);

    if (hotkey->enabled)
        return 1;

    hotkey->enabled = YES;
    hotkey->uid = store_hotkey(L, 1);
    EventHotKeyID hotKeyID = { .signature = 'MJLN', .id = hotkey->uid };
    hotkey->carbonHotKey = NULL;
    RegisterEventHotKey(hotkey->keycode, hotkey->mods, hotKeyID, GetEventDispatcherTarget(), kEventHotKeyExclusive, &hotkey->carbonHotKey);

    lua_pushvalue(L, 1);
    return 1;
}

static void stop(lua_State* L, hotkey_t* hotkey) {
    if (!hotkey->enabled)
        return;

    hotkey->enabled = NO;
    remove_hotkey(L, hotkey->uid);
    UnregisterEventHotKey(hotkey->carbonHotKey);
}

/// hs.hotkey:disable() -> hotkeyObject
/// Method
/// Disables a hotkey object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The hotkey object
static int hotkey_disable(lua_State* L) {
    hotkey_t* hotkey = luaL_checkudata(L, 1, "hs.hotkey");
    stop(L, hotkey);
    lua_pushvalue(L, 1);
    return 1;
}

static int hotkey_gc(lua_State* L) {
    hotkey_t* hotkey = luaL_checkudata(L, 1, "hs.hotkey");
    stop(L, hotkey);
    luaL_unref(L, LUA_REGISTRYINDEX, hotkey->pressedfn);
    luaL_unref(L, LUA_REGISTRYINDEX, hotkey->releasedfn);
    return 0;
}

static const luaL_Reg hotkeylib[] = {
    {"_new", hotkey_new},

    {"enable", hotkey_enable},
    {"disable", hotkey_disable},
    {"__gc", hotkey_gc},

    {}
};

static EventHandlerRef eventhandler;

static OSStatus hotkey_callback(EventHandlerCallRef __attribute__ ((unused)) inHandlerCallRef, EventRef inEvent, void *inUserData) {
    EventHotKeyID eventID;
    OSStatus result = GetEventParameter(inEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(eventID), NULL, &eventID);
    if (result != noErr) {
        NSLog(@"Error handling hotkey: %d", result);
        return noErr;
    }

    lua_State* L = inUserData;
    if (lua_status(L) != LUA_OK) {
        NSLog(@"Error: lua thread is not in a good state");
        return noErr;
    }

    hotkey_t* hotkey = push_hotkey(L, eventID.id);
    lua_pop(L, 1);

    if (hotkey) {
        int ref = 0;
        if (GetEventKind(inEvent) == kEventHotKeyPressed) {
           ref = hotkey->pressedfn;
        } else if (GetEventKind(inEvent) == kEventHotKeyReleased) {
           ref = hotkey->releasedfn;
        } else {
            NSLog(@"Error: unknown event kind in hotkey_callback");
            return noErr;
        }

        lua_getglobal(L, "debug");
        lua_getfield(L, -1, "traceback");
        lua_remove(L, -2);
        lua_rawgeti(L, LUA_REGISTRYINDEX, ref);

        if (lua_pcall(L, 0, 0, -2) != LUA_OK) {
            NSLog(@"%s", lua_tostring(L, -1));
            lua_getglobal(L, "hs");
            lua_getfield(L, -1, "showError");
            lua_remove(L, -2);
            lua_pushvalue(L, -2);
            lua_pcall(L, 1, 0, 0);
        }
    }

    return noErr;
}

static int meta_gc(lua_State* L __unused) {
    RemoveEventHandler(eventhandler);
    return 0;
}

static const luaL_Reg metalib[] = {
    {"__gc", meta_gc},
    {}
};

int luaopen_hs_hotkey_internal(lua_State* L) {
    handlers = [NSMutableIndexSet indexSet];

    luaL_newlib(L, hotkeylib);

    // watch for hotkey events
    EventTypeSpec hotKeyPressedSpec[] = {
        {kEventClassKeyboard, kEventHotKeyPressed},
        {kEventClassKeyboard, kEventHotKeyReleased},
    };
    InstallEventHandler(GetEventDispatcherTarget(),
                        hotkey_callback,
                        sizeof(hotKeyPressedSpec) / sizeof(EventTypeSpec),
                        hotKeyPressedSpec,
                        L,
                        &eventhandler);

    // put hotkey in registry; necessary for luaL_checkudata()
    lua_pushvalue(L, -1);
    lua_setfield(L, LUA_REGISTRYINDEX, "hs.hotkey");

    // hotkey.__index = hotkey
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");

    // set metatable so gc function can cleanup module
    luaL_newlib(L, metalib);
    lua_setmetatable(L, -2);

    return 1;
}
