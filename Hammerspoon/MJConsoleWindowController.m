#import "MJConsoleWindowController.h"
#import "MJLua.h"
#import "variables.h"

//
// Enable & Disable Console Dark Mode:
//
BOOL ConsoleDarkModeEnabled(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:HSConsoleDarkModeKey];
}

void ConsoleDarkModeSetEnabled(BOOL enabled) {
    [[NSUserDefaults standardUserDefaults] setBool:enabled
                                            forKey:HSConsoleDarkModeKey];
}

@interface MJConsoleWindowController ()

@property NSMutableArray* history;
@property NSInteger historyIndex;
@property IBOutlet NSTextView* outputView;
@property (weak) IBOutlet NSTextField* inputField;
@property NSMutableArray* preshownStdouts;
@property NSDateFormatter *dateFormatter;

@end

typedef NS_ENUM(NSUInteger, MJReplLineType) {
    MJReplLineTypeCommand,
    MJReplLineTypeResult,
    MJReplLineTypeStdout,
};

@implementation MJConsoleWindowController

- (id) init {
    self = [super init];
    if (self) {
        self.dateFormatter = [[NSDateFormatter alloc] init];
        NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        [self.dateFormatter setLocale:enUSPOSIXLocale];
        [self.dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];

        [self initializeConsoleColorsAndFont] ;
    }
    return self;
}

- (void)initializeConsoleColorsAndFont {
    self.MJColorForStdout  = [NSColor colorWithCalibratedHue:0.88 saturation:1.0 brightness:0.6 alpha:1.0] ;
    self.MJColorForCommand = [NSColor blackColor] ;
    self.MJColorForResult  = [NSColor colorWithCalibratedHue:0.54 saturation:1.0 brightness:0.7 alpha:1.0] ;
    self.consoleFont       = [NSFont fontWithName:@"Menlo" size:12.0] ;
}

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
    
    //
    // Dark Mode:
    //        
    if (ConsoleDarkModeEnabled()) {
        self.window.appearance = [NSAppearance appearanceNamed: NSAppearanceNameVibrantDark] ;
        self.window.titlebarAppearsTransparent = YES ;
        self.outputView.enclosingScrollView.drawsBackground = NO ;
    } else {
        self.window.appearance = [NSAppearance appearanceNamed: NSAppearanceNameVibrantLight] ;
        self.window.titlebarAppearsTransparent = NO ;
        self.outputView.enclosingScrollView.drawsBackground = YES ;
    }

    [[self window] setLevel: MJConsoleWindowAlwaysOnTop() ? NSFloatingWindowLevel : NSNormalWindowLevel];
}

- (void) windowDidLoad {
    
    // Save & Restore Last Window Location to Preferences:
    [self setShouldCascadeWindows:NO];
    [self setWindowFrameAutosaveName:@"console"];

    self.history = [NSMutableArray array];
    [self.outputView setEditable:NO];
    [self.outputView setSelectable:YES];

    /*
    [self appendString:@""
     "Welcome to the Hammerspoon Console!\n"
     "You can run any Lua code in here.\n\n"
                  type:MJReplLineTypeStdout];
     */

    for (NSString* str in self.preshownStdouts)
        [self appendString:str type:MJReplLineTypeStdout];

    [self.outputView scrollToEndOfDocument:self];
    self.preshownStdouts = nil;
}

- (void) appendString:(NSString*)str type:(MJReplLineType)type {
    NSColor* color = self.MJColorForStdout;

    if (!str) {
        return;
    }

    switch (type) {
        case MJReplLineTypeStdout:  color = self.MJColorForStdout; break;
        case MJReplLineTypeCommand: color = self.MJColorForCommand; break;
        case MJReplLineTypeResult:  color = self.MJColorForResult; break;
    }

    if (type == MJReplLineTypeStdout) {
        str = [NSString stringWithFormat:@"%@: %@", [self.dateFormatter stringFromDate:[NSDate date]], str];
    }

    NSDictionary* attrs = @{NSFontAttributeName: self.consoleFont, NSForegroundColorAttributeName: color};
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
    [(HSGrowingTextField *)self.inputField resetGrowth];

    if (self.historyIndex == [self.history count])
        [self.inputField setStringValue: @""];
    else
        [self.inputField setStringValue: [self.history objectAtIndex:self.historyIndex]];

    NSText* editor = [[self.inputField window] fieldEditor:YES forObject:self.inputField];
    NSRange position = (NSRange){[[editor string] length], 0};
    [editor setSelectedRange:position];
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
