@import Cocoa ;
@import LuaSkin ;

//
// TO-DO LIST:
//
//  * Finish `hs.dialog.colorPicker()`
//  * Add `setAllowedFileTypes`, `resolvesAliases` to `hs.dialog.chooseFileOrFolder()`
//  * Add `hs.dialog.chooseFromList()`
//  * Investigate doing a non-blocking version of all the scripts using NSWindow & callbacks.
//

static int refTable = LUA_NOREF ;

/*
-(void)colorUpdate:(NSColorPanel*)colorPanel{
    NSColor* theColor = colorPanel.color;
}
*/

/// hs.dialog.colorPanel([defaultColor]) -> string
/// Function
/// Displays a System Colour Picker.
///
/// Parameters:
///  * [defaultColor] - An RGB Table to use as the default value
///
/// Returns:
///  * An RGB table with the selected colour or `nil`
static int colorPanel(lua_State *L) {
    
    NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];
    [colorPanel setTarget:nil];
    [colorPanel setAction:nil];
    [colorPanel orderFront:nil];
    return 1;
    
}

/// hs.dialog.chooseFileOrFolder([message], [defaultPath], [canChooseFiles], [canChooseDirectories], [allowsMultipleSelection]) -> string
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
///  * The selected files in a table or `nil` if cancel was pressed.
///
/// Notes:
///  * The optional values must be entered in order (i.e. you can't supply `allowsMultipleSelection` without also supplying `canChooseFiles` and `canChooseDirectories`).
///  * Example:
///      hs.inspect(hs.dialog.chooseFileOrFolder("Please select a file:", "~/Desktop", true, false, true))
static int chooseFileOrFolder(lua_State *L) {

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
        lua_newtable(L);
        for (NSURL *url in [panel URLs]) {
            lua_pushstring(L,[[url absoluteString] UTF8String]); lua_setfield(L, -2, [[NSString stringWithFormat:@"%i", count] UTF8String]);
            count = count + 1;
        }
    }
    else
    {
        lua_pushnil(L);
    }
    
    return 1;
}

/// hs.dialog.webviewAlert(webview, callbackFn, message, informativeText, [buttonOne], [buttonTwo], [style]) -> string
/// Function
/// Displays a simple dialog box using `NSAlert` in a `hs.webview`.
///
/// Parameters:
///  * webview - The `hs.webview` to display the alert on.
///  * callbackFn - The callback function that's called when a button is pressed.
///  * message - The message text to display.
///  * informativeText - The informative text to display.
///  * [buttonOne] - An optional value for the first button as a string. Defaults to "OK".
///  * [buttonTwo] - An optional value for the second button as a string. By default there is no second button.
///  * [style] - An optional style of the dialog box as a string. Defaults to "NSWarningAlertStyle".
///
/// Returns:
///  * nil
///
/// Notes:
///  * This alert is will prevent the user from interacting with the `hs.webview` until a button is pressed on the alert.
///  * The optional values must be entered in order (i.e. you can't supply `style` without also supplying `buttonOne` and `buttonTwo`).
///  * [style] can be "NSWarningAlertStyle", "NSInformationalAlertStyle" or "NSCriticalAlertStyle". If something other than these string values is given, it will use "NSWarningAlertStyle".
///  * Example:
///      testCallbackFn = function(result) print("Callback Result: " .. result) end
///      testWebviewA = hs.webview.newBrowser(hs.geometry.rect(250, 250, 250, 250)):show()
///      testWebviewB = hs.webview.newBrowser(hs.geometry.rect(450, 450, 450, 450)):show()
///      hs.dialog.webviewAlert(testWebviewA, testCallbackFn, "Message", "Informative Text", "Button One", "Button Two", "NSCriticalAlertStyle")
///      hs.dialog.webviewAlert(testWebviewB, testCallbackFn, "Message", "Informative Text", "Single Button")
static int webviewAlert(lua_State *L) {
    
    NSString* defaultButton = @"OK";
    
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, "hs.webview", LS_TFUNCTION, LS_TSTRING, LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TSTRING | LS_TOPTIONAL, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK];
    
    NSWindow *webview = [skin toNSObjectAtIndex:1];
    
    lua_pushvalue(L, 2) ; // Copy the callback function to the top of the stack
    int callbackRef = [skin luaRef:refTable] ; // Store what's at the top of the stack in the registry and save it's reference number. "luaRef" will pull off the top value of the stack, so the net effect of these two lines is to leave the stack of arguments as-is.
    
    NSString *message = [skin toNSObjectAtIndex:3];
    NSString *informativeText = [skin toNSObjectAtIndex:4];
    NSString *buttonOne = [skin toNSObjectAtIndex:5];
    NSString *buttonTwo = [skin toNSObjectAtIndex:6];
    NSString *style = [skin toNSObjectAtIndex:7];
    
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
    
    [alert beginSheetModalForWindow:webview completionHandler:^(NSModalResponse result){
        
        NSString *button = defaultButton;
        
        if (result == NSAlertFirstButtonReturn) {
            if (buttonOne != nil) {
                button = buttonOne;
            }
        }
        else if (result == NSAlertSecondButtonReturn) {
            button = buttonTwo;
        }
        else
        {
            [LuaSkin logError:@"hs.dialog.webviewAlert() - Failed to detect which button was pressed."];
            lua_pushnil(L) ;
        }
        
        
        [skin pushLuaRef:refTable ref:callbackRef] ; // Put the saved function back on the stack.
        [skin luaUnref:refTable ref:callbackRef] ; // Remove the stored function from the registry.
        [skin pushNSObject:button];
        if (![skin protectedCallAndTraceback:1 nresults:0]) { // Returns NO on error, so we check if the result is !YES
            [skin logError:[NSString stringWithFormat:@"hs.dialog:callback error - %s", lua_tostring(L, -1)]]; // -1 indicates the top item of the stack, which will be an error message string in this case
            lua_pop(L, 1) ; // Remove the error from the stack to keep it clean
        }
    }] ;
    
    lua_pushnil(L) ;
    return 1 ;
    
}

/// hs.dialog.alert(message, informativeText, [buttonOne], [buttonTwo], [style]) -> string
/// Function
/// Displays a simple dialog box using `NSAlert`.
///
/// Parameters:
///  * message - The message text to display.
///  * informativeText - The informative text to display.
///  * [buttonOne] - An optional value for the first button as a string. Defaults to "OK".
///  * [buttonTwo] - An optional value for the second button as a string. By default there is no second button.
///  * [style] - An optional style of the dialog box as a string. Defaults to "NSWarningAlertStyle".
///
/// Returns:
///  * The value of the button as a string.
///
/// Notes:
///  * This alert is blocking (i.e. no other Lua code will be processed until the alert is closed).
///  * The optional values must be entered in order (i.e. you can't supply `style` without also supplying `buttonOne` and `buttonTwo`).
///  * [style] can be "NSWarningAlertStyle", "NSInformationalAlertStyle" or "NSCriticalAlertStyle". If something other than these string values is given, it will use "NSWarningAlertStyle".
///  * Example:
///      hs.dialog.alert("Message", "Informative Text", "Button One", "Button Two", "NSCriticalAlertStyle")
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

/// hs.dialog.textPrompt(message, informativeText, [defaultText], [buttonOne], [buttonTwo]) -> string, string
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
///  * Example:
///      hs.dialog.textPrompt("Main message.", "Please enter something:", "Default Value", "Button One", "Button Two")
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
        [LuaSkin logError:@"hs.dialog.textPrompt() - Failed to detect which button was pressed."];
        lua_pushnil(L) ;
    }
    
    return 2 ;
}

// Functions for returned object when module loads:
static luaL_Reg moduleLib[] = {
    {"colorPanel", colorPanel},
    {"webviewAlert", webviewAlert},
    {"alert", alert},
    {"textPrompt", textPrompt},
    {"chooseFileOrFolder", chooseFileOrFolder},
    {NULL,  NULL}
};

int luaopen_hs_dialog_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared];
	refTable = [skin registerLibrary:moduleLib metaFunctions:nil] ;
	
    return 1;
}
