#import "MJConsoleWindowController.h"
#import "MJLua.h"

#define MJColorForStdout [NSColor colorWithCalibratedHue:0.88 saturation:1.0 brightness:0.6 alpha:1.0]
#define MJColorForCommand [NSColor blackColor]
#define MJColorForResult [NSColor colorWithCalibratedHue:0.54 saturation:1.0 brightness:0.7 alpha:1.0]

@interface MJConsoleWindowController ()

@property NSMutableArray* history;
@property NSInteger historyIndex;
@property IBOutlet NSTextView* outputView;
@property (weak) IBOutlet NSTextField* inputField;

@end

typedef NS_ENUM(NSUInteger, MJReplLineType) {
    MJReplLineTypeCommand,
    MJReplLineTypeResult,
    MJReplLineTypeStdout,
};

@implementation MJConsoleWindowController

- (NSString*) windowNibName {
    return @"ConsoleWindow";
}

+ (instancetype) singleton {
    static MJConsoleWindowController* s;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s = [[MJConsoleWindowController alloc] init];
    });
    return s;
}

- (void) setup {
    [self window]; // HAX!
    
    MJLuaSetupLogHandler(^(NSString* str){
        [self appendString:str type:MJReplLineTypeStdout];
        [self.outputView scrollToEndOfDocument:self];
    });
}

- (void) windowDidLoad {
    self.history = [NSMutableArray array];
    [self.outputView setEditable:NO];
    [self.outputView setSelectable:YES];
    
    [self appendString:@""
     "Welcome to the Mjolnir REPL!\n"
     "You can run any Lua code in here.\n"
                  type:MJReplLineTypeStdout];
}

- (void) appendString:(NSString*)str type:(MJReplLineType)type {
    NSColor* color = nil;
    switch (type) {
        case MJReplLineTypeStdout:  color = MJColorForStdout; break;
        case MJReplLineTypeCommand: color = MJColorForCommand; break;
        case MJReplLineTypeResult:  color = MJColorForResult; break;
    }
    
    NSDictionary* attrs = @{NSFontAttributeName: [NSFont fontWithName:@"Menlo" size:12.0], NSForegroundColorAttributeName: color};
    NSAttributedString* attrstr = [[NSAttributedString alloc] initWithString:str attributes:attrs];
    [[self.outputView textStorage] appendAttributedString:attrstr];
}

- (NSString*) run:(NSString*)command {
    return MJLuaRunString(command);
}

- (IBAction) tryMessage:(NSTextField*)sender {
    NSString* command = [sender stringValue];
    [self appendString:[NSString stringWithFormat:@"\n> %@\n", command] type:MJReplLineTypeCommand];
    
    NSString* result = [self run:command];
    [self appendString:[NSString stringWithFormat:@"%@\n", result] type:MJReplLineTypeResult];
    
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
