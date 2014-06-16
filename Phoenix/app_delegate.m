#import <Cocoa/Cocoa.h>

#import "lua/lauxlib.h"
#import "lua/lualib.h"

int phoenix_show_about_panel(lua_State* L);
int phoenix_quit(lua_State* L);

int util_do_after_delay(lua_State* L);

int hotkey_setup(lua_State *L);
int hotkey_register(lua_State *L);
int hotkey_unregister(lua_State *L);

int application_running_applications(lua_State* L);
int application_get_windows(lua_State* L);
int application_title(lua_State* L);
int application_show(lua_State* L);
int application_hide(lua_State* L);
int application_kill(lua_State* L);
int application_kill9(lua_State* L);
int application_is_hidden(lua_State* L);

int mouse_get(lua_State* L);
int mouse_set(lua_State* L);

int autolaunch_get(lua_State* L);
int autolaunch_set(lua_State* L);

int alert_show(lua_State* L);

int menu_show(lua_State* L);
int menu_hide(lua_State* L);

int pathwatcher_stop(lua_State* L);
int pathwatcher_start(lua_State* L);

int window_get_focused_window(lua_State* L);
int window_title(lua_State* L);
int window_is_standard(lua_State* L);
int window_topleft(lua_State* L);
int window_size(lua_State* L);
int window_settopleft(lua_State* L);
int window_setsize(lua_State* L);
int window_minimize(lua_State* L);
int window_unminimize(lua_State* L);
int window_isminimized(lua_State* L);
int window_pid(lua_State* L);
int window_focus(lua_State* L);
int window_subrole(lua_State* L);
int window_role(lua_State* L);
int window_visible_windows_sorted_by_recency(lua_State* L);

int screen_get_screens(lua_State* L);
int screen_get_main_screen(lua_State* L);
int screen_frame(lua_State* L);
int screen_visible_frame(lua_State* L);
int screen_equals(lua_State* L);
int screen_set_tint(lua_State* L);

static const luaL_Reg phoenix_lib[] = {
    {"phoenix_show_about_panel", phoenix_show_about_panel},
    {"phoenix_quit", phoenix_quit},
    
    {"util_do_after_delay", util_do_after_delay},
    
    {"hotkey_setup", hotkey_setup},
    {"hotkey_register", hotkey_register},
    {"hotkey_unregister", hotkey_unregister},
    
    {"application_running_applications", application_running_applications},
    {"application_get_windows", application_get_windows},
    {"application_title", application_title},
    {"application_show", application_show},
    {"application_hide", application_hide},
    {"application_kill", application_kill},
    {"application_kill9", application_kill9},
    {"application_is_hidden", application_is_hidden},
    
    {"mouse_get", mouse_get},
    {"mouse_set", mouse_set},
    
    {"autolaunch_get", autolaunch_get},
    {"autolaunch_set", autolaunch_set},
    
    {"alert_show", alert_show},
    
    {"menu_show", menu_show},
    {"menu_hide", menu_hide},
    
    {"pathwatcher_stop", pathwatcher_stop},
    {"pathwatcher_start", pathwatcher_start},
    
    {"window_get_focused_window", window_get_focused_window},
    {"window_title", window_title},
    {"window_is_standard", window_is_standard},
    {"window_topleft", window_topleft},
    {"window_size", window_size},
    {"window_settopleft", window_settopleft},
    {"window_setsize", window_setsize},
    {"window_minimize", window_minimize},
    {"window_unminimize", window_unminimize},
    {"window_isminimized", window_isminimized},
    {"window_pid", window_pid},
    {"window_focus", window_focus},
    {"window_subrole", window_subrole},
    {"window_role", window_role},
    {"window_visible_windows_sorted_by_recency", window_visible_windows_sorted_by_recency},
    
    {"screen_get_screens", screen_get_screens},
    {"screen_get_main_screen", screen_get_main_screen},
    {"screen_frame", screen_frame},
    {"screen_visible_frame", screen_visible_frame},
    {"screen_equals", screen_equals},
    {"screen_set_tint", screen_set_tint},
    
    {NULL, NULL}
};


@interface PHAppDelegate : NSObject <NSApplicationDelegate>
@end

@implementation PHAppDelegate

- (void) complainIfNeeded {
    BOOL enabled = AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge id)kAXTrustedCheckOptionPrompt: @(YES)});
    
    if (!enabled) {
        NSRunAlertPanel(@"Enable Accessibility First",
                        @"Find the little popup right behind this one, click \"Open System Preferences\" and enable Phoenix. Then launch Phoenix again.",
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
    
    luaL_newlib(L, phoenix_lib);
    lua_setglobal(L, "__api");
    
    NSString* bundlePath = [[NSBundle mainBundle] resourcePath];
    NSString* initFile = [bundlePath stringByAppendingPathComponent:@"rawinit.lua"];
    
    luaL_loadfile(L, [initFile fileSystemRepresentation]);
    lua_pushstring(L, [bundlePath fileSystemRepresentation]);
    lua_pcall(L, 1, LUA_MULTRET, 0);
}

@end
