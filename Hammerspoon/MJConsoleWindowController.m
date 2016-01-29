#import "MJConsoleWindowController.h"
#import "MJLua.h"
#import "variables.h"

#define MJColorForStdout [NSColor colorWithCalibratedHue:0.88 saturation:1.0 brightness:0.6 alpha:1.0]
#define MJColorForCommand [NSColor blackColor]
#define MJColorForResult [NSColor colorWithCalibratedHue:0.54 saturation:1.0 brightness:0.7 alpha:1.0]

@interface MJConsoleWindowController ()

@property NSMutableArray* history;
@property NSInteger historyIndex;
@property IBOutlet NSTextView* outputView;
@property (weak) IBOutlet NSTextField* inputField;
@property NSMutableArray* preshownStdouts;

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
    self.preshownStdouts = [NSMutableArray array];
    MJLuaSetupLogHandler(^(NSString* str){
        if (self.outputView) {
            [self appendString:str type:MJReplLineTypeStdout];
            [self.outputView scrollToEndOfDocument:self];
        }
        else {
            [self.preshownStdouts addObject:str];
        }
    });
    [self reflectDefaults];
}

- (void) reflectDefaults {
    [[self window] setLevel: MJConsoleWindowAlwaysOnTop() ? NSFloatingWindowLevel : NSNormalWindowLevel];
}

- (void) windowDidLoad {
    [[self window] center];

    self.history = [NSMutableArray array];
    [self.outputView setEditable:NO];
    [self.outputView setSelectable:YES];

    [self appendString:@""
     "Welcome to the Hammerspoon Console!\n"
     "You can run any Lua code in here.\n\n"
                  type:MJReplLineTypeStdout];

    for (NSString* str in self.preshownStdouts)
        [self appendString:str type:MJReplLineTypeStdout];

    [self.outputView scrollToEndOfDocument:self];
    self.preshownStdouts = nil;
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
    [[self.outputView textStorage] performSelectorOnMainThread:@selector(appendAttributedString:) 
                                       withObject:attrstr
                                    waitUntilDone:YES];
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
    [(HSGrowingTextField *)sender resetGrowth];
    
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

BOOL MJConsoleWindowAlwaysOnTop(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey: MJKeepConsoleOnTopKey];
}

void MJConsoleWindowSetAlwaysOnTop(BOOL alwaysOnTop) {
    [[NSUserDefaults standardUserDefaults] setBool:alwaysOnTop
                                            forKey:MJKeepConsoleOnTopKey];
    [[MJConsoleWindowController singleton] reflectDefaults];
}

#pragma mark - NSTextFieldDelegate

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command {
    BOOL result = YES;

    if (command == @selector(moveUp:)) {
        [self goPrevHistory];
    } else if (command == @selector(moveDown:)) {
        [self goNextHistory];
    } else if (command == @selector(insertTab:)) {// || command == @selector(complete:)) {
        [self.inputField.currentEditor complete:nil];
    } else {
        result = NO;
    }
    return result;
}

- (NSArray<NSString *> *)control:(NSControl *)control
                        textView:(NSTextView *)textView
                     completions:(NSArray<NSString *> *)words
             forPartialWordRange:(NSRange)charRange
             indexOfSelectedItem:(NSInteger *)index
{
    NSString *currentText = textView.string;
    NSString *textBeforeCursor = [currentText substringToIndex:NSMaxRange(charRange)];
    NSString *textAfterCursor = [currentText substringFromIndex:NSMaxRange(charRange)];
    NSString *completionWord = [currentText substringWithRange:charRange];
    NSArray *completions = MJLuaCompletionsForWord(completionWord);
    if (completions.count == 1) {
        // We have only one completion, so we should just insert it into the text field
        NSString *completeWith = [completions objectAtIndex:0];
        NSString *stringToAdd = @"";

        //NSLog(@"Need to shove in the difference between %@ and %@", completeWith, completionWord);

        if ([completeWith hasPrefix:completionWord]) {
            stringToAdd = [completeWith substringFromIndex:[completionWord length]];
        }

        textView.string = [NSString stringWithFormat:@"%@%@%@", textBeforeCursor, stringToAdd, textAfterCursor];
        [textView setSelectedRange:NSMakeRange(NSMaxRange(charRange) + stringToAdd.length, 0)];
        return @[];
    }
    return completions;
}

@end
