#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import "chooser.h"

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

static LSRefTable refTable = LUA_NOREF;

#pragma mark - Lua API defines
static int userdata_gc(lua_State *L);

#pragma mark - Lua API - Constructors

/// hs.chooser.new(completionFn) -> hs.chooser object
/// Constructor
/// Creates a new chooser object
///
/// Parameters:
///  * completionFn - A function that will be called when the chooser is dismissed. It should accept one parameter, which will be nil if the user dismissed the chooser window, otherwise it will be a table containing whatever information you supplied for the item the user chose.
///
/// Returns:
///  * An `hs.chooser` object
///
/// Notes:
///  * As of macOS Sierra and later, if you want a `hs.chooser` object to appear above full-screen windows you must hide the Hammerspoon Dock icon first using: `hs.dockicon.hide()`
static int chooserNew(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK];

    // Parse function arguents
    lua_pushvalue(L, 1);
    int completionCallbackRef = [skin luaRef:refTable];

    // Create the HSChooser object with our arguments
    HSChooser *chooser = [[HSChooser alloc] initWithRefTable:refTable completionCallbackRef:completionCallbackRef];
    [skin pushNSObject:chooser];

    return 1;
}

#pragma mark - Lua API - Methods

/// hs.chooser:show([topLeftPoint]) -> hs.chooser object
/// Method
/// Displays the chooser
///
/// Parameters:
///  * An optional `hs.geometry` point object describing the absolute screen co-ordinates for the top left point of the chooser window. Defaults to centering the window on the primary screen
///
/// Returns:
///  * The hs.chooser object
static int chooserShow(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    if (lua_type(L, 2) == LUA_TTABLE) {
        NSPoint userTopLeft = [skin tableToPointAtIndex:2];
        NSPoint topLeft = NSMakePoint(userTopLeft.x, [NSScreen screens][0].frame.size.height - userTopLeft.y);
        [chooser showAtPoint:topLeft];
    } else {
        [chooser show];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:hide() -> hs.chooser object
/// Method
/// Hides the chooser
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.chooser` object
static int chooserHide(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    [chooser hide];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:isVisible() -> boolean
/// Method
/// Checks if the chooser is currently displayed
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if the chooser is displayed on screen, false if not
static int chooserIsVisible(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    lua_pushboolean(L, [chooser isVisible]);
    return 1;
}

/// hs.chooser:choices(choices) -> hs.chooser object
/// Method
/// Sets the choices for a chooser
///
/// Parameters:
///  * choices - Either a function to call when the list of choices is needed, or nil to remove any existing choices/callback, or a table containing static choices.
///
/// Returns:
///  * The `hs.chooser` object
///
/// Notes:
///  * The table of choices (be it provided statically, or returned by the callback) must contain at least the following keys for each choice:
///   * text - A string or hs.styledtext object that will be shown as the main text of the choice
///  * Each choice may also optionally contain the following keys:
///   * subText - A string or hs.styledtext object that will be shown underneath the main text of the choice
///   * image - An `hs.image` image object that will be displayed next to the choice
///   * valid - A boolean that defaults to `true`, if set to `false` selecting the choice will invoke the `invalidCallback` method instead of dismissing the chooser
///  * Any other keys/values in each choice table will be retained by the chooser and returned to the completion callback when a choice is made. This is useful for storing UUIDs or other non-user-facing information, however, it is important to note that you should not store userdata objects in the table - it is run through internal conversion functions, so only basic Lua types should be stored.
///  * If a function is given, it will be called once, when the chooser window is displayed. The results are then cached until this method is called again, or `hs.chooser:refreshChoicesCallback()` is called.
///  * If you're using a hs.styledtext object for text or subText choices, make sure you specify a color, otherwise your text could appear transparent depending on the bgDark setting.
///
/// Example:
///  ```
/// local choices = {
///  {
///   ["text"] = "First Choice",
///   ["subText"] = "This is the subtext of the first choice",
///   ["uuid"] = "0001"
///  },
///  { ["text"] = "Second Option",
///    ["subText"] = "I wonder what I should type here?",
///    ["uuid"] = "Bbbb"
///  },
///  { ["text"] = hs.styledtext.new("Third Possibility", {font={size=18}, color=hs.drawing.color.definedCollections.hammerspoon.green}),
///    ["subText"] = "What a lot of choosing there is going on here!",
///    ["uuid"] = "III3"
///  },
/// }
///  ```
static int chooserSetChoices(lua_State *L) {
    BOOL staticChoicesTypeCheckPass = NO;

    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TTABLE | LS_TNIL, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    chooser.choicesCallbackRef = [skin luaUnref:refTable ref:chooser.choicesCallbackRef];
    [chooser clearChoices];

    switch (lua_type(L, 2)) {
        case LUA_TNIL:
            break;

        case LUA_TFUNCTION:
            chooser.choicesCallbackRef = [skin luaRef:refTable atIndex:2];
            break;

        case LUA_TTABLE:
            chooser.choicesCallbackRef = [skin luaUnref:refTable ref:chooser.choicesCallbackRef];
            chooser.currentStaticChoices = [skin toNSObjectAtIndex:2];
            if ([chooser.currentStaticChoices isKindOfClass:[NSArray class]]) {
                staticChoicesTypeCheckPass = YES;

                for (id arrayElement in chooser.currentStaticChoices) {
                    if (![arrayElement isKindOfClass:[NSDictionary class]]) {
                        // We have something that doesn't conform, so we might as well break out of the loop immediately
                        staticChoicesTypeCheckPass = NO;
                        break;
                    }
                }
            }

            if (!staticChoicesTypeCheckPass) {
                [skin logError:@"hs.chooser:choices() table could not be parsed correctly."];
                chooser.currentStaticChoices = nil;
            }
            break;

        default:
            [skin logBreadcrumb:@"ERROR: Unknown type passed to hs.chooser:choices(). This should not be possible"];
            break;
    }

    [chooser updateChoices];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:hideCallback([fn]) -> hs.chooser object
/// Method
/// Sets/clears a callback for when the chooser window is hidden
///
/// Parameters:
///  * fn - An optional function that will be called when the chooser window is hidden. If this parameter is omitted, the existing callback will be removed.
///
/// Returns:
///  * The hs.chooser object
///
/// Notes:
///  * This callback is called *after* the chooser is hidden.
///  * This callback is called *after* hs.chooser.globalCallback.
static int chooserHideCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    chooser.hideCallbackRef = [skin luaUnref:refTable ref:chooser.hideCallbackRef];

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        chooser.hideCallbackRef = [skin luaRef:refTable atIndex:2];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:showCallback([fn]) -> hs.chooser object
/// Method
/// Sets/clears a callback for when the chooser window is shown
///
/// Parameters:
///  * fn - An optional function that will be called when the chooser window is shown. If this parameter is omitted, the existing callback will be removed.
///
/// Returns:
///  * The hs.chooser object
///
/// Notes:
///  * This callback is called *after* the chooser is shown. To execute code just before it's shown (and/or after it's removed) see `hs.chooser.globalCallback`
static int chooserShowCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    chooser.showCallbackRef = [skin luaUnref:refTable ref:chooser.showCallbackRef];

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        chooser.showCallbackRef = [skin luaRef:refTable atIndex:2];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:refreshChoicesCallback([reload]) -> hs.chooser object
/// Method
/// Refreshes the choices data from a callback
///
/// Parameters:
///  * reload - An optional parameter that reloads the chooser results to take into account the current query string (defaults to `false`)
///
/// Returns:
///  * The `hs.chooser` object
///
/// Notes:
///  * This method will do nothing if you have not set a function with `hs.chooser:choices()`
static int chooserRefreshChoicesCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    BOOL reload;
    reload = lua_toboolean(L, 2);

    if (chooser.choicesCallbackRef != LUA_NOREF && chooser.choicesCallbackRef != LUA_REFNIL) {
        [chooser clearChoices];
        [chooser getChoices];
        [chooser updateChoices];
        if (reload == YES) {
            [chooser controlTextDidChange:[NSNotification notificationWithName:@"Unused" object:nil]];
        }
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:query([queryString]) -> hs.chooser object or string
/// Method
/// Sets/gets the search string
///
/// Parameters:
///  * queryString - An optional string to search for, or an explicit nil to clear the query. If omitted, the current contents of the search box are returned
///
/// Returns:
///  * The `hs.chooser` object or a string
///
/// Notes:
///  * You can provide an explicit nil or empty string to clear the current query string.
static int chooserSetQuery(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    if (lua_gettop(L) == 1) {
        [skin pushNSObject:chooser.queryField.stringValue];
    } else {
        switch (lua_type(L, 2)) {
            case LUA_TSTRING:
                chooser.queryField.stringValue = [skin toNSObjectAtIndex:2];
                lua_pushvalue(L, 1);
                break;

            case LUA_TNIL:
                chooser.queryField.stringValue = @"" ;
                lua_pushvalue(L, 1);
                break;

            default:
                NSLog(@"ERROR: Unknown type passed to hs.chooser:query(). This should not be possible");
                lua_pushnil(L);
                break;
        }
    }
    return 1;
}

/// hs.chooser:placeholderText([placeholderText]) -> hs.chooser object or string
/// Method
/// Sets/gets placeholder text that is shown in the query text field when no other text is present
///
/// Parameters:
///  * placeholderText - An optional string for placeholder text. If this parameter is omitted, the existing placeholder text will be returned.
///
/// Returns:
///  * The hs.chooser object, or the existing placeholder text
static int chooserPlaceholder(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs: LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    if (lua_gettop(L) == 1) {
        NSObject *placeholderString = chooser.queryField.placeholderAttributedString ;
        if (!placeholderString) placeholderString = chooser.queryField.placeholderString ;
        [skin pushNSObject:placeholderString] ;
    } else {
        chooser.queryField.placeholderAttributedString = [skin toNSObjectAtIndex:2];
        lua_settop(L, 1);
    }
    return 1;
}

/// hs.chooser:queryChangedCallback([fn]) -> hs.chooser object
/// Method
/// Sets/clears a callback for when the search query changes
///
/// Parameters:
///  * fn - An optional function that will be called whenever the search query changes. If this parameter is omitted, the existing callback will be removed.
///
/// Returns:
///  * The hs.chooser object
///
/// Notes:
///  * As the user is typing, the callback function will be called for every keypress. You may wish to do filtering on each call, or you may wish to use a delayed `hs.timer` object to only react when they have finished typing.
///  * The callback function should accept a single argument:
///   * A string containing the new search query
static int chooserQueryCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    chooser.queryChangedCallbackRef = [skin luaUnref:refTable ref:chooser.queryChangedCallbackRef];

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        chooser.queryChangedCallbackRef = [skin luaRef:refTable atIndex:2];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:rightClickCallback([fn]) -> hs.chooser object
/// Method
/// Sets/clears a callback for right clicking on choices
///
/// Parameters:
///  * fn - An optional function that will be called whenever the user right clicks on a choice. If this parameter is omitted, the existing callback will be removed.
///
/// Returns:
///  * The `hs.chooser` object
///
/// Notes:
///   * The callback may accept one argument, the row the right click occurred in or 0 if there is currently no selectable row where the right click occurred. To determine the location of the mouse pointer at the right click, see `hs.mouse`.
///   * To display a context menu, see `hs.menubar`, specifically the `:popupMenu()` method
static int chooserRightClickCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    chooser.rightClickCallbackRef = [skin luaUnref:refTable ref:chooser.rightClickCallbackRef];

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        chooser.rightClickCallbackRef = [skin luaRef:refTable atIndex:2];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:invalidCallback([fn]) -> hs.chooser object
/// Method
/// Sets/clears a callback for invalid choices
///
/// Parameters:
///  * fn - An optional function that will be called whenever the user select an choice set as invalid. If this parameter is omitted, the existing callback will be removed.
///
/// Returns:
///  * The `hs.chooser` object
///
/// Notes:
///   * The callback may accept one argument, it will be a table containing whatever information you supplied for the item the user chose.
///   * To display a context menu, see `hs.menubar`, specifically the `:popupMenu()` method
static int chooserInvalidCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    chooser.invalidCallbackRef = [skin luaUnref:refTable ref:chooser.invalidCallbackRef];

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        chooser.invalidCallbackRef = [skin luaRef:refTable atIndex:2];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:delete()
/// Method
/// Deletes a chooser
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int chooserDelete(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    // FIXME: Should we force the selfRefCount to 1 here, so the _gc call definitely deletes the ObjC object?
    return userdata_gc(L);
}

/// hs.chooser:fgColor(color) -> hs.chooser object
/// Method
/// Sets the foreground color of the chooser
///
/// Parameters:
///  * color - An optional table containing a color specification (see `hs.drawing.color`), or nil to restore the default color. If this parameter is omitted, the existing color will be returned
///
/// Returns:
///  * The `hs.chooser` object or a color table
static int chooserSetFgColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    switch (lua_type(L, 2)) {
        case LUA_TTABLE:
            chooser.fgColor = [skin luaObjectAtIndex:2 toClass:"NSColor"];
            lua_pushvalue(L, 1);
            break;

        case LUA_TNIL:
            chooser.fgColor = nil;
            lua_pushvalue(L, 1);
            break;

        case LUA_TNONE:
            [skin pushNSObject:chooser.fgColor];
            break;

        default:
            NSLog(@"ERROR: Unknown type in hs.chooser:bgColor(). This should not be possible");
            lua_pushnil(L);
            break;
    }

    return 1;
}

/// hs.chooser:subTextColor(color) -> hs.chooser object or hs.color object
/// Method
/// Sets the sub-text color of the chooser
///
/// Parameters:
///  * color - An optional table containing a color specification (see `hs.drawing.color`), or nil to restore the default color. If this parameter is omitted, the existing color will be returned
///
/// Returns:
///  * The `hs.chooser` object or a color table
static int chooserSetSubTextColor(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    switch (lua_type(L, 2)) {
        case LUA_TTABLE:
            chooser.subTextColor = [skin luaObjectAtIndex:2 toClass:"NSColor"];
            lua_pushvalue(L, 1);
            break;

        case LUA_TNIL:
            chooser.subTextColor = nil;
            lua_pushvalue(L, 1);
            break;

        case LUA_TNONE:
            [skin pushNSObject:chooser.subTextColor];
            break;

        default:
            NSLog(@"ERROR: Unknown type in hs.chooser:bgColor(). This should not be possible");
            lua_pushnil(L);
            break;
    }

    return 1;
}

/// hs.chooser:bgDark([beDark]) -> hs.chooser object or boolean
/// Method
/// Sets the background of the chooser between light and dark
///
/// Parameters:
///  * beDark - A optional boolean, true to be dark, false to be light. If this parameter is omitted, the current setting will be returned
///
/// Returns:
///  * The `hs.chooser` object or a boolean, true if the window is dark, false if it is light
///
/// Notes:
///  * The text colors will not automatically change when you toggle the darkness of the chooser window, you should also set appropriate colors with `hs.chooser:fgColor()` and `hs.chooser:subTextColor()`
static int chooserSetBgDark(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNIL | LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    BOOL beDark;

    switch (lua_type(L, 2)) {
        case LUA_TNIL:
            [chooser setBgLightDark:[NSNotification notificationWithName:@"UNUSED" object:nil]];
            lua_pushvalue(L, 1);
            break;

        case LUA_TBOOLEAN:
            beDark = lua_toboolean(L, 2);
            [chooser setBgLightDark:[NSNotification notificationWithName:@"UNUSED" object:[NSNumber numberWithBool:beDark]]];
            lua_pushvalue(L, 1);
            break;

        case LUA_TNONE:
            lua_pushboolean(L, [chooser isBgLightDark]);
            break;

        default:
            NSLog(@"ERROR: Unknown type in hs.chooser:bgDark(). This should not be possible");
            lua_pushnil(L);
            break;
    }

    return 1;
}

/// hs.chooser:searchSubText([searchSubText]) -> hs.chooser object or boolean
/// Method
/// Gets/Sets whether the chooser should search in the sub-text of each item
///
/// Parameters:
///  * searchSubText - An optional boolean, true to search sub-text, false to not search sub-text. If this parameter is omitted, the current configuration value will be returned
///
/// Returns:
///  * The `hs.chooser` object if a value was set, or a boolean if no parameter was passed
///
/// Notes:
///  * This should be used before a chooser has been displayed
static int chooserSetSearchSubText(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    switch (lua_type(L, 2)) {
        case LUA_TBOOLEAN:
            chooser.searchSubText = lua_toboolean(L, 2);
            lua_pushvalue(L, 1);
            break;

        case LUA_TNONE:
            lua_pushboolean(L, chooser.searchSubText);
            return 1;

        default:
            NSLog(@"ERROR: Unknown type passed to hs.chooser:searchSubText(). This should not be possible");
            lua_pushnil(L);
            break;
    }

    return 1;
}

/// hs.chooser:width([percent]) -> hs.chooser object or number
/// Method
/// Gets/Sets the width of the chooser
///
/// Parameters:
///  * percent - An optional number indicating the percentage of the width of the screen that the chooser should occupy. If this parameter is omitted, the current width will be returned
///
/// Returns:
///  * The `hs.chooser` object or a number
///
/// Notes:
///  * This should be used before a chooser has been displayed
static int chooserSetWidth(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    switch (lua_type(L, 2)) {
        case LUA_TNUMBER:
            chooser.width = (CGFloat)lua_tonumber(L, 2);
            lua_pushvalue(L, 1);
            break;

        case LUA_TNONE:
            lua_pushnumber(L, chooser.width);
            break;

        default:
            NSLog(@"ERROR: Unknown type passed to hs.chooser:width(). This should not be possible");
            lua_pushnil(L);
            break;
    }

    return 1;
}

/// hs.chooser:rows([numRows]) -> hs.chooser object or number
/// Method
/// Gets/Sets the number of rows that will be shown
///
/// Parameters:
///  * numRows - An optional number of choices to show (i.e. the vertical height of the chooser window). If this parameter is omitted, the current value will be returned
///
/// Returns:
///  * The `hs.chooser` object or a number
static int chooserSetNumRows(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    switch (lua_type(L, 2)) {
        case LUA_TNUMBER:
            chooser.numRows = (NSInteger)lua_tointeger(L, 2);
            lua_pushvalue(L, 1);
            break;

        case LUA_TNONE:
            lua_pushinteger(L, chooser.numRows);
            break;

        default:
            NSLog(@"ERROR: Unknown type passed to hs.chooser:rows(). This should not be possible");
            lua_pushnil(L);
            break;
    }

    return 1;
}

/// hs.chooser:selectedRow([row]) -> number
/// Method
/// Get or set the currently selected row
///
/// Parameters:
///  * `row` - an optional integer specifying the row to select.
///
/// Returns:
///  * If an argument is provided, returns the hs.chooser object; otherwise returns a number containing the row currently selected (i.e. the one highlighted in the UI)
static int chooserSelectedRow(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    if (lua_gettop(L) == 1) {
        NSInteger selectedRow = chooser.choicesTableView.selectedRow;
        lua_pushinteger(L, (lua_Integer)selectedRow + 1);
    } else {
        NSInteger maxRow = chooser.choicesTableView.numberOfRows - 1;
        NSInteger newRow = lua_tointeger(L, 2) - 1 ;
        newRow = (newRow < 0) ? 0 : ((newRow > maxRow) ? maxRow : newRow) ;
        [chooser.choicesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:newRow] byExtendingSelection:NO] ;
        [chooser.choicesTableView scrollRowToVisible:newRow];
        lua_pushvalue(L, 1) ;
    }
    return 1;
}

/// hs.chooser:selectedRowContents([row]) -> table
/// Method
/// Returns the contents of the currently selected or specified row
///
/// Parameters:
///  * `row` - an optional integer specifying the specific row to return the contents of
///
/// Returns:
///  * a table containing whatever information was supplied for the row currently selected or an empty table if no row is selected or the specified row does not exist.
static int chooserSelectedRowContents(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];
    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    NSInteger selectedRow = (lua_gettop(L) == 1) ? chooser.choicesTableView.selectedRow : (lua_tointeger(L, 2) - 1) ;
    if (selectedRow >= 0 && selectedRow < chooser.choicesTableView.numberOfRows) {
        [skin pushNSObject:[[chooser getChoices] objectAtIndex:selectedRow]];
    } else {
        lua_newtable(L) ;
    }
    return 1 ;
}

/// hs.chooser:select([row]) -> hs.chooser object
/// Method
/// Closes the chooser by selecting the specified row, or the currently selected row if not given
///
/// Parameters:
///  * `row` - an optional integer specifying the row to select.
///
/// Returns:
///  * The `hs.chooser` object
static int chooserSelect(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];

    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    chooserSelectedRow(L);
    lua_pop(L, 1);

    [chooser queryDidPressEnter:nil];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:cancel() -> hs.chooser object
/// Method
/// Cancels the chooser
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.chooser` object
static int chooserCancel(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSChooser *chooser = [skin toNSObjectAtIndex:1];

    [chooser cancel:nil];

    lua_pushvalue(L, 1);
    return 1;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSChooser(lua_State *L, id obj) {
    HSChooser *value = obj;
    value.selfRefCount++;
    void** valuePtr = lua_newuserdata(L, sizeof(HSChooser *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSChooserFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSChooser *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSChooser, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                        lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    HSChooser *chooser = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%@)", USERDATA_TAG, chooser]];
    return 1;
}

static int userdata_eq(lua_State* L) {
    // can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
    // so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSChooser *obj1 = [skin luaObjectAtIndex:1 toClass:"HSChooser"] ;
        HSChooser *obj2 = [skin luaObjectAtIndex:2 toClass:"HSChooser"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}
static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSChooser *chooser = get_objectFromUserdata(__bridge_transfer HSChooser, L, 1, USERDATA_TAG);
    if (chooser) {
        chooser.selfRefCount--;
        if (chooser.selfRefCount == 0) {
            chooser.hideCallbackRef = [skin luaUnref:refTable ref:chooser.hideCallbackRef];
            chooser.showCallbackRef = [skin luaUnref:refTable ref:chooser.showCallbackRef];
            chooser.choicesCallbackRef = [skin luaUnref:refTable ref:chooser.choicesCallbackRef];
            chooser.queryChangedCallbackRef = [skin luaUnref:refTable ref:chooser.queryChangedCallbackRef];
            chooser.completionCallbackRef = [skin luaUnref:refTable ref:chooser.completionCallbackRef];
            chooser.rightClickCallbackRef = [skin luaUnref:refTable ref:chooser.rightClickCallbackRef];
            chooser.invalidCallbackRef = [skin luaUnref:refTable ref:chooser.invalidCallbackRef];
            chooser.isObservingThemeChanges = NO;  // Stop observing for interface theme changes.

            NSWindow *theWindow = chooser.window ;
            if (theWindow.toolbar) {
                theWindow.toolbar.visible = NO ;
                theWindow.toolbar = nil ;
            }

            chooser = nil;
        }
    }

    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0;
}

static const luaL_Reg chooserLib[] = {
    {"new", chooserNew},

    {NULL, NULL}
};

// Metatable for userdata objects
static const luaL_Reg userdataLib[] = {
    {"show", chooserShow},
    {"hide", chooserHide},
    {"isVisible", chooserIsVisible},
    {"choices", chooserSetChoices},
    {"hideCallback", chooserHideCallback},
    {"showCallback", chooserShowCallback},
    {"queryChangedCallback", chooserQueryCallback},
    {"query", chooserSetQuery},
    {"delete", chooserDelete},
    {"refreshChoicesCallback", chooserRefreshChoicesCallback},
    {"rightClickCallback", chooserRightClickCallback},
    {"invalidCallback", chooserInvalidCallback},
    {"selectedRow", chooserSelectedRow},
    {"selectedRowContents", chooserSelectedRowContents},
    {"select", chooserSelect},
    {"cancel", chooserCancel},
    {"fgColor", chooserSetFgColor},
    {"subTextColor", chooserSetSubTextColor},
    {"bgDark", chooserSetBgDark},
    {"placeholderText", chooserPlaceholder},
    {"searchSubText", chooserSetSearchSubText},
    {"width", chooserSetWidth},
    {"rows", chooserSetNumRows},

    {"__tostring", userdata_tostring},
    {"__eq", userdata_eq},
    {"__gc", userdata_gc},
    {NULL, NULL}
};

int luaopen_hs_chooser_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:chooserLib
                                 metaFunctions:nil
                               objectFunctions:userdataLib];

    [skin registerPushNSHelper:pushHSChooser         forClass:"HSChooser"];
    [skin registerLuaObjectHelper:toHSChooserFromLua forClass:"HSChooser" withUserdataMapping:USERDATA_TAG];

    return 1;
}
