#import "lua/lauxlib.h"

@interface HDReplWindowController : NSWindowController
@property (copy) void(^messageHandler)(NSString* str);
@property IBOutlet NSTextView* resultsView;
@end

static HDReplWindowController* repl_window_controller;

@implementation HDReplWindowController

- (NSString*) windowNibName { return @"repl"; }

- (IBAction) evalString:(NSTextField*)sender {
    NSString* code = [sender stringValue];
    [sender setStringValue:@""];
    
    if ([code hasPrefix:@"="])
        code = [@"return " stringByAppendingString:[code substringFromIndex:1]];
    
    self.messageHandler(code);
}

- (void) appendResult:(NSString*)result {
    [[[self.resultsView textStorage] mutableString] appendFormat:@"%@\n", result];
}

@end

// args: []
// ret: []
int repl_show(lua_State* L) {
    if (!repl_window_controller) {
        repl_window_controller = [[HDReplWindowController alloc] init];
        repl_window_controller.messageHandler = ^(NSString* str) {
            luaL_loadstring(L, [str UTF8String]);
            lua_pcall(L, 0, 1, 0);
            
            const char* result = luaL_tolstring(L, -1, NULL);
            [repl_window_controller appendResult: [NSString stringWithUTF8String:result]];
        };
    }
    
    [repl_window_controller showWindow: nil];
    
    [[repl_window_controller window] center];
    [repl_window_controller showWindow: nil];
    [NSApp activateIgnoringOtherApps:YES];
    
    return 0;
}

static const luaL_Reg repllib[] = {
    {"show", repl_show},
    {NULL, NULL}
};

int luaopen_repl(lua_State* L) {
    luaL_newlib(L, repllib);
    return 1;
}
