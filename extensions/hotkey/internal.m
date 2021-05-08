#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>

@interface HSKeyRepeatManager : NSObject {
    NSTimer *keyRepeatTimer;
    int eventID;
    int eventType;
}

- (void)startTimer:(int)theEventID eventKind:(int)theEventKind;
- (void)stopTimer;
- (void)delayTimerFired:(NSTimer *)timer;
- (void)repeatTimerFired:(NSTimer *)timer;
@end

#define USERDATA_TAG "hs.hotkey"
static LSRefTable refTable;
static EventHandlerRef eventhandler;

static UInt32 monotonicHotkeyCount = 0;
static NSMutableDictionary<NSNumber*, NSValue*> *hotkeys = nil;

static HSKeyRepeatManager* keyRepeatManager;
static OSStatus trigger_hotkey_callback(int eventUID, int eventKind, BOOL isRepeat);

typedef struct _hotkey_t {
    int monotonicID;
    UInt32 mods;
    UInt32 keycode;
    int pressedfn;
    int releasedfn;
    int repeatfn;
    BOOL enabled;
    EventHotKeyRef carbonHotKey;
    LSGCCanary lsCanary;
} hotkey_t;

@implementation HSKeyRepeatManager
- (void)startTimer:(int)theEventID eventKind:(int)theEventKind {
    //NSLog(@"startTimer");
    if (keyRepeatTimer) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        [skin logWarn:@"hs.hotkey - startTimer() called while an existing repeat timer is running. Stopping existing timer and refusing to proceed."];
        [self stopTimer];
        return;
    }
    keyRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:[NSEvent keyRepeatDelay]
                                                      target:self
                                                    selector:@selector(delayTimerFired:)
                                                    userInfo:nil
                                                     repeats:NO];

    eventID = theEventID;
    eventType = theEventKind;
}

- (void)stopTimer {
    //NSLog(@"stopTimer");
    [keyRepeatTimer invalidate];
    keyRepeatTimer = nil;
    eventID = 0;
    eventType = 0;
}

- (void)delayTimerFired:(NSTimer * __unused)timer {
    //NSLog(@"delayTimerFired");

    trigger_hotkey_callback(eventID, eventType, true);

    [keyRepeatTimer invalidate];
    keyRepeatTimer = [NSTimer scheduledTimerWithTimeInterval:[NSEvent keyRepeatInterval]
                                                      target:self
                                                    selector:@selector(repeatTimerFired:)
                                                    userInfo:nil
                                                     repeats:YES];
}

- (void)repeatTimerFired:(NSTimer * __unused)timer {
    //NSLog(@"repeatTimerFired");

    trigger_hotkey_callback(eventID, eventType, true);
}

@end

//static int store_hotkey(lua_State* L, int idx) {
//    LuaSkin *skin = [LuaSkin sharedWithState:L];
//    lua_pushvalue(L, idx);
//    int x = [skin luaRef:refTable];
//    return x;
//}
//
//static int remove_hotkey(lua_State* L, int x) {
//    LuaSkin *skin = [LuaSkin sharedWithState:L];
//    [skin luaUnref:refTable ref:x];
//    return LUA_NOREF;
//}
//
//static void* push_hotkey(lua_State* L, int x) {
//    LuaSkin *skin = [LuaSkin sharedWithState:L];
//    [skin pushLuaRef:refTable ref:x];
//    return lua_touserdata(L, -1);
//}

static int hotkey_new(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    luaL_checktype(L, 1, LUA_TTABLE);
    UInt32 keycode = (UInt32)luaL_checkinteger(L, 2);
    BOOL hasDown = NO;
    BOOL hasUp = NO;
    BOOL hasRepeat = NO;

    if (!lua_isnoneornil(L, 3)) {
        hasDown = YES;
    }

    if (!lua_isnoneornil(L, 4)) {
        hasUp = YES;
    }

    if (!lua_isnoneornil(L, 5)) {
        hasRepeat = YES;
    }

    if (!hasDown && !hasUp && !hasRepeat) {
        [skin logError:@"hs.hotkey: new hotkeys must have at least one callback function"];

        lua_pushnil(L);
        return 1;
    }
    lua_settop(L, 5);

    hotkey_t* hotkey = lua_newuserdata(L, sizeof(hotkey_t));
    memset(hotkey, 0, sizeof(hotkey_t));

    UInt32 uid = monotonicHotkeyCount;
    monotonicHotkeyCount++;
    hotkey->monotonicID = uid;

    hotkey->lsCanary =  [skin createGCCanary];
    [hotkeys setObject:[NSValue valueWithPointer:hotkey] forKey:[NSNumber numberWithUnsignedInt:hotkey->monotonicID]];

    hotkey->carbonHotKey = nil;
    hotkey->keycode = keycode;

    // use 'hs.hotkey' metatable
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    // store pressedfn
    if (hasDown) {
        lua_pushvalue(L, 3);
        hotkey->pressedfn = [skin luaRef:refTable];
    } else {
        hotkey->pressedfn = LUA_NOREF;
    }

    // store releasedfn
    if (hasUp) {
        lua_pushvalue(L, 4);
        hotkey->releasedfn = [skin luaRef:refTable];
    } else {
        hotkey->releasedfn = LUA_NOREF;
    }

    // store repeatfn
    if (hasRepeat) {
        lua_pushvalue(L, 5);
        hotkey->repeatfn = [skin luaRef:refTable];
    } else {
        hotkey->repeatfn = LUA_NOREF;
    }

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

static int hotkey_systemAssigned(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    luaL_checktype(L, 1, LUA_TTABLE);
    UInt32 keycode = (UInt32)luaL_checkinteger(L, 2);
    UInt32 mods    = 0 ;

    // save mods
    lua_pushnil(L);
    while (lua_next(L, 1) != 0) {
        NSString* mod = [[NSString stringWithUTF8String:luaL_checkstring(L, -1)] lowercaseString];
        if ([mod isEqualToString: @"cmd"] || [mod isEqualToString: @"⌘"])        mods |= cmdKey;
        else if ([mod isEqualToString: @"ctrl"] || [mod isEqualToString: @"⌃"])  mods |= controlKey;
        else if ([mod isEqualToString: @"alt"] || [mod isEqualToString: @"⌥"])   mods |= optionKey;
        else if ([mod isEqualToString: @"shift"] || [mod isEqualToString: @"⇧"]) mods |= shiftKey;
        lua_pop(L, 1);
    }

    BOOL assigned = NO ;
    CFArrayRef registeredHotKeys = NULL ;
    OSStatus status = CopySymbolicHotKeys(&registeredHotKeys) ;
    if (status == noErr && registeredHotKeys) {

        CFIndex count = CFArrayGetCount(registeredHotKeys);
        for(CFIndex i = 0; i < count; i++)
        {
            CFDictionaryRef hotKeyInfo      = CFArrayGetValueAtIndex(registeredHotKeys, i);
            CFNumberRef     hotKeyCode      = CFDictionaryGetValue(hotKeyInfo, kHISymbolicHotKeyCode);
            CFNumberRef     hotKeyModifiers = CFDictionaryGetValue(hotKeyInfo, kHISymbolicHotKeyModifiers);
            CFBooleanRef    hotKeyEnabled   = CFDictionaryGetValue(hotKeyInfo, kHISymbolicHotKeyEnabled);
            // I *think* 1<< 17 represents the Fn key on laptops; at any rate, it's automatically added for
            // some keys, notably Function keys, arrow keys, etc... since we can't actually set it, remove
            // it from the dictionary if present.
            UInt32 modifierFlags = [(__bridge NSNumber *)hotKeyModifiers unsignedIntValue] & ~(1 << 17) ;
            if (([(__bridge NSNumber *)hotKeyCode unsignedIntValue] == keycode) && (modifierFlags == mods)) {
                lua_newtable(L) ;
                [skin pushNSObject:(__bridge NSNumber *)hotKeyCode]    ; lua_setfield(L, -2, "keycode") ;
                lua_pushinteger(L, modifierFlags) ;                      lua_setfield(L, -2, "mods") ;
                [skin pushNSObject:(__bridge NSNumber *)hotKeyEnabled] ; lua_setfield(L, -2, "enabled") ;
                assigned = YES ;
                break ;
            }
        }
        CFRelease(registeredHotKeys) ;
        if (!assigned) lua_pushboolean(L, false) ;
    } else {
        [skin logWarn:[NSString stringWithFormat:@"%s.assigned - unable to retrieve SymbolicHotKeys (%d)", USERDATA_TAG, status]] ;
        lua_pushnil(L) ;
    }

    return 1;
}

static int hotkey_enable(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    hotkey_t* hotkey = lua_touserdata(L, 1);
    lua_settop(L, 1);

    if (hotkey->enabled)
        return 1;

    if (hotkey->carbonHotKey) {
        [skin logBreadcrumb:@"hs.hotkey:enable() we think the hotkey is disabled, but it has a Carbon event. Proceeding, but this is a leak."];
    }

    EventHotKeyID hotKeyID = { .signature = 'HMSP', .id = hotkey->monotonicID };
    OSStatus result = RegisterEventHotKey(hotkey->keycode, hotkey->mods, hotKeyID, GetEventDispatcherTarget(), kEventHotKeyExclusive, &hotkey->carbonHotKey);

    if (result == noErr) {
        hotkey->enabled = YES;
        lua_pushvalue(L, 1);
    } else {
        [skin logError:[NSString stringWithFormat:@"%s:enable() keycode: %d, mods: 0x%04x, RegisterEventHotKey failed: %d", USERDATA_TAG, hotkey->keycode, hotkey->mods, (int)result]];
        if (result == eventHotKeyExistsErr) {
            [skin logError:@"This hotkey is already registered. It may be a duplicate in your Hammerspoon config, or it may be registered by macOS. See System Preferences->Keyboard->Shortcuts"];
        }

        lua_pushnil(L) ;
    }

    return 1;
}

static void stop(lua_State* L, hotkey_t* hotkey) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    if (!hotkey->enabled)
        return;

    hotkey->enabled = NO;

    if (!hotkey->carbonHotKey) {
        [skin logBreadcrumb:@"hs.hotkey stop() we think the hotkey is enabled, but it has no Carbon event. Refusing to unregister."];
    } else {
        OSStatus result = UnregisterEventHotKey(hotkey->carbonHotKey);
        hotkey->carbonHotKey = nil;
        if (result != noErr) {
            [skin logError:[NSString stringWithFormat:@"%s:stop() keycode: %d, mods: 0x%04x, UnregisterEventHotKey failed: %d", USERDATA_TAG, hotkey->keycode, hotkey->mods, (int)result]];
        }
    }

    [keyRepeatManager stopTimer];
}

static int hotkey_disable(lua_State* L) {
    hotkey_t* hotkey = luaL_checkudata(L, 1, USERDATA_TAG);
    stop(L, hotkey);
    lua_pushvalue(L, 1);
    return 1;
}

static int hotkey_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    hotkey_t* hotkey = luaL_checkudata(L, 1, USERDATA_TAG);

    stop(L, hotkey);

    [hotkeys removeObjectForKey:[NSNumber numberWithUnsignedInt:hotkey->monotonicID]];
    [skin destroyGCCanary:&(hotkey->lsCanary)];

    hotkey->pressedfn = [skin luaUnref:refTable ref:hotkey->pressedfn];
    hotkey->releasedfn = [skin luaUnref:refTable ref:hotkey->releasedfn];
    hotkey->repeatfn = [skin luaUnref:refTable ref:hotkey->repeatfn];

    return 0;
}

static OSStatus hotkey_callback(EventHandlerCallRef __attribute__ ((unused)) inHandlerCallRef, EventRef inEvent, void *inUserData) {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    EventHotKeyID eventID;
    int eventKind;
    int eventUID;

    //NSLog(@"hotkey_callback");
    OSStatus result = GetEventParameter(inEvent, kEventParamDirectObject, typeEventHotKeyID, NULL, sizeof(eventID), NULL, &eventID);
    if (result != noErr) {
        [skin logBreadcrumb:[NSString stringWithFormat:@"Error handling hotkey: %d", result]];
        return noErr;
    }

    eventKind = GetEventKind(inEvent);
    eventUID = eventID.id;

    return trigger_hotkey_callback(eventUID, eventKind, false);
}

static OSStatus trigger_hotkey_callback(int eventUID, int eventKind, BOOL isRepeat) {
    //NSLog(@"trigger_hotkey_callback: isDown: %s, isUp: %s, isRepeat: %s", (eventKind == kEventHotKeyPressed) ? "YES" : "NO", (eventKind == kEventHotKeyReleased) ? "YES" : "NO", isRepeat ? "YES" : "NO");
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];

    lua_State *L = skin.L;

    NSValue *hkValue = [hotkeys objectForKey:[NSNumber numberWithUnsignedInt:eventUID]];
    if (!hkValue) {
        [skin logWarn:[NSString stringWithFormat:@"hs.hotkey system callback for an eventUID we don't know about: %d", eventUID]];
        return noErr;
    }
    hotkey_t *hotkey = (hotkey_t *)hkValue.pointerValue;

    if (![skin checkGCCanary:hotkey->lsCanary]) {
        return noErr;
    }

    _lua_stackguard_entry(L);

    if (!isRepeat) {
        //NSLog(@"trigger_hotkey_callback: not a repeat, killing the timer if it's running");
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
            [skin logWarn:[NSString stringWithFormat:@"Unknown event kind (%i) in hs.hotkey trigger_hotkey_callback", eventKind]];
            return noErr;
        }

        if (ref != LUA_NOREF) {
            [skin pushLuaRef:refTable ref:ref];

            if (![skin protectedCallAndError:@"hs.hotkey callback" nargs:0 nresults:0]) {
                // For the sake of safety, we'll invalidate any repeat timer that's running, so we don't ruin the user's day by spamming them with errors
                [keyRepeatManager stopTimer];
                return noErr;
            }
        }
        if (!isRepeat && eventKind == kEventHotKeyPressed && hotkey->repeatfn != LUA_NOREF) {
            //NSLog(@"trigger_hotkey_callback: not a repeat, but it is a keydown, starting the timer");
            [keyRepeatManager startTimer:eventUID eventKind:eventKind];
        }
    }
    _lua_stackguard_exit(L);
    return noErr;
}

static int meta_gc(lua_State* L __unused) {
    RemoveEventHandler(eventhandler);
    [keyRepeatManager stopTimer];
    keyRepeatManager = nil;

    [hotkeys removeAllObjects];

    return 0;
}

static int userdata_tostring(lua_State* L) {
    hotkey_t* hotkey = luaL_checkudata(L, 1, USERDATA_TAG);

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: keycode: %d, mods: 0x%04x (%p)", USERDATA_TAG, hotkey->keycode, hotkey->mods, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static const luaL_Reg hotkeylib[] = {
    {"_new", hotkey_new},
    {"systemAssigned", hotkey_systemAssigned},

    {NULL, NULL}
};

static const luaL_Reg metalib[] = {
    {"__gc", meta_gc},
    {NULL, NULL}
};

static const luaL_Reg hotkey_objectlib[] = {
    {"enable", hotkey_enable},
    {"disable", hotkey_disable},
    {"__tostring", userdata_tostring},
    {"__gc", hotkey_gc},
    {NULL, NULL}
};

int luaopen_hs_hotkey_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    if (!hotkeys) {
        hotkeys = [[NSMutableDictionary alloc] init];
    }
    keyRepeatManager = [[HSKeyRepeatManager alloc] init];

    refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:hotkeylib metaFunctions:metalib objectFunctions:hotkey_objectlib];

    // watch for hotkey events
    EventTypeSpec hotKeyPressedSpec[] = {
        {kEventClassKeyboard, kEventHotKeyPressed},
        {kEventClassKeyboard, kEventHotKeyReleased},
    };

    InstallEventHandler(GetEventDispatcherTarget(),
                        hotkey_callback,
                        sizeof(hotKeyPressedSpec) / sizeof(EventTypeSpec),
                        hotKeyPressedSpec,
                        nil,
                        &eventhandler);

    return 1;
}
