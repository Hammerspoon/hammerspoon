#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import "chooser.h"

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
static int chooserNew(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK];

    // Create the userdata object
    chooser_userdata_t *userData = lua_newuserdata(L, sizeof(chooser_userdata_t));
    memset(userData, 0, sizeof(chooser_userdata_t));
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    // Parse function arguents
    lua_pushvalue(L, 1);
    int completionCallbackRef = [skin luaRef:refTable];

    // Create the HSChooser object with our arguments
    HSChooser *chooser = [[HSChooser alloc] initWithRefTable:&refTable completionCallbackRef:completionCallbackRef];
    userData->chooser = (__bridge_retained void*)chooser;

    return 1;
}

#pragma mark - Lua API - Methods

/// hs.chooser:show() -> hs.chooser object
/// Method
/// Displays the chooser
///
/// Parameters:
///  * None
///
/// Returns:
///  * The hs.chooser object
static int chooserShow(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

    [chooser show];

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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

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
///   * text - A string that will be shown as the main text of the choice
///  * Each choice may also optionally contain the following keys:
///   * subText - A string that will be shown underneath the main text of the choice
///   * image - An `hs.image` image object that will be displayed next to the choice
///  * Any other keys/values in each choice table will be retained by the chooser and returned to the completion callback when a choice is made. This is useful for storing UUIDs or other non-user-facing information, however, it is important to note that you should not store userdata objects in the table - it is run through internal conversion functions, so only basic Lua types should be stored.
///  * If a function is given, it will be called once, when the chooser window is displayed. The results are then cached until this method is called again, or `hs.chooser:refreshChoicesCallback()` is called.
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
///  { ["text"] = "Third Possibility",
///    ["subText"] = "What a lot of choosing there is going on here!",
///    ["uuid"] = "III3"
///  },
/// }
///  ```
static int chooserSetChoices(lua_State *L) {
    BOOL staticChoicesTypeCheckPass = NO;

    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TTABLE | LS_TNIL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

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

/// hs.chooser:showCallback([fn]) -> hs.chooser object
/// Method
/// Sets/clears a callback for when the chooser window is shown
///
/// Parameters:
///  * fn - An optional function that will be called when the chooser window is shown. If this parameter is omitted, the existing callback will be removed.
///
/// Returns:
///  * The hs.chooser object
static int chooserShowCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

    chooser.showCallbackRef = [skin luaUnref:refTable ref:chooser.showCallbackRef];

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        chooser.showCallbackRef = [skin luaRef:refTable atIndex:2];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:refreshChoicesCallback() -> hs.chooser object
/// Method
/// Refreshes the choices data from a callback
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.chooser` object
///
/// Notes:
///  * This method will do nothing if you have not set a function with `hs.chooser:choices()`
static int chooserRefreshChoicesCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

    if (chooser.choicesCallbackRef != LUA_NOREF && chooser.choicesCallbackRef != LUA_REFNIL) {
        [chooser clearChoices];
        [chooser getChoices];
        [chooser updateChoices];
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNIL | LS_TOPTIONAL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

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
///  * fn - An optional function taht will be called whenever the user right clicks on a choice. If this parameter is omitted, the existing callback will be removed.
///
/// Returns:
///  * The hs.chosoer object
///
/// Notes:
///   * The callback may accept one argument, the row the right click occurred in or 0 if there is currently no selectable row where the right click occurred. To determine the location of the mouse pointer at the right click, see `hs.mouse`.
///   * To display a context menu, see `hs.menubar`, specifically the `:popupMenu()` method
static int chooserRightClickCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

    chooser.rightClickCallbackRef = [skin luaUnref:refTable ref:chooser.rightClickCallbackRef];

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        chooser.rightClickCallbackRef = [skin luaRef:refTable atIndex:2];
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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNIL | LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

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
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];
    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

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
    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

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
    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

    [chooser cancel:nil];

    lua_pushvalue(L, 1);
    return 1;
}

#pragma mark - Hammerspoon Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    chooser_userdata_t *userData = lua_touserdata(L, 1);
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, (void *)userData]];
    return 1;
}

static int userdata_gc(lua_State* L) {
    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge_transfer HSChooser *)userData->chooser;
    if (chooser) {
        LuaSkin *skin = [LuaSkin shared] ;
        chooser.showCallbackRef = [skin luaUnref:refTable ref:chooser.showCallbackRef];
        chooser.choicesCallbackRef = [skin luaUnref:refTable ref:chooser.choicesCallbackRef];
        chooser.queryChangedCallbackRef = [skin luaUnref:refTable ref:chooser.queryChangedCallbackRef];
        chooser.completionCallbackRef = [skin luaUnref:refTable ref:chooser.completionCallbackRef];
        chooser.rightClickCallbackRef = [skin luaUnref:refTable ref:chooser.rightClickCallbackRef];
        chooser.isObservingThemeChanges = NO;  // Stop observing for interface theme changes.
    }
    userData->chooser = nil;
    chooser = nil;

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
    {"showCallback", chooserShowCallback},
    {"queryChangedCallback", chooserQueryCallback},
    {"query", chooserSetQuery},
    {"delete", chooserDelete},
    {"refreshChoicesCallback", chooserRefreshChoicesCallback},
    {"rightClickCallback", chooserRightClickCallback},
    {"selectedRow", chooserSelectedRow},
    {"selectedRowContents", chooserSelectedRowContents},
    {"select", chooserSelect},
    {"cancel", chooserCancel},
    {"fgColor", chooserSetFgColor},
    {"subTextColor", chooserSetSubTextColor},
    {"bgDark", chooserSetBgDark},
    {"searchSubText", chooserSetSearchSubText},
    {"width", chooserSetWidth},
    {"rows", chooserSetNumRows},

    {"__tostring", userdata_tostring},
    {"__gc", userdata_gc},
    {NULL, NULL}
};

int luaopen_hs_chooser_internal(__unused lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:chooserLib
                                 metaFunctions:nil
                               objectFunctions:userdataLib];

    return 1;
}
