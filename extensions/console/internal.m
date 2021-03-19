@import Cocoa ;
@import LuaSkin ;

#import "MJConsoleWindowController.h"

// NOTE: This is all we need from MJConsoleWindowController.h and MJConsoleWindowController.m

/*
@interface MJConsoleWindowController : NSWindowController

@property NSColor *MJColorForStdout ;
@property NSColor *MJColorForCommand ;
@property NSColor *MJColorForResult ;
@property NSFont  *consoleFont ;

+ (instancetype)singleton;

@end
*/

@interface MJConsoleWindowController ()

@property NSMutableArray *history;
@property NSInteger historyIndex;
@property IBOutlet NSTextView *outputView;
@property (weak) IBOutlet NSTextField *inputField;

- (void) reflectDefaults ;
@end

static LSRefTable refTable = LUA_NOREF;

/// hs.console.darkMode([state]) -> bool
/// Function
/// Set or display whether or not the Console window should display in dark mode.
///
/// Parameters:
///  * state - an optional boolean which will set whether or not the Console window should display in dark mode.
///
/// Returns:
///  * A boolean, true if dark mode is enabled otherwise false.
///
/// Notes:
///  * Enabling Dark Mode for the Console only affects the window background, and doesn't automatically change the Console's Background Color, so you will need to add something similar to:
///    ```lua
///    if hs.console.darkMode() then
///        hs.console.outputBackgroundColor{ white = 0 }
///        hs.console.consoleCommandColor{ white = 1 }
///        hs.console.alpha(.8)
///    end
///.   ```
static int consoleDarkMode(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBOOLEAN|LS_TOPTIONAL, LS_TBREAK];

    if (lua_isboolean(L, 1)) {
        ConsoleDarkModeSetEnabled(lua_toboolean(L, 1));
        [[MJConsoleWindowController singleton] reflectDefaults] ;
    }

    lua_pushboolean(L, ConsoleDarkModeEnabled()) ;
    return 1;
}

/// hs.console.consolePrintColor([color]) -> color
/// Function
/// Get or set the color that regular output displayed in the Hammerspoon console is displayed with.
///
/// Parameters:
///  * color - an optional table containing color keys as described in `hs.drawing.color`
///
/// Returns:
///  * the current color setting as a table
///
/// Notes:
///  * See the `hs.drawing.color` entry in the Dash documentation, or type `help.hs.drawing.color` in the Hammerspoon console to get more information on how to specify a color.
///  * Note this only affects future output -- anything already in the console will remain its current color.
static int console_consolePrintColor(lua_State *L) {
    LuaSkin *skin      = [LuaSkin sharedWithState:L];
    //NSTextView *output = [MJConsoleWindowController singleton].outputView;

    if (lua_type(L, 1) != LUA_TNONE) {
        luaL_checktype(L, 1, LUA_TTABLE);
        [MJConsoleWindowController singleton].MJColorForStdout = [skin luaObjectAtIndex:1 toClass:"NSColor"];
    }

    [skin pushNSObject:[MJConsoleWindowController singleton].MJColorForStdout];
    return 1;
}

/// hs.console.consoleFont([font]) -> fontTable
/// Function
/// Get or set the font used in the Hammerspoon console.
///
/// Parameters:
///  * font - an optional string or table describing the font to use in the console. If a string is specified, then the default system font size will be used.  If a table is specified, it should contain a `name` key-value pair and a `size` key-value pair describing the font to be used.
///
/// Returns:
///  * the current font setting as a table containing a `name` key and a `size` key.
///
/// Notes:
///  * See the `hs.drawing.color` entry in the Dash documentation, or type `help.hs.drawing.color` in the Hammerspoon console to get more information on how to specify a color.
///  * Note this only affects future output -- anything already in the console will remain its current font.
static int console_consoleFont(lua_State *L) {
    LuaSkin *skin      = [LuaSkin sharedWithState:L];
    //NSTextView *output = [MJConsoleWindowController singleton].outputView;

    if (lua_type(L, 1) != LUA_TNONE) {
        NSFont *newFont = [skin luaObjectAtIndex:1 toClass:"NSFont"] ;
        if (newFont) [MJConsoleWindowController singleton].consoleFont = newFont ;
    }

    [skin pushNSObject:[MJConsoleWindowController singleton].consoleFont];
    return 1;
}

/// hs.console.consoleCommandColor([color]) -> color
/// Function
/// Get or set the color that commands displayed in the Hammerspoon console are displayed with.
///
/// Parameters:
///  * color - an optional table containing color keys as described in `hs.drawing.color`
///
/// Returns:
///  * the current color setting as a table
///
/// Notes:
///  * See the `hs.drawing.color` entry in the Dash documentation, or type `help.hs.drawing.color` in the Hammerspoon console to get more information on how to specify a color.
///  * Note this only affects future output -- anything already in the console will remain its current color.
static int console_consoleCommandColor(lua_State *L) {
    LuaSkin *skin      = [LuaSkin sharedWithState:L];
    //NSTextView *output = [MJConsoleWindowController singleton].outputView;

    if (lua_type(L, 1) != LUA_TNONE) {
        luaL_checktype(L, 1, LUA_TTABLE);
        [MJConsoleWindowController singleton].MJColorForCommand = [skin luaObjectAtIndex:1 toClass:"NSColor"];
    }

    [skin pushNSObject:[MJConsoleWindowController singleton].MJColorForCommand];
    return 1;
}

/// hs.console.consoleResultColor([color]) -> color
/// Function
/// Get or set the color that function results displayed in the Hammerspoon console are displayed with.
///
/// Parameters:
///  * color - an optional table containing color keys as described in `hs.drawing.color`
///
/// Returns:
///  * the current color setting as a table
///
/// Notes:
///  * See the `hs.drawing.color` entry in the Dash documentation, or type `help.hs.drawing.color` in the Hammerspoon console to get more information on how to specify a color.
///  * Note this only affects future output -- anything already in the console will remain its current color.
static int console_consoleResultColor(lua_State *L) {
    LuaSkin *skin      = [LuaSkin sharedWithState:L];
    //NSTextView *output = [MJConsoleWindowController singleton].outputView;

    if (lua_type(L, 1) != LUA_TNONE) {
        luaL_checktype(L, 1, LUA_TTABLE);
        [MJConsoleWindowController singleton].MJColorForResult = [skin luaObjectAtIndex:1 toClass:"NSColor"];
    }

    [skin pushNSObject:[MJConsoleWindowController singleton].MJColorForResult];
    return 1;
}

/// hs.console.hswindow() -> hs.window object
/// Function
/// Get an hs.window object which represents the Hammerspoon console window
///
/// Parameters:
///  * None
///
/// Returns:
///  * an hs.window object
static int console_asWindow(lua_State *L) {
    LuaSkin *skin     = [LuaSkin sharedWithState:L];
    NSWindow *console = [[MJConsoleWindowController singleton] window];

    CGWindowID windowID = (CGWindowID)[console windowNumber];
    [skin requireModule:"hs.window"];
    lua_getfield(L, -1, "windowForID");
    lua_pushinteger(L, windowID);
    lua_call(L, 1, 1);
    return 1;
}

/// hs.console.windowBackgroundColor([color]) -> color
/// Function
/// Get or set the color for the background of the Hammerspoon Console's window.
///
/// Parameters:
///  * color - an optional table containing color keys as described in `hs.drawing.color`
///
/// Returns:
///  * the current color setting as a table
///
/// Notes:
///  * See the `hs.drawing.color` entry in the Dash documentation, or type `help.hs.drawing.color` in the Hammerspoon console to get more information on how to specify a color.
static int console_backgroundColor(lua_State *L) {
    LuaSkin *skin     = [LuaSkin sharedWithState:L];
    NSWindow *console = [[MJConsoleWindowController singleton] window];

    if (lua_type(L, 1) != LUA_TNONE) {
        luaL_checktype(L, 1, LUA_TTABLE);
        [console setBackgroundColor:[skin luaObjectAtIndex:1 toClass:"NSColor"]];
    }

    [skin pushNSObject:[console backgroundColor]];
    return 1;
}

/// hs.console.outputBackgroundColor([color]) -> color
/// Function
/// Get or set the color for the background of the Hammerspoon Console's output view.
///
/// Parameters:
///  * color - an optional table containing color keys as described in `hs.drawing.color`
///
/// Returns:
///  * the current color setting as a table
///
/// Notes:
///  * See the `hs.drawing.color` entry in the Dash documentation, or type `help.hs.drawing.color` in the Hammerspoon console to get more information on how to specify a color.
static int console_outputBackgroundColor(lua_State *L) {
    LuaSkin *skin      = [LuaSkin sharedWithState:L];
    NSTextView *output = [MJConsoleWindowController singleton].outputView;

    if (lua_type(L, 1) != LUA_TNONE) {
        luaL_checktype(L, 1, LUA_TTABLE);
        [output setBackgroundColor:[skin luaObjectAtIndex:1 toClass:"NSColor"]];
    }

    [skin pushNSObject:[output backgroundColor]];
    return 1;
}

/// hs.console.inputBackgroundColor([color]) -> color
/// Function
/// Get or set the color for the background of the Hammerspoon Console's input field.
///
/// Parameters:
///  * color - an optional table containing color keys as described in `hs.drawing.color`
///
/// Returns:
///  * the current color setting as a table
///
/// Notes:
///  * See the `hs.drawing.color` entry in the Dash documentation, or type `help.hs.drawing.color` in the Hammerspoon console to get more information on how to specify a color.
static int console_inputBackgroundColor(lua_State *L) {
    LuaSkin *skin      = [LuaSkin sharedWithState:L];
    NSTextField *input = [MJConsoleWindowController singleton].inputField;

    if (lua_type(L, 1) != LUA_TNONE) {
        luaL_checktype(L, 1, LUA_TTABLE);
        [input setBackgroundColor:[skin luaObjectAtIndex:1 toClass:"NSColor"]];
    }

    [skin pushNSObject:[input backgroundColor]];
    return 1;
}

/// hs.console.smartInsertDeleteEnabled([flag]) -> bool
/// Function
/// Determine whether or not objects copied from the console window insert or delete space around selected words to preserve proper spacing and punctuation.
///
/// Parameters:
///  * flag - an optional boolean value indicating whether or not "smart" space behavior is enabled when copying from the Hammerspoon console.
///
/// Returns:
///  * the current value
///
/// Notes:
///  * this only applies to future copy operations from the Hammerspoon console -- anything already in the clipboard is not affected.
static int console_smartInsertDeleteEnabled(lua_State *L) {
    NSTextView *output = [MJConsoleWindowController singleton].outputView;

    if (lua_type(L, 1) != LUA_TNONE) {
        [output setSmartInsertDeleteEnabled:(BOOL)lua_toboolean(L, 1)];
    }

    lua_pushboolean(L, [output smartInsertDeleteEnabled]);
    return 1;
}

/// hs.console.getHistory() -> array
/// Function
/// Get the Hammerspoon console history as an array.
///
/// Parameters:
///  * None
///
/// Returns:
///  * an array containing the history of commands entered into the Hammerspoon console.
static int console_getHistory(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];
    MJConsoleWindowController *console = [MJConsoleWindowController singleton];

    [skin pushNSObject:[console history]];
    return 1;
}

/// hs.console.setConsole([styledText]) -> none
/// Function
/// Clear the Hammerspoon console output window.
///
/// Parameters:
///  * styledText - an optional `hs.styledtext` object containing the text you wish to replace the Hammerspoon console output with.  If you do not provide an argument, the console is cleared of all content.
///
/// Returns:
///  * None
///
/// Notes:
///  * You can specify the console content as a string or as an `hs.styledtext` object in either userdata or table format.
static int console_setConsole(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TANY | LS_TOPTIONAL, LS_TBREAK];
    MJConsoleWindowController *console = [MJConsoleWindowController singleton];

    if (lua_gettop(L) == 0) {
        [[console.outputView textStorage] performSelectorOnMainThread:@selector(setAttributedString:)
                                                           withObject:[[NSMutableAttributedString alloc] init]
                                                        waitUntilDone:YES];
    } else {
        NSAttributedString *theStr;
        if (lua_type(L, 1) == LUA_TUSERDATA && luaL_testudata(L, 1, "hs.styledtext")) {
            theStr = [skin luaObjectAtIndex:1 toClass:"NSAttributedString"];
        } else {
            NSDictionary *consoleAttrs = @{ NSFontAttributeName: [MJConsoleWindowController singleton].consoleFont,
                                            NSForegroundColorAttributeName: [MJConsoleWindowController singleton].MJColorForStdout };
            luaL_tolstring(L, 1, NULL);
            theStr = [[NSAttributedString alloc] initWithString:[skin toNSObjectAtIndex:-1]
                                                     attributes:consoleAttrs];
            lua_pop(L, 1);
        }
        [[console.outputView textStorage] performSelectorOnMainThread:@selector(setAttributedString:)
                                                           withObject:theStr
                                                        waitUntilDone:YES];
    }
    [console.outputView scrollToEndOfDocument:console];
    return 0;
}

/// hs.console.getConsole([styled]) -> text | styledText
/// Function
/// Get the text of the Hammerspoon console output window.
///
/// Parameters:
///  * styled - an optional boolean indicating whether the console text is returned as a string or a styledText object.  Defaults to false.
///
/// Returns:
///  * The text currently in the Hammerspoon console output window as either a string or an `hs.styledtext` object.
///
/// Notes:
///  * If the text of the console is retrieved as a string, no color or style information in the console output is retrieved - only the raw text.
static int console_getConsole(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];
    MJConsoleWindowController *console = [MJConsoleWindowController singleton];
    BOOL styled                        = lua_isboolean(L, 1) ? (BOOL)lua_toboolean(L, 1) : NO;

    if (styled) {
        [skin pushNSObject:[[console.outputView textStorage] copy]];
    } else {
        [skin pushNSObject:[[console.outputView textStorage] string]];
    }

    return 1;
}

/// hs.console.setHistory(array) -> nil
/// Function
/// Set the Hammerspoon console history to the items specified in the given array.
///
/// Parameters:
///  * array - the list of commands to set the Hammerspoon console history to.
///
/// Returns:
///  * None
///
/// Notes:
///  * You can clear the console history by using an empty array (e.g. `hs.console.setHistory({})`
static int console_setHistory(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TTABLE, LS_TBREAK];
    MJConsoleWindowController *console = [MJConsoleWindowController singleton];

    console.history      = [skin toNSObjectAtIndex:1];
    console.historyIndex = (NSInteger)[console.history count];
    lua_pushnil(L);
    return 1;
}

/// hs.console.printStyledtext(...) -> none
/// Function
/// A print function which recognizes `hs.styledtext` objects and renders them as such in the Hammerspoon console.
///
/// Parameters:
///  * Any number of arguments can be specified, just like the builtin Lua `print` command.  If an argument matches the userdata type of `hs.styledtext`, the text is rendered as defined by its style attributes in the Hammerspoon console; otherwise it is rendered as it would be via the traditional `print` command within Hammerspoon.
///
/// Returns:
///  * None
///
/// Notes:
///  * This has been made as close to the Lua `print` command as possible.  You can replace the existing print command with this by adding the following to your `init.lua` file:
///
/// ~~~
///    print = function(...)
///        hs.rawprint(...)
///        hs.console.printStyledtext(...)
///    end
/// ~~~
static int console_printStyledText(lua_State *L) {
    LuaSkin *skin                      = [LuaSkin sharedWithState:L];
    MJConsoleWindowController *console = [MJConsoleWindowController singleton];
    NSDictionary *consoleAttrs         = @{ NSFontAttributeName: [MJConsoleWindowController singleton].consoleFont,
                                    NSForegroundColorAttributeName: [MJConsoleWindowController singleton].MJColorForStdout };

    NSMutableAttributedString *theStr = [[NSMutableAttributedString alloc] init];
    for (int i = 1; i <= lua_gettop(L); i++) {
        if (i > 1) {
            [theStr appendAttributedString:[[NSAttributedString alloc] initWithString:@"\t"
                                                                           attributes:consoleAttrs]];
        }
        if (lua_type(L, i) == LUA_TUSERDATA && luaL_testudata(L, i, "hs.styledtext")) {
            [theStr appendAttributedString:[skin luaObjectAtIndex:i toClass:"NSAttributedString"]];
        } else {
            luaL_tolstring(L, i, NULL);
            [theStr appendAttributedString:[[NSAttributedString alloc]
                                               initWithString:[skin toNSObjectAtIndex:-1]
                                                   attributes:consoleAttrs]];
            lua_pop(L, 1);
        }
    }
    [theStr appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"
                                                                   attributes:consoleAttrs]];

    [[console.outputView textStorage] performSelectorOnMainThread:@selector(appendAttributedString:)
                                                       withObject:theStr
                                                    waitUntilDone:YES];
    [console.outputView scrollToEndOfDocument:console];
    return 0;
}

/// hs.console.level([theLevel]) -> currentValue
/// Function
/// Get or set the console window level
///
/// Parameters:
///  * `theLevel` - an optional parameter specifying the desired level as an integer, which can be obtained from `hs.drawing.windowLevels`.
///
/// Returns:
///  * the current, possibly new, value
///
/// Notes:
///  * see the notes for `hs.drawing.windowLevels`
static int console_level(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK] ;
    NSWindow *console = [[MJConsoleWindowController singleton] window];

    if (lua_gettop(L) == 1) {
        lua_Integer targetLevel = lua_tointeger(L, 1) ;

        if (targetLevel >= CGWindowLevelForKey(kCGMinimumWindowLevelKey) && targetLevel <= CGWindowLevelForKey(kCGMaximumWindowLevelKey)) {
            [console setLevel:targetLevel] ;
        } else {
            return luaL_error(L, [[NSString stringWithFormat:@"window level must be between %d and %d inclusive",
                                   CGWindowLevelForKey(kCGMinimumWindowLevelKey),
                                   CGWindowLevelForKey(kCGMaximumWindowLevelKey)] UTF8String]) ;
        }
    }
    lua_pushinteger(L, console.level) ;
    return 1 ;
}

/// hs.console.alpha([alpha]) -> currentValue
/// Function
/// Get or set the alpha level of the console window.
///
/// Parameters:
///  * `alpha` - an optional number between 0.0 and 1.0 specifying the new alpha level for the Hammerspoon console.
///
/// Returns:
///  * the current, possibly new, value.
static int console_alpha(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    NSWindow *console = [[MJConsoleWindowController singleton] window];

    if (lua_gettop(L) == 1) {
        CGFloat newLevel = luaL_checknumber(L, 1);
        console.alphaValue = ((newLevel < 0.0) ? 0.0 : ((newLevel > 1.0) ? 1.0 : newLevel)) ;
    }
    lua_pushnumber(L, console.alphaValue) ;
    return 1 ;
}

/// hs.console.behavior([behavior]) -> currentValue
/// Method
/// Get or set the window behavior settings for the console.
///
/// Parameters:
///  * `behavior` - an optional number representing the desired window behaviors for the Hammerspoon console.
///
/// Returns:
///  * the current, possibly new, value.
///
/// Notes:
///  * Window behaviors determine how the webview object is handled by Spaces and Exposé. See `hs.drawing.windowBehaviors` for more information.
static int console_behavior(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TOPTIONAL,
                    LS_TBREAK] ;

    NSWindow *console = [[MJConsoleWindowController singleton] window];

    if (lua_gettop(L) == 1) {
        [skin checkArgs:LS_TNUMBER | LS_TINTEGER,
                        LS_TBREAK] ;

        NSInteger newLevel = lua_tointeger(L, 1);
        @try {
            [console setCollectionBehavior:(NSWindowCollectionBehavior)newLevel] ;
        }
        @catch ( NSException *theException ) {
            return luaL_error(L, "%s: %s", [[theException name] UTF8String], [[theException reason] UTF8String]) ;
        }
    }
    lua_pushinteger(L, [console collectionBehavior]) ;
    return 1 ;
}

/// hs.console.titleVisibility([state]) -> current value
/// Function
/// Get or set whether or not the "Hammerspoon Console" text appears in the Hammerspoon console titlebar.
///
/// Parameters:
///  * state - an optional string containing the text "visible" or "hidden", specifying whether or not the console window's title text appears.
///
/// Returns:
///  * a string of "visible" or "hidden" specifying the current (possibly changed) state of the window title's visibility.
///
/// Notes:
///  * When a toolbar is attached to the Hammerspoon console (see the `hs.webview.toolbar` module documentation), this function can be used to specify whether the Toolbar appears underneath the console window's title ("visible") or in the window's title bar itself, as seen in applications like Safari ("hidden"). When the title is hidden, the toolbar will only display the toolbar items as icons without labels, and ignores changes made with `hs.webview.toolbar:displayMode`.
///
///  * If a toolbar is attached to the console, you can achieve the same effect as this function with `hs.console.toolbar():inTitleBar(boolean)`
static int console_titleVisibility(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSWindow *console = [[MJConsoleWindowController singleton] window];
    NSDictionary *mapping = @{
        @"visible" : @(NSWindowTitleVisible),
        @"hidden"  : @(NSWindowTitleHidden),
    } ;

    if (lua_gettop(L) == 1) {
        NSNumber *value = mapping[[skin toNSObjectAtIndex:1]] ;
        if (value) {
            console.titleVisibility = [value intValue] ;
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_argerror(L, 2, [[NSString stringWithFormat:@"must be one of '%@'", [[mapping allKeys] componentsJoinedByString:@"', '"]] UTF8String]) ;
        }
    }
    NSNumber *titleVisibility = @(console.titleVisibility) ;
    NSString *value = [[mapping allKeysForObject:titleVisibility] firstObject] ;
    if (value) {
        [skin pushNSObject:value] ;
    } else {
        [skin logWarn:[NSString stringWithFormat:@"unrecognized titleVisibility %@ -- notify developers", titleVisibility]] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

// static int meta_gc(__unused lua_State *L) {
//     return 0;
// }

static const luaL_Reg extrasLib[] = {
//     {"asHSDrawing", console_asDrawing},

    {"darkMode", consoleDarkMode},

    {"hswindow", console_asWindow},

    {"windowBackgroundColor", console_backgroundColor},
    {"inputBackgroundColor", console_inputBackgroundColor},
    {"outputBackgroundColor", console_outputBackgroundColor},

    {"smartInsertDeleteEnabled", console_smartInsertDeleteEnabled},
    {"getHistory", console_getHistory},
    {"setHistory", console_setHistory},

    {"getConsole", console_getConsole},
    {"setConsole", console_setConsole},

    {"consoleCommandColor", console_consoleCommandColor},
    {"consoleResultColor",  console_consoleResultColor},
    {"consolePrintColor",   console_consolePrintColor},
    {"consoleFont",         console_consoleFont},

    {"titleVisibility", console_titleVisibility},

    {"level", console_level},
    {"alpha", console_alpha},
    {"behavior", console_behavior},

    {"printStyledtext", console_printStyledText},
    {NULL, NULL}};

// static const luaL_Reg metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs_console_internal(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable      = [skin registerLibrary:"hs.console" functions:extrasLib metaFunctions:nil];

    return 1;
}
