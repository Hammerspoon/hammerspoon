#import "PKReplController.h"
#import "lua/lua.h"
#import "lua/lauxlib.h"

extern lua_State* PKLuaState;

@implementation PKReplController

- (void) awakeFromNib {
    [self.outputView setEditable:NO];
    [self.outputView setSelectable:YES];
}

- (void) appendString:(NSString*)str type:(int)type {
    NSDictionary* attrs = @{NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:12.0],
                            NSForegroundColorAttributeName: type == 0 ? [NSColor redColor] : [NSColor blueColor]};
    NSAttributedString* attrstr = [[NSAttributedString alloc] initWithString:str attributes:attrs];
    [[self.outputView textStorage] appendAttributedString:attrstr];
}

- (NSString*) run:(NSString*)command {
    lua_State* L = PKLuaState;
    
    lua_getglobal(L, "core");
    lua_getfield(L, -1, "runstring");
    lua_pushstring(L, [command UTF8String]);
    lua_pcall(L, 1, 1, 0);
    
    size_t len;
    const char* s = lua_tolstring(L, -1, &len);
    NSString* str = [[NSString alloc] initWithData:[NSData dataWithBytes:s length:len] encoding:NSUTF8StringEncoding];
    lua_pop(L, 2);
    
    return str;
}

- (IBAction) tryMessage:(NSTextField*)sender {
    NSString* command = [sender stringValue];
    [self appendString:[NSString stringWithFormat:@"> %@\n", command] type:0];
    
    NSString* result = [self run:command];
    [self appendString:[NSString stringWithFormat:@"%@\n\n", result] type:1];
    
    [sender setStringValue:@""];
    
    [self.outputView scrollToEndOfDocument:self];
}

@end
