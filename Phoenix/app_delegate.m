#import <Cocoa/Cocoa.h>

#import "lua/lauxlib.h"
#import "lua/lualib.h"

int hotkey_setup(lua_State *L);
int hotkey_register(lua_State *L);
int hotkey_unregister(lua_State *L);

int app_running_apps(lua_State* L);
int app_get_windows(lua_State* L);
int app_title(lua_State* L);
int app_show(lua_State* L);
int app_hide(lua_State* L);
int app_kill(lua_State* L);
int app_kill9(lua_State* L);
int app_is_hidden(lua_State* L);

int mouse_get(lua_State* L);
int mouse_set(lua_State* L);

int open_at_login_get(lua_State* L);
int open_at_login_set(lua_State* L);

static const luaL_Reg phoenix_lib[] = {
    {"hotkey_setup", hotkey_setup},
    {"hotkey_register", hotkey_register},
    {"hotkey_unregister", hotkey_unregister},
    
    {"app_running_apps", app_running_apps},
    {"app_get_windows", app_get_windows},
    {"app_title", app_title},
    {"app_show", app_show},
    {"app_hide", app_hide},
    {"app_kill", app_kill},
    {"app_kill9", app_kill9},
    {"app_is_hidden", app_is_hidden},
    
    {"mouse_get", mouse_get},
    {"mouse_set", mouse_set},
    
    {"open_at_login_get", open_at_login_get},
    {"open_at_login_set", open_at_login_set},
    
    {NULL, NULL}
};


@interface PHAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation PHAppDelegate

- (void) complainIfNeeded {
    BOOL enabled = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge id)kAXTrustedCheckOptionPrompt: @(YES)});
    
    if (!enabled) {
        NSRunAlertPanel(@"Enable Accessibility First", @"Find the little popup right behind this one, click \"Open System Preferences\" and enable Phoenix. Then launch Phoenix again.", @"Quit", nil, nil);
        [NSApp terminate:self];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self complainIfNeeded];
    
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    
    luaL_newlib(L, phoenix_lib);
    lua_setglobal(L, "__api");
    
    const char* app_init_file = [[[NSBundle mainBundle] URLForResource:@"phoenix_init" withExtension:@"lua"] fileSystemRepresentation];
    luaL_dofile(L, app_init_file);
}

@end
