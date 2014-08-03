#import <Cocoa/Cocoa.h>
#import "PKMainWindowController.h"
#import "PKExtensionManager.h"
#import "lua/lauxlib.h"
#import "lua/lualib.h"
int luaopen_core(lua_State* L);

NSString* PKConfigDir;
NSURL* PKDocsetDestinationURL;

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

- (void) setupConfigDir {
    [[NSFileManager defaultManager] createDirectoryAtPath:PKConfigDir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
}

- (void) copyDocsIfNeeded {
    if ([[NSFileManager defaultManager] fileExistsAtPath:[PKDocsetDestinationURL path]])
        return;
    
    NSURL* docsetSourceURL = [[NSBundle mainBundle] URLForResource:@"Penknife" withExtension:@"docset"];
    [[NSFileManager defaultManager] copyItemAtURL:docsetSourceURL toURL:PKDocsetDestinationURL error:NULL];
}

- (void) setupLua {
    [[NSFileManager defaultManager] changeCurrentDirectoryPath:PKConfigDir];
    
    lua_State* L = PKLuaState = luaL_newstate();
    luaL_openlibs(L);
    
    luaopen_core(L);
    lua_setglobal(L, "core");
    
    luaL_dofile(L, [[[NSBundle mainBundle] pathForResource:@"setup" ofType:@"lua"] fileSystemRepresentation]);
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    PKConfigDir = [@"~/.penknife/" stringByStandardizingPath];
    PKDocsetDestinationURL = [NSURL fileURLWithPath:[@"~/.penknife/Penknife.docset" stringByStandardizingPath]];
    
    [self setupConfigDir];
    [self copyDocsIfNeeded];
    [[PKExtensionManager sharedManager] setup];
    [[PKMainWindowController sharedMainWindowController] showWindow:nil];
    [self setupLua];
}

@end
