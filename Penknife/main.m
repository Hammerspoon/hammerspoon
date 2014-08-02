#import <Cocoa/Cocoa.h>
#import "PKMainWindowController.h"
#import "PKExtensionManager.h"
#import "lua/lauxlib.h"
#import "lua/lualib.h"
int luaopen_core(lua_State* L);

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
    
    luaopen_core(L);
    lua_setglobal(L, "core");
    
    luaL_dofile(L, [[[NSBundle mainBundle] pathForResource:@"setup" ofType:@"lua"] fileSystemRepresentation]);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [[PKExtensionManager sharedManager] setup];
    [[PKMainWindowController sharedMainWindowController] showWindow:nil];
    [self setupLua];
}

@end
