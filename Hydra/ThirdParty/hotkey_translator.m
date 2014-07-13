#import <Carbon/Carbon.h>
#import "helpers.h"

void hydra_pushkeycodestable(lua_State* L) {
    lua_newtable(L);
    
    int relocatableKeyCodes[] = {
        kVK_ANSI_A, kVK_ANSI_B, kVK_ANSI_C, kVK_ANSI_D, kVK_ANSI_E, kVK_ANSI_F,
        kVK_ANSI_G, kVK_ANSI_H, kVK_ANSI_I, kVK_ANSI_J, kVK_ANSI_K, kVK_ANSI_L,
        kVK_ANSI_M, kVK_ANSI_N, kVK_ANSI_O, kVK_ANSI_P, kVK_ANSI_Q, kVK_ANSI_R,
        kVK_ANSI_S, kVK_ANSI_T, kVK_ANSI_U, kVK_ANSI_V, kVK_ANSI_W, kVK_ANSI_X,
        kVK_ANSI_Y, kVK_ANSI_Z, kVK_ANSI_0, kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3,
        kVK_ANSI_4, kVK_ANSI_5, kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,
        kVK_ANSI_Grave, kVK_ANSI_Equal, kVK_ANSI_Minus, kVK_ANSI_RightBracket,
        kVK_ANSI_LeftBracket, kVK_ANSI_Quote, kVK_ANSI_Semicolon, kVK_ANSI_Backslash,
        kVK_ANSI_Comma, kVK_ANSI_Slash, kVK_ANSI_Period,
    };
    
    TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
    CFDataRef layoutData = TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData);
    
    if (layoutData) {
        const UCKeyboardLayout *keyboardLayout = (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
        UInt32 keysDown = 0;
        UniChar chars[4];
        UniCharCount realLength;
        
        for (int i = 0 ; i < sizeof(relocatableKeyCodes)/sizeof(relocatableKeyCodes[0]) ; i++) {
            UCKeyTranslate(keyboardLayout,
                           relocatableKeyCodes[i],
                           kUCKeyActionDisplay,
                           0,
                           LMGetKbdType(),
                           kUCKeyTranslateNoDeadKeysBit,
                           &keysDown,
                           sizeof(chars) / sizeof(chars[0]),
                           &realLength,
                           chars);
            
            const char* name = [[NSString stringWithCharacters:chars length:1] UTF8String];
            
            lua_pushnumber(L, relocatableKeyCodes[i]);
            lua_setfield(L, -2, name);
        }
    }
    
    CFRelease(currentKeyboard);
    
    // you should prefer typing these in upper-case in your config file,
    // since they look more unique (and less confusing) that way
    lua_pushnumber(L, kVK_F1); lua_setfield(L, -2, "f1");
    lua_pushnumber(L, kVK_F2); lua_setfield(L, -2, "f2");
    lua_pushnumber(L, kVK_F3); lua_setfield(L, -2, "f3");
    lua_pushnumber(L, kVK_F4); lua_setfield(L, -2, "f4");
    lua_pushnumber(L, kVK_F5); lua_setfield(L, -2, "f5");
    lua_pushnumber(L, kVK_F6); lua_setfield(L, -2, "f6");
    lua_pushnumber(L, kVK_F7); lua_setfield(L, -2, "f7");
    lua_pushnumber(L, kVK_F8); lua_setfield(L, -2, "f8");
    lua_pushnumber(L, kVK_F9); lua_setfield(L, -2, "f9");
    lua_pushnumber(L, kVK_F10); lua_setfield(L, -2, "f10");
    lua_pushnumber(L, kVK_F11); lua_setfield(L, -2, "f11");
    lua_pushnumber(L, kVK_F12); lua_setfield(L, -2, "f12");
    lua_pushnumber(L, kVK_F13); lua_setfield(L, -2, "f13");
    lua_pushnumber(L, kVK_F14); lua_setfield(L, -2, "f14");
    lua_pushnumber(L, kVK_F15); lua_setfield(L, -2, "f15");
    lua_pushnumber(L, kVK_F16); lua_setfield(L, -2, "f16");
    lua_pushnumber(L, kVK_F17); lua_setfield(L, -2, "f17");
    lua_pushnumber(L, kVK_F18); lua_setfield(L, -2, "f18");
    lua_pushnumber(L, kVK_F19); lua_setfield(L, -2, "f19");
    lua_pushnumber(L, kVK_F20); lua_setfield(L, -2, "f20");
    
    // you should prefer typing these in lower-case in your config file,
    // since there's no concern for ambiguity/confusion with words, just with chars.
    lua_pushnumber(L, kVK_ANSI_KeypadDecimal); lua_setfield(L, -2, "pad.");
    lua_pushnumber(L, kVK_ANSI_KeypadMultiply); lua_setfield(L, -2, "pad*");
    lua_pushnumber(L, kVK_ANSI_KeypadPlus); lua_setfield(L, -2, "pad+");
    lua_pushnumber(L, kVK_ANSI_KeypadDivide); lua_setfield(L, -2, "pad/");
    lua_pushnumber(L, kVK_ANSI_KeypadMinus); lua_setfield(L, -2, "pad-");
    lua_pushnumber(L, kVK_ANSI_KeypadEquals); lua_setfield(L, -2, "pad=");
    lua_pushnumber(L, kVK_ANSI_Keypad0); lua_setfield(L, -2, "pad0");
    lua_pushnumber(L, kVK_ANSI_Keypad1); lua_setfield(L, -2, "pad1");
    lua_pushnumber(L, kVK_ANSI_Keypad2); lua_setfield(L, -2, "pad2");
    lua_pushnumber(L, kVK_ANSI_Keypad3); lua_setfield(L, -2, "pad3");
    lua_pushnumber(L, kVK_ANSI_Keypad4); lua_setfield(L, -2, "pad4");
    lua_pushnumber(L, kVK_ANSI_Keypad5); lua_setfield(L, -2, "pad5");
    lua_pushnumber(L, kVK_ANSI_Keypad6); lua_setfield(L, -2, "pad6");
    lua_pushnumber(L, kVK_ANSI_Keypad7); lua_setfield(L, -2, "pad7");
    lua_pushnumber(L, kVK_ANSI_Keypad8); lua_setfield(L, -2, "pad8");
    lua_pushnumber(L, kVK_ANSI_Keypad9); lua_setfield(L, -2, "pad9");
    lua_pushnumber(L, kVK_ANSI_KeypadClear); lua_setfield(L, -2, "padclear");
    lua_pushnumber(L, kVK_ANSI_KeypadEnter); lua_setfield(L, -2, "padenter");
    
    lua_pushnumber(L, kVK_Return); lua_setfield(L, -2, "return");
    lua_pushnumber(L, kVK_Tab); lua_setfield(L, -2, "tab");
    lua_pushnumber(L, kVK_Space); lua_setfield(L, -2, "space");
    lua_pushnumber(L, kVK_Delete); lua_setfield(L, -2, "delete");
    lua_pushnumber(L, kVK_Escape); lua_setfield(L, -2, "escape");
    lua_pushnumber(L, kVK_Help); lua_setfield(L, -2, "help");
    lua_pushnumber(L, kVK_Home); lua_setfield(L, -2, "home");
    lua_pushnumber(L, kVK_PageUp); lua_setfield(L, -2, "pageup");
    lua_pushnumber(L, kVK_ForwardDelete); lua_setfield(L, -2, "forwarddelete");
    lua_pushnumber(L, kVK_End); lua_setfield(L, -2, "end");
    lua_pushnumber(L, kVK_PageDown); lua_setfield(L, -2, "pagedown");
    lua_pushnumber(L, kVK_LeftArrow); lua_setfield(L, -2, "left");
    lua_pushnumber(L, kVK_RightArrow); lua_setfield(L, -2, "right");
    lua_pushnumber(L, kVK_DownArrow); lua_setfield(L, -2, "down");
    lua_pushnumber(L, kVK_UpArrow); lua_setfield(L, -2, "up");
}
