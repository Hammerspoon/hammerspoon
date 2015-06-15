#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lua/lauxlib.h>
#import "../hammerspoon.h"

@interface HSKeyRepeatManager : NSObject {
    NSTimer *keyRepeatTimer;
    lua_State *L;
    int eventID;
    int eventType;
}

- (void)startTimer:(lua_State *)luaState eventID:(int)theEventID eventKind:(int)theEventKind;
- (void)stopTimer;
- (void)delayTimerFired:(NSTimer *)timer;
- (void)repeatTimerFired:(NSTimer *)timer;
@end

static NSMutableIndexSet* handlers;
static HSKeyRepeatManager* keyRepeatManager;
static OSStatus trigger_hotkey_callback(lua_State* L, int eventUID, int eventKind, BOOL isRepeat);

@implementation HSKeyRepeatManager
- (void)startTimer:(lua_State *)luaState eventID:(int)theEventID eventKind:(int)theEventKind {
    //CLS_NSLOG(@"startTimer");
    if (keyRepeatTimer) {
        printToConsole(luaState, "ERROR: startTimer() called while an existing timer is running. Stopping existing one and refusing to proceed");
        [self stopTimer];
        return;
    }
    keyRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:[NSEvent keyRepeatDelay]
                                                      target:self
                                                    selector:@selector(delayTimerFired:)
                                                    userInfo:nil
                                                     repeats:NO];

    L = luaState;
    eventID = theEventID;
    eventType = theEventKind;
}

- (void)stopTimer {
    //CLS_NSLOG(@"stopTimer");
    [keyRepeatTimer invalidate];
    keyRepeatTimer = nil;
    L = nil;
    eventID = 0;
    eventType = 0;
}

- (void)delayTimerFired:(NSTimer * __unused)timer {
    //CLS_NSLOG(@"delayTimerFired");
    trigger_hotkey_callback(L, eventID, eventType, true);

    [keyRepeatTimer invalidate];
    keyRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:[NSEvent keyRepeatInterval]
                                                      target:self
                                                    selector:@selector(repeatTimerFired:)
                                                    userInfo:nil
                                                     repeats:YES];
}

- (void)repeatTimerFired:(NSTimer * __unused)timer {
    //CLS_NSLOG(@"repeatTimerFired");
    trigger_hotkey_callback(L, eventID, eventType, true);
}

@end

static int store_hotkey(lua_State* L, int idx) {
    lua_pushvalue(L, idx);
    int x = luaL_ref(L, LUA_REGISTRYINDEX);
    [handlers addIndex: x];
    return x;
}

static int remove_hotkey(lua_State* L, int x) {
    luaL_unref(L, LUA_REGISTRYINDEX, x);
    [handlers removeIndex: x];
    return LUA_NOREF;
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
    int repeatfn;
    BOOL enabled;
    EventHotKeyRef carbonHotKey;
} hotkey_t;


static int hotkey_new(lua_State* L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    UInt32 keycode = luaL_checknumber(L, 2);
    luaL_checktype(L, 3, LUA_TFUNCTION);
    luaL_checktype(L, 4, LUA_TFUNCTION);
    luaL_checktype(L, 5, LUA_TFUNCTION);
    lua_settop(L, 5);

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

    // store repeatfn
    lua_pushvalue(L, 5);
    hotkey->repeatfn = luaL_ref(L, LUA_REGISTRYINDEX);

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
///  * The `hs.hotkey` object
static int hotkey_enable(lua_State* L) {
    hotkey_t* hotkey = luaL_checkudata(L, 1, "hs.hotkey");
    lua_settop(L, 1);

    if (hotkey->enabled)
        return 1;

    hotkey->enabled = YES;
    hotkey->uid = store_hotkey(L, 1);
    EventHotKeyID hotKeyID = { .signature = 'HMSP', .id = hotkey->uid };
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
    hotkey->uid = LUA_NOREF;
    UnregisterEventHotKey(hotkey->carbonHotKey);
    [keyRepeatManager stopTimer];
}

/// hs.hotkey:disable() -> hotkeyObject
/// Method
/// Disables a hotkey object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.hotkey` object
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
    luaL_unref(L, LUA_REGISTRYINDEX, hotkey->repeatfn);
    hotkey->pressedfn = LUA_NOREF;
    hotkey->releasedfn = LUA_NOREF;
    hotkey->repeatfn = LUA_NOREF;
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
    int eventKind;
    int eventUID;

    //CLS_NSLOG(@"hotkey_callback");
    OSStatus result = GetEventParameter(inEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(eventID), NULL, &eventID);
    if (result != noErr) {
        CLS_NSLOG(@"Error handling hotkey: %d", result);
        return noErr;
    }

    eventKind = GetEventKind(inEvent);
    eventUID = eventID.id;

    return trigger_hotkey_callback((lua_State *)inUserData, eventUID, eventKind, false);
}

static OSStatus trigger_hotkey_callback(lua_State* L, int eventUID, int eventKind, BOOL isRepeat) {
    //CLS_NSLOG(@"trigger_hotkey_callback: isDown: %s, isUp: %s, isRepeat: %s", (eventKind == kEventHotKeyPressed) ? "YES" : "NO", (eventKind == kEventHotKeyReleased) ? "YES" : "NO", isRepeat ? "YES" : "NO");
    if (!L || (lua_status(L) != LUA_OK)) {
        printToConsole(L, "Error: lua thread is not in a good state");
        return noErr;
    }

    hotkey_t* hotkey = push_hotkey(L, eventUID);
    lua_pop(L, 1);

    if (!isRepeat) {
        //CLS_NSLOG(@"trigger_hotkey_callback: not a repeat, killing the timer if it's running");
        [keyRepeatManager stopTimer];
    }

    if (hotkey) {
        int ref = 0;
        if (isRepeat) {
            ref = hotkey->repeatfn;
        } else if (eventKind == kEventHotKeyPressed) {
           ref = hotkey->pressedfn;
        } else if (eventKind == kEventHotKeyReleased) {
           ref = hotkey->releasedfn;
        } else {
            printToConsole(L, "Error: unknown event kind in hotkey_callback");
            return noErr;
        }

        lua_getglobal(L, "debug");
        lua_getfield(L, -1, "traceback");
        lua_remove(L, -2);
        lua_rawgeti(L, LUA_REGISTRYINDEX, ref);

        if (lua_pcall(L, 0, 0, -2) != LUA_OK) {
            CLS_NSLOG(@"ERROR: trigger_hotkey_callback Lua error: %s", lua_tostring(L, -1));

            // For the sake of safety, we'll invalidate any repeat timer that's running, so we don't ruin the user's day by spamming them with errors
            [keyRepeatManager stopTimer];

            lua_getglobal(L, "hs");
            lua_getfield(L, -1, "showError");
            lua_remove(L, -2);
            lua_pushvalue(L, -2);
            lua_pcall(L, 1, 0, 0);
        } else {
            if (!isRepeat && eventKind == kEventHotKeyPressed) {
                //CLS_NSLOG(@"trigger_hotkey_callback: not a repeat, but it is a keydown, starting the timer");
                [keyRepeatManager startTimer:L eventID:eventUID eventKind:eventKind];
            }
        }

    }

    return noErr;
}

static int meta_gc(lua_State* L __unused) {
    RemoveEventHandler(eventhandler);
    [keyRepeatManager stopTimer];
    keyRepeatManager = nil;

    return 0;
}

static const luaL_Reg metalib[] = {
    {"__gc", meta_gc},
    {}
};

int luaopen_hs_hotkey_internal(lua_State* L) {
    handlers = [NSMutableIndexSet indexSet];
    keyRepeatManager = [[HSKeyRepeatManager alloc] init];

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
