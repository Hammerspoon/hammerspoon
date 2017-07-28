@import Cocoa ;
@import LuaSkin ;

// TO-DO LIST:
//  * hs.dialog.displayChooseFromList()
//  * hs.dialog.displayColorPicker()
//  * Investigate doing a non-blocking version of all the scripts using NSWindow & callbacks. hs.dialog.displayMessage?
//  * Add setAllowedFileTypes, resolvesAliases to hs.dialog.file()
//  * hs.dialog.file() should probably return a table of the file paths?

static int refTable = LUA_NOREF ;

/// hs.dialog.displayChooseFileOrFolder([canChooseFiles], [canChooseDirectories], [allowsMultipleSelection]) -> string
/// Function
/// Displays a file and/or folder selection dialog box using NSOpenPanel.
///
/// Parameters:
///  * [message] - The optional message text to display.
///  * [defaultPath] - The optional path you want to dialog to open to.
///  * [canChooseFiles] - Whether or not the user can select files. Defaults to `true`.
///  * [canChooseDirectories] - Whether or not the user can select folders. Default to `false`.
///  * [allowsMultipleSelection] - Allow multiple selections of files and/or folders. Defaults to `false`.
///
/// Returns:
///  * The selected files or `nil` if cancel was pressed.
///
/// Notes:
///  * The optional values must be entered in order (i.e. you can't supply `allowsMultipleSelection` without also supplying `canChooseFiles` and `canChooseDirectories`).
static int displayChooseFileOrFolder(lua_State *L) {

    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TOPTIONAL | LS_TSTRING, LS_TOPTIONAL | LS_TSTRING, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    
    NSString* message = [skin toNSObjectAtIndex:1];
    if(message != nil) {
        [panel setMessage:message];
    }

    NSString* path = [skin toNSObjectAtIndex:2];
    if(path != nil) {
        NSURL *url = [[NSURL alloc] initWithString:path];
        [panel setDirectoryURL:url];
    }
    
    if (lua_isboolean(L, 3) && !lua_toboolean(L, 3)) {
        [panel setCanChooseFiles:NO];
    }
    else
    {
        [panel setCanChooseFiles:YES];
        
    }
    
    if (lua_isboolean(L, 4) && lua_toboolean(L, 4)) {
        [panel setCanChooseDirectories:YES];
    }
    else {
        [panel setCanChooseDirectories:NO];
    }
    
    if (lua_isboolean(L, 5) && lua_toboolean(L, 5)) {
        [panel setAllowsMultipleSelection:YES];
    }
    else {
        [panel setAllowsMultipleSelection:NO];
    }

    NSInteger clicked = [panel runModal];

    int count = 1;
    
    if (clicked == NSFileHandlingPanelOKButton) {
        for (NSURL *url in [panel URLs]) {
            count = count + 1;
            lua_pushstring(L,[[url absoluteString] UTF8String]);
        }
        count = count - 1;
    }
    else
    {
        lua_pushnil(L) ;
    }
    
    return count ;
}

/// hs.dialog.displayAlertMessage(message, informativeText, [buttonOne], [buttonTwo], [style], [window]) -> string
/// Function
/// Displays a simple dialog box using `NSAlert`.
///
/// Parameters:
///  * message - The message text to display.
///  * informativeText - The informative text to display.
///  * [buttonOne] - An optional value for the first button as a string. Defaults to "OK".
///  * [buttonTwo] - An optional value for the second button as a string. By default there is no second button.
///  * [style] - An optional style of the dialog box as a string. Defaults to "NSWarningAlertStyle".
///  * [window] - An optional `hs.window` to display the alert on.
///
/// Returns:
///  * The value of the button as a string.
///
/// Notes:
///  * This alert is blocking (i.e. no other Lua code will be processed until the alert is closed).
///  * The optional values must be entered in order (i.e. you can't supply `style` without also supplying `buttonOne` and `buttonTwo`).
///  * [style] can be "NSWarningAlertStyle", "NSInformationalAlertStyle" or "NSCriticalAlertStyle". If something other than these string values is given, it will use "NSWarningAlertStyle".
static int displayAlertMessage(lua_State *L) {
	
    // hs.dialog.alert("Message", "Informative Text", "Button One", "Button Two", "NSCriticalAlertStyle", hs.console.hswindow())
    
	NSString* defaultButton = @"OK";
	
 	LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TSTRING | LS_TOPTIONAL, LS_TSTRING | LS_TOPTIONAL, LS_TANY | LS_TOPTIONAL, LS_TBREAK];

    NSString* message = [skin toNSObjectAtIndex:1];
    NSString* informativeText = [skin toNSObjectAtIndex:2];    
    NSString* buttonOne = [skin toNSObjectAtIndex:3];
    NSString* buttonTwo = [skin toNSObjectAtIndex:4];
    NSString* style = [skin toNSObjectAtIndex:5];
    
    // TO-DO: Work out how to get the hs.window user data and process it acccordingly.
    // window = [skin toNSObjectAtIndex:6];
    
	NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:message];
    [alert setInformativeText:informativeText];
    
	if( buttonOne == nil ){
		[alert addButtonWithTitle:defaultButton];
	}
	else
	{
		[alert addButtonWithTitle:buttonOne];
	}
   
    if (buttonTwo != nil ) {
        [alert addButtonWithTitle:buttonTwo];
    }
		
	if (style == nil){
		[alert setAlertStyle:NSWarningAlertStyle];
	}
	else
	{
		if ([style isEqualToString:@"NSWarningAlertStyle"]) {
			[alert setAlertStyle:NSWarningAlertStyle];
		}
		else if ([style isEqualToString:@"NSInformationalAlertStyle"]) {
			[alert setAlertStyle:NSInformationalAlertStyle];
		}
		else if ([style isEqualToString:@"NSCriticalAlertStyle"]) {
			[alert setAlertStyle:NSCriticalAlertStyle];
		}
        else
        {
            [alert setAlertStyle:NSWarningAlertStyle];
        }
	}

	NSInteger result = [alert runModal];

	if (result == NSAlertFirstButtonReturn) {
		if (buttonOne == nil) {
			lua_pushstring(L,[defaultButton UTF8String]);
		}
		else
		{
			lua_pushvalue(L, 3);
		}
	}
	else if (result == NSAlertSecondButtonReturn) {
		lua_pushvalue(L, 4);
	}
	else
	{
        [LuaSkin logError:@"hs.dialog.alert() - Failed to detect which button was pressed."];
        lua_pushnil(L) ;
	}
    
	return 1 ;
}

/// hs.dialog.displayTextPrompt(message, [defaultText], [buttonOne], [buttonTwo]) -> string, string
/// Function
/// Displays a simple text input dialog box.
///
/// Parameters:
///  * message - The message text to display
///  * informativeText - The informative text to display
///  * [defaultText] - The informative text to display
///  * [buttonOne] - An optional value for the first button as a string
///  * [buttonTwo] - An optional value for the second button as a string
///
/// Returns:
///  * The value of the button as a string
///  * The value of the text input as a string
///
/// Notes:
///  * [buttonOne] defaults to "OK" if no value is supplied.
static int displayTextPrompt(lua_State *L) {
    NSString* defaultButton = @"OK";
    
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TSTRING | LS_TOPTIONAL, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK];
    
    NSString* message = [skin toNSObjectAtIndex:1];
    NSString* informativeText = [skin toNSObjectAtIndex:2];
    NSString* defaultText = [skin toNSObjectAtIndex:3];
    NSString* buttonOne = [skin toNSObjectAtIndex:4];
    NSString* buttonTwo = [skin toNSObjectAtIndex:5];
    
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:message];
    [alert setInformativeText:informativeText];
    
    if( buttonOne == nil ){
        [alert addButtonWithTitle:defaultButton];
    }
    else
    {
        [alert addButtonWithTitle:buttonOne];
    }
    
    if (buttonTwo != nil ) {
        [alert addButtonWithTitle:buttonTwo];
    }
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    if (defaultText == nil) {
        [input setStringValue:@""];
    }
    else
    {
        [input setStringValue:defaultText];
    }
    
    [alert setAccessoryView:input];
    
    NSInteger result = [alert runModal];
    
    if (result == NSAlertFirstButtonReturn) {
        if (buttonOne == nil) {
            lua_pushstring(L,[defaultButton UTF8String]);
            lua_pushstring(L, [[input stringValue] UTF8String]);
        }
        else
        {
            lua_pushvalue(L, 4);
            lua_pushstring(L, [[input stringValue] UTF8String]);
        }
    }
    else if (result == NSAlertSecondButtonReturn) {
        lua_pushvalue(L, 5);
        lua_pushstring(L, [[input stringValue] UTF8String]);
    }
    else
    {
        [LuaSkin logError:@"hs.dialog.alert() - Failed to detect which button was pressed."];
        lua_pushnil(L) ;
    }
    
    return 2 ;
}

// Functions for returned object when module loads:
static luaL_Reg moduleLib[] = {
    {"displayAlertMessage", displayAlertMessage},
    {"displayTextPrompt", displayTextPrompt},
    {"displayChooseFileOrFolder", displayChooseFileOrFolder},
    {NULL,  NULL}
};

int luaopen_hs_dialog_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared];
	refTable = [skin registerLibrary:moduleLib metaFunctions:nil] ;
	
    return 1;
}
