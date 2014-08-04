#import "lua/lua.h"
#import "lua/lauxlib.h"
extern lua_State* MJLuaState;

@interface MJReplTabController : NSObject

@property NSMutableArray* history;
@property NSInteger historyIndex;
@property IBOutlet NSTextView* outputView;
@property (weak) IBOutlet NSTextField* inputField;

@end

@implementation MJReplTabController

- (void) awakeFromNib {
    self.history = [NSMutableArray array];
    [self.outputView setEditable:NO];
    [self.outputView setSelectable:YES];
    
    [self appendString:@""
     "Welcome to the Mjolnir REPL!\n"
     "You can run any Lua code in here.\n"
                  type:1];
}

- (void) appendString:(NSString*)str type:(int)type {
    NSDictionary* attrs = @{NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:12.0],
                            NSForegroundColorAttributeName: type == 0 ? [NSColor redColor] : [NSColor blueColor]};
    NSAttributedString* attrstr = [[NSAttributedString alloc] initWithString:str attributes:attrs];
    [[self.outputView textStorage] appendAttributedString:attrstr];
}

- (NSString*) run:(NSString*)command {
    lua_State* L = MJLuaState;
    
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
    [self appendString:[NSString stringWithFormat:@"\n> %@\n", command] type:0];
    
    NSString* result = [self run:command];
    [self appendString:[NSString stringWithFormat:@"%@\n", result] type:1];
    
    [sender setStringValue:@""];
    [self saveToHistory:command];
    [self.outputView scrollToEndOfDocument:self];
}

- (void) saveToHistory:(NSString*)cmd {
    [self.history addObject:cmd];
    self.historyIndex = [self.history count];
    [self useCurrentHistoryIndex];
}

- (void) goPrevHistory {
    self.historyIndex = MAX(self.historyIndex - 1, 0);
    [self useCurrentHistoryIndex];
}

- (void) goNextHistory {
    self.historyIndex = MIN(self.historyIndex + 1, [self.history count]);
    [self useCurrentHistoryIndex];
}

- (void) useCurrentHistoryIndex {
    if (self.historyIndex == [self.history count])
        [self.inputField setStringValue: @""];
    else
        [self.inputField setStringValue: [self.history objectAtIndex:self.historyIndex]];
    
    NSText* editor = [[self.inputField window] fieldEditor:YES forObject:self.inputField];
    [editor moveToEndOfDocument:self];
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command {
    if (command == @selector(moveUp:)) {
        [self goPrevHistory];
        return YES;
    }
    else if (command == @selector(moveDown:)) {
        [self goNextHistory];
        return YES;
    }
    return NO;
}

@end
