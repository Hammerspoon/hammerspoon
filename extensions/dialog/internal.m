@import Cocoa ;
@import LuaSkin ;

// TO-DO LIST:
//  * Finsh hs.dialog.file()
//  * Build hs.dialog.list()
//  * Investigate doing a non-blocking version of all the scripts ussing callbacks.

static int refTable = LUA_NOREF ;

/// hs.dialog.file([canChooseFiles], [canChooseDirectories], [allowsMultipleSelection]) -> string
/// Function
/// Displays a file and/or folder selection dialog box.
///
/// Parameters:
///  * [canChooseFiles] - Whether or not the user can select files
///  * [canChooseDirectories] - Whether or not the user can select folders
///  * [allowsMultipleSelection] - Allow multiple selections of files and/or folders
///
/// Returns:
///  * The value of the button as a string.
static int file(lua_State *L) {

    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];
    
    //BOOL canChooseFiles = [skin toNSObjectAtIndex:1];
    //BOOL canChooseDirectories = [skin toNSObjectAtIndex:2];
    //BOOL allowsMultipleSelection = [skin toNSObjectAtIndex:3];
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:NO];
    [panel setCanChooseDirectories:YES];
    [panel setAllowsMultipleSelection:YES]; // yes if more than one dir is allowed

    NSInteger clicked = [panel runModal];

    if (clicked == NSFileHandlingPanelOKButton) {
        for (NSURL *url in [panel URLs]) {
            // do something with the url here.
            lua_pushstring(L,[[url absoluteString] UTF8String]);
        }
    }
    else
    {
        lua_pushnil(L) ;
    }
    
    return 1 ;
}

/// hs.dialog.alert(message, informativeText, [buttonOne], [buttonTwo], [style]) -> string
/// Function
/// Displays a simple dialog box.
///
/// Parameters:
///  * message - The message text to display
///  * informativeText - The informative text to display
///  * [buttonOne] - An optional value for the first button as a string
///  * [buttonTwo] - An optional value for the second button as a string
///  * [style] - Style of the dialog box as a string
///
/// Returns:
///  * The value of the button as a string.
///
/// Notes:
///  * [buttonOne] defaults to "OK" if no value is supplied.
///  * [style] can be "NSWarningAlertStyle", "NSInformationalAlertStyle" or "NSCriticalAlertStyle". If no value is given, then "NSWarningAlertStyle" will be used by default.
static int alert(lua_State *L) {	
	
	NSString* defaultButton = @"OK";
	
 	LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TSTRING | LS_TOPTIONAL, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK];

    NSString* message = [skin toNSObjectAtIndex:1];
    NSString* informativeText = [skin toNSObjectAtIndex:2];    
    NSString* buttonOne = [skin toNSObjectAtIndex:3];
    NSString* buttonTwo = [skin toNSObjectAtIndex:4];
    NSString* style = [skin toNSObjectAtIndex:5];
	
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

/// hs.dialog.textPrompt(message, [defaultText], [buttonOne], [buttonTwo]) -> string, string
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
static int textPrompt(lua_State *L) {
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
    {"alert", alert},
    {"textPrompt", textPrompt},
    {"file", file},
    {NULL,  NULL}
};

int luaopen_hs_dialog_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared];
	refTable = [skin registerLibrary:moduleLib metaFunctions:nil] ;
	
    return 1;
}
