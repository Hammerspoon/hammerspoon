@import Cocoa ;
@import Carbon ;
@import LuaSkin ;

static char *USERDATA_TAG  = "hs.keycodes.callback" ;
static LSRefTable refTable;

static void pushkeycode(lua_State* L, int code, const char* key) {
    // t[key] = code
    lua_pushinteger(L, code);
    lua_setfield(L, -2, key);

    // t[code] = key
    lua_pushstring(L, key);
    lua_rawseti(L, -2, code);
}

int keycodes_cachemap(lua_State* L) {
    lua_newtable(L);

    UInt16 relocatableKeyCodes[] = {
        kVK_ANSI_A, kVK_ANSI_B, kVK_ANSI_C, kVK_ANSI_D, kVK_ANSI_E, kVK_ANSI_F,
        kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_I, kVK_ANSI_J, kVK_ANSI_K, kVK_ANSI_L,
        kVK_ANSI_M, kVK_ANSI_N, kVK_ANSI_O, kVK_ANSI_P, kVK_ANSI_Q, kVK_ANSI_R,
        kVK_ANSI_S, kVK_ANSI_T, kVK_ANSI_U, kVK_ANSI_V, kVK_ANSI_W, kVK_ANSI_X,
        kVK_ANSI_Y, kVK_ANSI_Z, kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3,
        kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,
        kVK_ANSI_Grave, kVK_ANSI_Equal, kVK_ANSI_Minus, kVK_ANSI_RightBracket,
        kVK_ANSI_LeftBracket, kVK_ANSI_Quote, kVK_ANSI_Semicolon, kVK_ANSI_Backslash,
        kVK_ANSI_Comma, kVK_ANSI_Slash, kVK_ANSI_Period, kVK_ISO_Section,
        kVK_JIS_Yen, kVK_JIS_Underscore, kVK_JIS_KeypadComma, kVK_JIS_Eisu, kVK_JIS_Kana,
    };

    // NOTE: It appears that TISCopyCurrentKeyboardInputSources() can return NULL
    TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
    CFDataRef layoutData = TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData);

    if (layoutData) {
        const UCKeyboardLayout *keyboardLayout = (const void *)CFDataGetBytePtr(layoutData);
        UInt32 keysDown = 0;
        UniChar chars[4];
        UniCharCount realLength;

        for (int i = 0 ; i < (int)(sizeof(relocatableKeyCodes)/sizeof(relocatableKeyCodes[0])) ; i++) {
            if (UCKeyTranslate(keyboardLayout,
                               relocatableKeyCodes[i],
                               kUCKeyActionDown,
                               0,
                               LMGetKbdType(),
                               kUCKeyTranslateNoDeadKeysMask,
                               &keysDown,
                               sizeof(chars) / sizeof(chars[0]),
                               &realLength,
                               chars) == noErr && realLength > 0) {
                const char* name = [[NSString stringWithCharacters:chars length:1] UTF8String];

                pushkeycode(L, relocatableKeyCodes[i], name);
            }
        }
    }
    else {
        pushkeycode(L, kVK_ANSI_A, "a");
        pushkeycode(L, kVK_ANSI_B, "b");
        pushkeycode(L, kVK_ANSI_C, "c");
        pushkeycode(L, kVK_ANSI_D, "d");
        pushkeycode(L, kVK_ANSI_E, "e");
        pushkeycode(L, kVK_ANSI_F, "f");
        pushkeycode(L, kVK_ANSI_G, "g");
        pushkeycode(L, kVK_ANSI_H, "h");
        pushkeycode(L, kVK_ANSI_I, "i");
        pushkeycode(L, kVK_ANSI_J, "j");
        pushkeycode(L, kVK_ANSI_K, "k");
        pushkeycode(L, kVK_ANSI_L, "l");
        pushkeycode(L, kVK_ANSI_M, "m");
        pushkeycode(L, kVK_ANSI_N, "n");
        pushkeycode(L, kVK_ANSI_O, "o");
        pushkeycode(L, kVK_ANSI_P, "p");
        pushkeycode(L, kVK_ANSI_Q, "q");
        pushkeycode(L, kVK_ANSI_R, "r");
        pushkeycode(L, kVK_ANSI_S, "s");
        pushkeycode(L, kVK_ANSI_T, "t");
        pushkeycode(L, kVK_ANSI_U, "u");
        pushkeycode(L, kVK_ANSI_V, "v");
        pushkeycode(L, kVK_ANSI_W, "w");
        pushkeycode(L, kVK_ANSI_X, "x");
        pushkeycode(L, kVK_ANSI_Y, "y");
        pushkeycode(L, kVK_ANSI_Z, "z");
        pushkeycode(L, kVK_ANSI_0, "0");
        pushkeycode(L, kVK_ANSI_1, "1");
        pushkeycode(L, kVK_ANSI_2, "2");
        pushkeycode(L, kVK_ANSI_3, "3");
        pushkeycode(L, kVK_ANSI_4, "4");
        pushkeycode(L, kVK_ANSI_5, "5");
        pushkeycode(L, kVK_ANSI_6, "6");
        pushkeycode(L, kVK_ANSI_7, "7");
        pushkeycode(L, kVK_ANSI_8, "8");
        pushkeycode(L, kVK_ANSI_9, "9");
        pushkeycode(L, kVK_ANSI_Grave, "`");
        pushkeycode(L, kVK_ANSI_Equal, "=");
        pushkeycode(L, kVK_ANSI_Minus, "-");
        pushkeycode(L, kVK_ANSI_RightBracket, "]");
        pushkeycode(L, kVK_ANSI_LeftBracket, "[");
        pushkeycode(L, kVK_ANSI_Quote, "'");
        pushkeycode(L, kVK_ANSI_Semicolon, ";");
        pushkeycode(L, kVK_ANSI_Backslash, "\\");
        pushkeycode(L, kVK_ANSI_Comma, ",");
        pushkeycode(L, kVK_ANSI_Slash, "/");
        pushkeycode(L, kVK_ANSI_Period, ".");
        pushkeycode(L, kVK_ISO_Section, "§");
    }

    if (currentKeyboard) {
        CFRelease(currentKeyboard);
    }

    pushkeycode(L, kVK_F1, "f1");
    pushkeycode(L, kVK_F2, "f2");
    pushkeycode(L, kVK_F3, "f3");
    pushkeycode(L, kVK_F4, "f4");
    pushkeycode(L, kVK_F5, "f5");
    pushkeycode(L, kVK_F6, "f6");
    pushkeycode(L, kVK_F7, "f7");
    pushkeycode(L, kVK_F8, "f8");
    pushkeycode(L, kVK_F9, "f9");
    pushkeycode(L, kVK_F10, "f10");
    pushkeycode(L, kVK_F11, "f11");
    pushkeycode(L, kVK_F12, "f12");
    pushkeycode(L, kVK_F13, "f13");
    pushkeycode(L, kVK_F14, "f14");
    pushkeycode(L, kVK_F15, "f15");
    pushkeycode(L, kVK_F16, "f16");
    pushkeycode(L, kVK_F17, "f17");
    pushkeycode(L, kVK_F18, "f18");
    pushkeycode(L, kVK_F19, "f19");
    pushkeycode(L, kVK_F20, "f20");

    pushkeycode(L, kVK_ANSI_KeypadDecimal, "pad.");
    pushkeycode(L, kVK_ANSI_KeypadMultiply, "pad*");
    pushkeycode(L, kVK_ANSI_KeypadPlus, "pad+");
    pushkeycode(L, kVK_ANSI_KeypadDivide, "pad/");
    pushkeycode(L, kVK_ANSI_KeypadMinus, "pad-");
    pushkeycode(L, kVK_ANSI_KeypadEquals, "pad=");
    pushkeycode(L, kVK_ANSI_Keypad0, "pad0");
    pushkeycode(L, kVK_ANSI_Keypad1, "pad1");
    pushkeycode(L, kVK_ANSI_Keypad2, "pad2");
    pushkeycode(L, kVK_ANSI_Keypad3, "pad3");
    pushkeycode(L, kVK_ANSI_Keypad4, "pad4");
    pushkeycode(L, kVK_ANSI_Keypad5, "pad5");
    pushkeycode(L, kVK_ANSI_Keypad6, "pad6");
    pushkeycode(L, kVK_ANSI_Keypad7, "pad7");
    pushkeycode(L, kVK_ANSI_Keypad8, "pad8");
    pushkeycode(L, kVK_ANSI_Keypad9, "pad9");
    pushkeycode(L, kVK_ANSI_KeypadClear, "padclear");
    pushkeycode(L, kVK_ANSI_KeypadEnter, "padenter");

    pushkeycode(L, kVK_Return, "return");
    pushkeycode(L, kVK_Tab, "tab");
    pushkeycode(L, kVK_Space, "space");
    pushkeycode(L, kVK_Delete, "delete");
    pushkeycode(L, kVK_Escape, "escape");
    pushkeycode(L, kVK_Help, "help");
    pushkeycode(L, kVK_Home, "home");
    pushkeycode(L, kVK_PageUp, "pageup");
    pushkeycode(L, kVK_ForwardDelete, "forwarddelete");
    pushkeycode(L, kVK_End, "end");
    pushkeycode(L, kVK_PageDown, "pagedown");
    pushkeycode(L, kVK_LeftArrow, "left");
    pushkeycode(L, kVK_RightArrow, "right");
    pushkeycode(L, kVK_DownArrow, "down");
    pushkeycode(L, kVK_UpArrow, "up");

    pushkeycode(L, kVK_Command, "cmd");
    // kVK_RightCommand first appeared in 10.12
    pushkeycode(L, /* kVK_RightCommand */ 0x36, "rightcmd");
    pushkeycode(L, kVK_Shift, "shift");
    pushkeycode(L, kVK_CapsLock, "capslock");
    pushkeycode(L, kVK_Option, "alt");
    pushkeycode(L, kVK_Control, "ctrl");
    pushkeycode(L, kVK_RightShift, "rightshift");
    pushkeycode(L, kVK_RightOption, "rightalt");
    pushkeycode(L, kVK_RightControl, "rightctrl");
    pushkeycode(L, kVK_Function, "fn");

    pushkeycode(L, kVK_JIS_Yen, "yen");
    pushkeycode(L, kVK_JIS_Underscore, "underscore");
    pushkeycode(L, kVK_JIS_KeypadComma, "pad,");
    pushkeycode(L, kVK_JIS_Eisu, "eisu");
    pushkeycode(L, kVK_JIS_Kana, "kana");

    return 1;
}

@interface MJKeycodesObserver : NSObject
@property int ref;
@property LSGCCanary lsCanary;
@end

@implementation MJKeycodesObserver

- (instancetype)init {
    self = [super init] ;
    if (self) {
        _ref = LUA_NOREF ;
    }
    return self ;
}

- (void) inputSourceChanged:(NSNotification*)__unused note {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.ref != LUA_NOREF) {
            LuaSkin *skin = [LuaSkin sharedWithState:NULL];
            if (![skin checkGCCanary:self.lsCanary]) {
                return;
            }
            _lua_stackguard_entry(skin.L);
            [skin pushLuaRef:refTable ref:self.ref];
            [skin protectedCallAndError:@"hs.keycodes.inputSourceChanged" nargs:0 nresults:0];
            _lua_stackguard_exit(skin.L);
        }
    });
}

- (void) start {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(inputSourceChanged:)
                                                 name:NSTextInputContextKeyboardSelectionDidChangeNotification
                                               object:nil];
    /* This should have made things better, but it seems to cause crashes for some, possibly because the paired removeObserver call is wrong?
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self
                                                        selector:@selector(_inputSourceChanged:)
                                                            name:(__bridge NSString *)kTISNotifySelectedKeyboardInputSourceChanged
                                                          object:nil
                                              suspensionBehavior:NSNotificationSuspensionBehaviorDeliverImmediately];
     */
}

- (void) stop {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSTextInputContextKeyboardSelectionDidChangeNotification
                                                  object:nil];
    /*
    [[NSDistributedNotificationCenter defaultCenter] removeObserver:self
                                                               name:(__bridge NSString *)kTISNotifyEnabledKeyboardInputSourcesChanged
                                                             object:nil];
     */
}

@end

static int keycodes_newcallback(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    luaL_checktype(L, 1, LUA_TFUNCTION);

    lua_pushvalue(L, 1);
    int ref = [skin luaRef:refTable];

    MJKeycodesObserver* observer = [[MJKeycodesObserver alloc] init];
    observer.ref = ref;
    observer.lsCanary = [skin createGCCanary];
    [observer start];

    void** ud = lua_newuserdata(L, sizeof(id));
    *ud = (__bridge_retained void*)observer;

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1;
}

static int userdata_tostring(lua_State* L) {
    lua_pushstring(L, [[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static int keycodes_callback_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    MJKeycodesObserver* observer = (__bridge_transfer MJKeycodesObserver*)*(void**)luaL_checkudata(L, 1, USERDATA_TAG);

    LSGCCanary tmplsCanary = observer.lsCanary;
    [skin destroyGCCanary:&tmplsCanary];
    observer.lsCanary = tmplsCanary;

    [observer stop];

    observer.ref = [skin luaUnref:refTable ref:observer.ref];
    observer = nil;
    return 0;
}

static int keycodes_callback_stop(lua_State* L) {
    MJKeycodesObserver* observer = (__bridge MJKeycodesObserver*)*(void**)luaL_checkudata(L, 1, USERDATA_TAG);
    [observer stop];
    return 0;
}

NSString *getLayoutName(TISInputSourceRef layout) {
    return (__bridge NSString *)TISGetInputSourceProperty(layout, kTISPropertyLocalizedName);
}

void pushSourceIcon(lua_State *L, TISInputSourceRef source) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    IconRef icon = TISGetInputSourceProperty(source, kTISPropertyIconRef);
    if (icon) {
        [skin pushNSObject:[[NSImage alloc] initWithIconRef:icon]];
    } else {
        lua_pushnil(L);
    }
}

CFArrayRef getAllLayouts(void) {
    NSDictionary *properties = @{
                                 (__bridge NSString *)kTISPropertyInputSourceType : (__bridge NSString *)kTISTypeKeyboardLayout,
                                 (__bridge NSString *)kTISPropertyInputSourceIsSelectCapable: @true
                                 };
    return TISCreateInputSourceList((__bridge CFDictionaryRef)properties, false);
}

CFArrayRef getAllInputMethods(void) {
    NSDictionary *properties = @{
                                 (__bridge NSString *)kTISPropertyInputSourceType : (__bridge NSString *)kTISTypeKeyboardInputMode,
                                 (__bridge NSString *)kTISPropertyInputSourceIsSelectCapable: @true
                                 };
    return TISCreateInputSourceList((__bridge CFDictionaryRef)properties, false);
}

/// hs.keycodes.currentSourceID([sourceID]) -> string | boolean
/// Function
/// Get or set the source id for the keyboard input source
///
/// Parameters:
///  * sourceID - an optional string specifying the input source to set for keyboard input
///
/// Returns:
///  * If no parameter is provided, returns a string containing the source id for the current keyboard layout or input method; if a parameter is provided, returns true or false specifying whether or not the input source was able to be changed.
static int keycodes_sourceID(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;

    if (lua_gettop(L) == 0) {
        TISInputSourceRef layout = TISCopyCurrentKeyboardInputSource();
        [skin pushNSObject:(__bridge id)TISGetInputSourceProperty(layout, kTISPropertyInputSourceID)] ;
        CFRelease(layout);
    } else {
        BOOL found = NO ;
        NSString     *sourceID = [skin toNSObjectAtIndex:1] ;
        NSDictionary *prop     = @{
                                   (__bridge NSString *)kTISPropertyInputSourceID : sourceID,
                                   (__bridge NSString *)kTISPropertyInputSourceIsSelectCapable: @true
                                   } ;
        CFArrayRef   sources   = TISCreateInputSourceList((__bridge CFDictionaryRef)prop, false);
        if (sources) {
            if (CFArrayGetCount(sources) > 0) {
                found = (TISSelectInputSource((TISInputSourceRef)CFArrayGetValueAtIndex(sources, 0)) == noErr) ;
            }
            CFRelease(sources) ;
        }
        lua_pushboolean(L, found) ;
    }
    return 1;
}

/// hs.keycodes.currentLayout() -> string
/// Function
/// Gets the name of the current keyboard layout
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the name of the current keyboard layout
static int keycodes_currentLayout(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    TISInputSourceRef layout = TISCopyCurrentKeyboardLayoutInputSource();
    [skin pushNSObject:getLayoutName(layout)];
    CFRelease(layout);
    return 1;
}

/// hs.keycodes.currentLayoutIcon() -> hs.image object
/// Function
/// Gets the icon of the current keyboard layout
///
/// Parameters:
///  * None
///
/// Returns:
///  * An hs.image object containing the icon, if available
static int keycodes_currentLayoutIcon(lua_State* L) {
    TISInputSourceRef layout = TISCopyCurrentKeyboardInputSource();

    pushSourceIcon(L, layout);
    CFRelease(layout);
    return 1;
}

/// hs.keycodes.layouts([sourceID]) -> table
/// Function
/// Gets all of the enabled keyboard layouts that the keyboard input source can be switched to
///
/// Parameters:
///  * sourceID - an optional boolean, default false, indicating whether the keyboard layout names should be returned (false) or their source IDs (true).
///
/// Returns:
///  * A table containing a list of keyboard layouts enabled in System Preferences
///
/// Notes:
///  * Only those layouts which can be explicitly switched to will be included in the table.  Keyboard layouts which are part of input methods are not included.  See `hs.keycodes.methods`.
static int keycodes_layouts(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    BOOL sourceIDsOnly = lua_gettop(L) == 1 ? (BOOL)lua_toboolean(L, 1) : NO ;
    CFArrayRef layoutRefs = getAllLayouts();

    lua_newtable(L) ;
    if (layoutRefs) {
        for (int i = 0; i < CFArrayGetCount(layoutRefs); i++) {
            TISInputSourceRef layout = (TISInputSourceRef)(CFArrayGetValueAtIndex(layoutRefs, i));
            if (sourceIDsOnly) {
                [skin pushNSObject:(__bridge id)TISGetInputSourceProperty(layout, kTISPropertyInputSourceID)] ;
            } else {
                [skin pushNSObject:getLayoutName(layout)];
            }
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
        CFRelease(layoutRefs);
    }
    return 1;
}

/// hs.keycodes.methods([sourceID]) -> table
/// Function
/// Gets all of the enabled input methods that the keyboard input source can be switched to
///
/// Parameters:
///  * sourceID - an optional boolean, default false, indicating whether the keyboard input method names should be returned (false) or their source IDs (true).
///
/// Returns:
///  * A table containing a list of input methods enabled in System Preferences
///
/// Notes:
///  * Keyboard layouts which are not part of an input method are not included in this table.  See `hs.keycodes.layouts`.
static int keycodes_methods(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    BOOL sourceIDsOnly = lua_gettop(L) == 1 ? (BOOL)lua_toboolean(L, 1) : NO ;
    CFArrayRef methodRefs = getAllInputMethods();

    lua_newtable(L) ;
    if (methodRefs) {
        for (int i = 0; i < CFArrayGetCount(methodRefs); i++) {
            TISInputSourceRef method = (TISInputSourceRef)(CFArrayGetValueAtIndex(methodRefs, i));
            if (sourceIDsOnly) {
                [skin pushNSObject:(__bridge id)TISGetInputSourceProperty(method, kTISPropertyInputSourceID)] ;
            } else {
                [skin pushNSObject:getLayoutName(method)];
            }
            lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
        }
        CFRelease(methodRefs);
    }
    return 1;
}

/// hs.keycodes.currentMethod() -> string
/// Function
/// Get current input method
///
/// Parameters:
///  * None
///
/// Returns:
///  * Name of current input method, or nil
static int keycodes_currentMethod(__unused lua_State * L) {
    LuaSkin * skin = [LuaSkin sharedWithState:L];
    CFArrayRef methodRefs = getAllInputMethods();
    NSString * currentMethod = nil;

    if (methodRefs) {
        for (int i = 0 ; i < CFArrayGetCount(methodRefs); i ++ ) {
            TISInputSourceRef method = (TISInputSourceRef)(CFArrayGetValueAtIndex(methodRefs, i));
            CFBooleanRef selected = TISGetInputSourceProperty(method, kTISPropertyInputSourceIsSelected);
            if (CFBooleanGetValue(selected) == YES) {
                currentMethod = getLayoutName(method);
                break;
            }
        }

        CFRelease(methodRefs);
    }
    [skin pushNSObject:currentMethod];
    return 1;
}

/// hs.keycodes.setLayout(layoutName) -> boolean
/// Function
/// Changes the system keyboard layout
///
/// Parameters:
///  * layoutName - A string containing the name of an enabled keyboard layout
///
/// Returns:
///  * A boolean, true if the layout was successfully changed, otherwise false
static int keycodes_setLayout(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];
    NSString *desiredLayout = [skin toNSObjectAtIndex:1];
    CFArrayRef layoutRefs = getAllLayouts();
    BOOL found = NO;

    if (layoutRefs) {
        for (int i = 0; i < CFArrayGetCount(layoutRefs); i++) {
            TISInputSourceRef layout = (TISInputSourceRef)(CFArrayGetValueAtIndex(layoutRefs, i));
            NSString *layoutName = getLayoutName(layout);

            if ([layoutName isEqualToString:desiredLayout] && TISSelectInputSource(layout) == noErr) {
                found = YES;
            }
        }

        CFRelease(layoutRefs);
    }
    lua_pushboolean(L, found);
    return 1;
}

/// hs.keycodes.setMethod(methodName) -> boolean
/// Function
/// Changes the system input method
///
/// Parameters:
///  * methodName - A string containing the name of an enabled input method
///
/// Returns:
///  * A boolean, true if the method was successfully changed, otherwise false
static int keycodes_setMethod(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];
    NSString *desiredLayout = [skin toNSObjectAtIndex:1];
    CFArrayRef layoutRefs = getAllInputMethods();
    BOOL found = NO;

    if (layoutRefs) {
        for (int i = 0; i < CFArrayGetCount(layoutRefs); i++) {
            TISInputSourceRef layout = (TISInputSourceRef)(CFArrayGetValueAtIndex(layoutRefs, i));
            NSString *layoutName = getLayoutName(layout);

            if ([layoutName isEqualToString:desiredLayout] && TISSelectInputSource(layout) == noErr) {
                found = YES;
            }
        }

        CFRelease(layoutRefs);
    }
    lua_pushboolean(L, found);
    return 1;
}

/// hs.keycodes.iconForLayoutOrMethod(sourceName) -> hs.image object
/// Function
/// Gets an hs.image object for a given keyboard layout or input method
///
/// Parameters:
///  * sourceName - A string containing the name of an input method or keyboard layout
///
/// Returns:
///  * An hs.image object, or nil if no image could be found
///
/// Notes:
///  * Not all layouts/methods have icons, so you should assume this will return nil at some point
static int keycodes_getIcon(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];
    NSString *sourceName = [skin toNSObjectAtIndex:1];
    CFArrayRef layoutRefs = getAllLayouts();
    CFArrayRef methodRefs = getAllInputMethods();
    BOOL found = NO;

    if (layoutRefs) {
        for (int i = 0; i < CFArrayGetCount(layoutRefs); i++) {
            TISInputSourceRef layout = (TISInputSourceRef)(CFArrayGetValueAtIndex(layoutRefs, i));
            NSString *layoutName = getLayoutName(layout);

            if ([layoutName isEqualToString:sourceName]) {
                pushSourceIcon(L, layout);
                found = YES;
                break;
            }
        }
    }
    if (!found) {
        if (methodRefs) {
            for (int i = 0; i < CFArrayGetCount(methodRefs); i++) {
                TISInputSourceRef layout = (TISInputSourceRef)(CFArrayGetValueAtIndex(methodRefs, i));
                NSString *layoutName = getLayoutName(layout);

                if ([layoutName isEqualToString:sourceName]) {
                    pushSourceIcon(L, layout);
                    found = YES;
                    break;
                }
            }
        }
    }

    if (!found) {
        lua_pushnil(L);
    }

    if (layoutRefs) CFRelease(layoutRefs);
    if (methodRefs) CFRelease(methodRefs);

    return 1;
}

static const luaL_Reg callbacklib[] = {
    // instance methods
    {"_stop", keycodes_callback_stop},

    // metamethods
    {"__tostring", userdata_tostring},
    {"__gc", keycodes_callback_gc},

    {NULL, NULL}
};

static const luaL_Reg keycodeslib[] = {
    // module methods
    {"_newcallback", keycodes_newcallback},
    {"_cachemap", keycodes_cachemap},
    {"currentLayout", keycodes_currentLayout},
    {"currentLayoutIcon", keycodes_currentLayoutIcon},
    {"currentMethod", keycodes_currentMethod},
    {"layouts", keycodes_layouts},
    {"methods", keycodes_methods},
    {"setLayout", keycodes_setLayout},
    {"setMethod", keycodes_setMethod},
    {"iconForLayoutOrMethod", keycodes_getIcon},
    {"currentSourceID", keycodes_sourceID},

    {NULL, NULL}
};

int luaopen_hs_libkeycodes(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:keycodeslib metaFunctions:nil objectFunctions:callbacklib];

    return 1;
}
