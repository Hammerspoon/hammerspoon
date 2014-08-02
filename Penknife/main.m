#import <Cocoa/Cocoa.h>
#import "PKMainWindowController.h"
#import "PKExtensionManager.h"
#import "lua/lauxlib.h"
#import "lua/lualib.h"

int main(int argc, const char * argv[]) {
    return NSApplicationMain(argc, argv);
}

@interface HydraAppDelegate : NSObject <NSApplicationDelegate>
@end

lua_State* PKLuaState;

@implementation HydraAppDelegate

- (IBAction) showSpecificWindow:(NSMenuItem*)item {
    [[PKMainWindowController sharedMainWindowController] showAtTab:[[item title] lowercaseString]];
}

- (void) setupLua {
    lua_State* L = PKLuaState = luaL_newstate();
    luaL_openlibs(L);
    
//    hydra_setup_handler_storage(L); // TODO: turn into core.addhandler(), etc...
    
    int luaopen_core(lua_State* L);
    luaopen_core(L);
    lua_pushvalue(L, -1);
    lua_setglobal(L, "core");
    
    NSString* initFile = [[NSBundle mainBundle] pathForResource:@"rawinit" ofType:@"lua"];
    luaL_dofile(L, [initFile fileSystemRepresentation]);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [[PKExtensionManager sharedManager] setup];
    [[PKMainWindowController sharedMainWindowController] showWindow:nil];
    [self setupLua];
}

@end
