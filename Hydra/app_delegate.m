#import <Cocoa/Cocoa.h>

#import "lua/lauxlib.h"
#import "lua/lualib.h"

int luaopen_api(lua_State* L);

int luaopen_hotkey(lua_State* L);
int luaopen_app(lua_State* L);
int luaopen_mouse(lua_State* L);
int luaopen_autolaunch(lua_State* L);
int luaopen_alert(lua_State* L);
int luaopen_menu(lua_State* L);
int luaopen_pathwatcher(lua_State* L);
int luaopen_window(lua_State* L);
int luaopen_screen(lua_State* L);
int luaopen_timer(lua_State* L);
int luaopen_geometry(lua_State* L);
int luaopen_textgrid(lua_State* L);

@interface PHAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation PHAppDelegate

- (void) complainIfNeeded {
    BOOL enabled = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge id)kAXTrustedCheckOptionPrompt: @(YES)});
    
    if (!enabled) {
        NSRunAlertPanel(@"Enable Accessibility First",
                        @"Find the little popup right behind this one, click \"Open System Preferences\" and enable api. Then launch Hydra again.",
                        @"Quit",
                        nil,
                        nil);
        [NSApp terminate:self];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self complainIfNeeded];
    
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    
    luaopen_api(L);
    lua_pushvalue(L, -1);
    lua_setglobal(L, "api");
    
    static const luaL_Reg hydralibs[] = {
        {"hotkey",       luaopen_hotkey},
        {"app",          luaopen_app},
        {"mouse",        luaopen_mouse},
        {"autolaunch",   luaopen_autolaunch},
        {"alert",        luaopen_alert},
        {"menu",         luaopen_menu},
        {"pathwatcher",  luaopen_pathwatcher},
        {"window",       luaopen_window},
        {"screen",       luaopen_screen},
        {"timer",        luaopen_timer},
        {"geometry",     luaopen_geometry},
        {"textgrid",     luaopen_textgrid},
        {NULL, NULL},
    };
    
    for (int i = 0; hydralibs[i].name; i++) {
        luaL_Reg lib = hydralibs[i];
        lib.func(L);
        lua_setfield(L, -2, lib.name);
    }
    
    const char* initfile = [[[NSBundle mainBundle] pathForResource:@"rawinit" ofType:@"lua"] fileSystemRepresentation];
    luaL_dofile(L, initfile);
}

@end
