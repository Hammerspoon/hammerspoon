#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

// ----------------------- Definitions ---------------------

#define USERDATA_TAG "hs.menubar"
int refTable;
#define get_item_arg(L, idx) ((menubaritem_t *)luaL_checkudata(L, idx, USERDATA_TAG))

// Define a base object for our various callback handlers
@interface HSMenubarCallbackObject : NSObject
@property lua_State *L;
@property int fn;
@end
@implementation HSMenubarCallbackObject
// Generic callback runner that will execute a Lua function stored in self.fn
- (void) callback_runner {
    LuaSkin *skin = [LuaSkin shared];
    lua_State *L = skin.L;

    BOOL fn_result;
    NSEvent *event = [NSApp currentEvent];

    [skin pushLuaRef:refTable ref:self.fn];

    if (event != nil) {
        NSUInteger theFlags = [event modifierFlags];
        BOOL isCommandKey = (theFlags & NSCommandKeyMask) != 0;
        BOOL isShiftKey = (theFlags & NSShiftKeyMask) != 0;
        BOOL isOptKey = (theFlags & NSAlternateKeyMask) != 0;
        BOOL isCtrlKey = (theFlags & NSControlKeyMask) != 0;
        BOOL isFnKey = (theFlags & NSFunctionKeyMask) != 0;

        lua_newtable(L);

        lua_pushboolean(L, isCommandKey);
        lua_setfield(L, -2, "cmd");

        lua_pushboolean(L, isShiftKey);
        lua_setfield(L, -2, "shift");

        lua_pushboolean(L, isOptKey);
        lua_setfield(L, -2, "alt");

        lua_pushboolean(L, isCtrlKey);
        lua_setfield(L, -2, "ctrl");

        lua_pushboolean(L, isFnKey);
        lua_setfield(L, -2, "fn");

        fn_result = [skin protectedCallAndTraceback:1 nresults:1];
    } else {
        // event is very unlikely to be nil, but we'll handle it just in case
        fn_result = [skin protectedCallAndTraceback:0 nresults:1];
    }

    if (!fn_result) {
        const char *errorMsg = lua_tostring(L, -1);
        CLS_NSLOG(@"%s", errorMsg);
        showError(L, (char *)errorMsg);
        return;
    }
}

@end

// Define some basic helper functions
void parse_table(lua_State *L, int idx, NSMenu *menu);
void erase_menu_items(lua_State *L, NSMenu *menu);

// Define a datatype for hs.menubar meta-objects
typedef struct _menubaritem_t {
    void *menuBarItemObject;
    void *click_callback;
    int  click_fn;
    BOOL removed ;
} menubaritem_t;

// Define an array to track delegates for dynamic menu objects
NSMutableArray *dynamicMenuDelegates;

// Define an object for delegate objects to handle clicks on menubar items that have no menu, but wish to act on clicks
@interface HSMenubarItemClickDelegate : HSMenubarCallbackObject
@end
@implementation HSMenubarItemClickDelegate
- (void) click:(id __unused)sender {
    [self callback_runner];
}
@end

// Define an object for dynamic menu objects
@interface HSMenubarItemMenuDelegate : HSMenubarCallbackObject <NSMenuDelegate>
@end
@implementation HSMenubarItemMenuDelegate
- (void) menuNeedsUpdate:(NSMenu *)menu {
    [self callback_runner];

    // Ensure the callback pushed a table onto the stack, then remove any existing menu structure and parse the table into a new menu
    if (lua_type(self.L, lua_gettop(self.L)) == LUA_TTABLE) {
        erase_menu_items(self.L, menu);
        parse_table(self.L, lua_gettop(self.L), menu);
    } else {
        showError(self.L, "You must return a valid Lua table from a callback function passed to hs.menubar:setMenu()");
    }
}
@end

// ----------------------- Helper functions ---------------------

// Helper function to parse a Lua table and turn it into an NSMenu hierarchy (is recursive, so may do terrible things on huge tables)
void parse_table(lua_State *L, int idx, NSMenu *menu) {
    LuaSkin *skin = [LuaSkin shared];

    lua_pushnil(L); // Push a nil to the top of the stack, which lua_next() will interpret as "fetch the first item of the table"
    while (lua_next(L, idx) != 0) {
        // lua_next pushed two things onto the stack, the table item's key at -2 and its value at -1

        // Check that the value is a table
        if (lua_type(L, -1) != LUA_TTABLE) {
            CLS_NSLOG(@"Error: table entry is not a menu item table: %s", lua_typename(L, lua_type(L, -1)));

            // Pop the value off the stack, leaving the key at the top
            lua_pop(L, 1);
            // Bail to the next lua_next() call
            continue;
        }

        // Inspect the menu item table at the top of the stack, fetch the value for the key "title" and push the result to the top of the stack
        lua_getfield(L, -1, "title");
        if (!lua_isstring(L, -1)) {
            // We can't proceed without the title, we'd have nothing to display in the menu, so let's just give up and move on
            CLS_NSLOG(@"Error: malformed menu table entry. Instead of a title string, we found: %s", lua_typename(L, lua_type(L, -1)));
            // We need to pop two things off the stack - the result of lua_getfield and the table it inspected
            lua_pop(L, 2);
            // Bail to the next lua_next() call
            continue;
        }

        // We have found the title of a menu bar item. Turn it into an NSString and pop it off the stack
        NSString *title = lua_to_nsstring(L, -1);
        lua_pop(L, 1);

        if ([title isEqualToString:@"-"]) {
            // We hit the special string for a menu separator
            [menu addItem:[NSMenuItem separatorItem]];
        } else {
            // Create a menu item
            if (!title) {
                title = @"";
            }
            NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];

            // Check to see if we have a submenu, if so, recurse into it
            lua_getfield(L, -1, "menu");
            if (lua_istable(L, -1)) {
                // Create the submenu, populate it and attach it to our current menu item
                NSMenu *subMenu = [[NSMenu alloc] initWithTitle:@"HammerspoonSubMenu"];
                [subMenu setAutoenablesItems:NO];
                parse_table(L, lua_gettop(L), subMenu);
                [menuItem setSubmenu:subMenu];
            }
            lua_pop(L, 1);

            // Inspect the menu item table at the top of the stack, fetch the value for the key "fn" and push the result to the top of the stack
            lua_getfield(L, -1, "fn");
            if (lua_isfunction(L, -1)) {
                // Create the delegate object that will service clicks on this menu item
                HSMenubarItemClickDelegate *delegate = [[HSMenubarItemClickDelegate alloc] init];

                // luaL_ref is going to create a reference to the item at the top of the stack and then pop it off. To avoid confusion, we're going to push the top item on top of itself, so luaL_ref leaves us where we are now
                lua_pushvalue(L, -1);
                delegate.fn = [skin luaRef:refTable];
                delegate.L = L;
                [menuItem setTarget:delegate];
                [menuItem setAction:@selector(click:)];
                [menuItem setRepresentedObject:delegate]; // representedObject is a strong reference, so we don't need to retain the delegate ourselves
            }
            // Pop the result of fetching "fn", off the stack
            lua_pop(L, 1);

            // Check if this item is enabled/disabled, defaulting to enabled
            lua_getfield(L, -1, "disabled");
            if (lua_isboolean(L, -1)) {
                [menuItem setEnabled:!lua_toboolean(L, -1)];
            } else {
                [menuItem setEnabled:YES];
            }
            lua_pop(L, 1);

            // Check if this item is checked/unchecked, defaulting to unchecked
            lua_getfield(L, -1, "checked");
            if (lua_isboolean(L, -1)) {
                [menuItem setState:lua_toboolean(L, -1) ? NSOnState : NSOffState];
            } else {
                [menuItem setState:NSOffState];
            }
            lua_pop(L, 1);

            // We've finished parsing all our options, so now add the menu item to the menu!
            [menu addItem:menuItem];
        }
        // Pop the menu item table off the stack, leaving its key at the top, for lua_next()
        lua_pop(L, 1);
    }
}

// Recursively remove all items from a menu, de-allocating their delegates as we go
void erase_menu_items(lua_State *L, NSMenu *menu) {
    LuaSkin *skin = [LuaSkin shared];

    for (NSMenuItem *menuItem in [menu itemArray]) {
        HSMenubarItemClickDelegate *target = [menuItem representedObject];
        if (target) {
            // This menuitem has a delegate object. Destroy its Lua reference and nuke all the references to the object, so ARC will deallocate it
            target.fn = [skin luaUnref:refTable ref:target.fn];
            [menuItem setTarget:nil];
            [menuItem setAction:nil];
            [menuItem setRepresentedObject:nil];
            target = nil;
        }
        if ([menuItem hasSubmenu]) {
            erase_menu_items(L, [menuItem submenu]);
            [menuItem setSubmenu:nil];
        }
        [menu removeItem:menuItem];
    }
}

// Remove and clean up a dynamic menu delegate
void erase_menu_delegate(lua_State *L __unused, NSMenu *menu) {
    LuaSkin *skin = [LuaSkin shared];

    HSMenubarItemMenuDelegate *delegate = [menu delegate];
    if (delegate) {
        delegate.fn = [skin luaUnref:refTable ref:delegate.fn];
        [dynamicMenuDelegates removeObject:delegate];
        [menu setDelegate:nil];
        delegate = nil;
    }

    return;
}

// Remove any kind of menu on a menubar item
void erase_all_menu_parts(lua_State *L, NSStatusItem *statusItem) {
   NSMenu *menu = [statusItem menu];

   if (menu) {
       erase_menu_delegate(L, menu);
       erase_menu_items(L, menu);
       [statusItem setMenu:nil];
   }

   return;
}

// Create and push a lua geometry rect
static void geom_pushrect(lua_State* L, NSRect rect) {
    lua_newtable(L);
    lua_pushnumber(L, rect.origin.x);    lua_setfield(L, -2, "x");
    lua_pushnumber(L, rect.origin.y);    lua_setfield(L, -2, "y");
    lua_pushnumber(L, rect.size.width);  lua_setfield(L, -2, "w");
    lua_pushnumber(L, rect.size.height); lua_setfield(L, -2, "h");
}

// ----------------------- API implementations ---------------------

/// hs.menubar.new([inMenuBar]) -> menubaritem or nil
/// Constructor
/// Creates a new menu bar item object and optionally add it to the system menubar
///
/// Parameters:
///  * inMenuBar -- an optional parameter which defaults to true.  If it is true, the menubaritem is added to the system menubar, otherwise the menubaritem is hidden.
///
/// Returns:
///  * menubar item object to use with other API methods, or nil if it could not be created
///
/// Notes:
///  * You should call hs.menubar:setTitle() or hs.menubar:setIcon() after creating the object, otherwise it will be invisible
///
///  * Calling this method with inMenuBar equal to false is equivalent to calling hs.menubar.new():removeFromMenuBar().
///  * A hidden menubaritem can be added to the system menubar by calling hs.menubar:returnToMenuBar() or used as a pop-up menu by calling hs.menubar:popupMenu().
static int menubarNew(lua_State *L) {
    NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
    NSStatusItem *statusItem = [statusBar statusItemWithLength:NSVariableStatusItemLength];

    if (statusItem) {
        menubaritem_t *menuBarItem = lua_newuserdata(L, sizeof(menubaritem_t));
        memset(menuBarItem, 0, sizeof(menubaritem_t));

        menuBarItem->menuBarItemObject = (__bridge_retained void*)statusItem;
        menuBarItem->click_callback = nil;
        menuBarItem->click_fn = LUA_NOREF;
        menuBarItem->removed = NO ;

        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);

        if (lua_isboolean(L, 1) && !lua_toboolean(L, 1)) {
              [statusBar removeStatusItem:statusItem];
              menuBarItem->removed = YES ;
        }
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.menubar:setTitle(title) -> menubaritem
/// Method
/// Sets the title of a menubar item object. The title will be displayed in the system menubar
///
/// Parameters:
///  * `title` - A string to use as the title, or nil to remove the title
///
/// Returns:
///  * the menubar item
///
/// Notes:
///  * If you set an icon as well as a title, they will both be displayed next to each other
///  * Has no affect on the display of a pop-up menu, but changes will be be in effect if hs.menubar:returnToMenuBar() is called on the menubaritem.
static int menubarSetTitle(lua_State *L) {
    menubaritem_t *menuBarItem = get_item_arg(L, 1);
    NSString *titleText;
    if (lua_isnoneornil(L, 2)) {
        titleText = nil;
    } else {
        titleText = lua_to_nsstring(L, 2);
    }

    [(__bridge NSStatusItem*)menuBarItem->menuBarItemObject setTitle:titleText];

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.menubar:setIcon(imageData) -> menubaritem or nil
/// Method
/// Sets the image of a menubar item object. The image will be displayed in the system menubar
///
/// Parameters:
///  * imageData - This can one of the following:
///   * An `hs.image` object
///   * A string containing a path to an image file
///   * A string beginning with `ASCII:` which signifies that the rest of the string is interpreted as a special form of ASCII diagram, which will be rendered to an image and used as the icon. See the notes below for information about the special format of ASCII diagram.
///   * nil, indicating that the current image is to be removed
///
/// Returns:
///  * the menubaritem if the image was loaded and set, `nil` if it could not be found or loaded
///
/// Notes:
///  * ** API Change **
///    * This method used to return true on success -- this has been changed to return the menubaritem on success to facilitate method chaining.  Since Lua treats any value which is not nil or false as "true", this should only affect code where the return value was actually being compared to true, e.g. `if result == true then...` rather than the (unaffected) `if result then...`.
///
///  * If you set a title as well as an icon, they will both be displayed next to each other
///  * Has no affect on the display of a pop-up menu, but changes will be be in effect if hs.menubar:returnToMenuBar() is called on the menubaritem.
///
///  * Icons should be small, transparent images that roughly match the size of normal menubar icons, otherwise they will look very strange
///  * Retina scaling is supported if the image is either scalable (e.g. a PDF produced by Adobe Illustrator) or contain multiple sizes (e.g. a TIFF with small and large images). Images will not automatically do the right thing if you have a @2x version present
///  * Icons are specified as "templates", which allows them to automatically support OS X 10.10's Dark Mode, but this also means they cannot be complicated, colour images
///  * For examples of images that work well, see Hammerspoon.app/Contents/Resources/statusicon.tiff (for a retina-capable multi-image TIFF icon) or [https://github.com/jigish/slate/blob/master/Slate/status.pdf](https://github.com/jigish/slate/blob/master/Slate/status.pdf) (for a scalable vector PDF icon)
///  * For guidelines on the sizing of images, see [http://alastairs-place.net/blog/2013/07/23/nsstatusitem-what-size-should-your-icon-be/](http://alastairs-place.net/blog/2013/07/23/nsstatusitem-what-size-should-your-icon-be/)
 ///  * To use the ASCII diagram image support, see http://cocoamine.net/blog/2015/03/20/replacing-photoshop-with-nsstring/ and be sure to preface your ASCII diagram with the special string `ASCII:`

// NOTE: THIS FUNCTION IS WRAPPED IN init.lua
static int menubarSetIcon(lua_State *L) {
    NSImage *iconImage;
    menubaritem_t *menuBarItem = get_item_arg(L, 1);

    if (lua_isnoneornil(L, 2)) {
        iconImage = nil;
    } else {
        iconImage = [[LuaSkin shared] luaObjectAtIndex:2 toClass:"NSImage"] ;

        if (!iconImage) {
            lua_pushnil(L);
            return 1;
        }
        [iconImage setTemplate:YES];
    }
    [(__bridge NSStatusItem*)menuBarItem->menuBarItemObject setImage:iconImage];

//    lua_pushboolean(L, 1); // it's more useful for chaining to return the menubar item, and we return nil if an error occurs, so unless you're doing something like `if result == true ...` instead of just `if result ...` the end result is the same
    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.menubar:setTooltip(tooltip) -> menubaritem
/// Method
/// Sets the tooltip text on a menubar item
///
/// Parameters:
///  * `tooltip` - A string to use as the tooltip
///
/// Returns:
///  * the menubaritem
///
/// Notes:
///  * Has no affect on the display of a pop-up menu, but changes will be be in effect if hs.menubar:returnToMenuBar() is called on the menubaritem.
static int menubarSetTooltip(lua_State *L) {
    menubaritem_t *menuBarItem = get_item_arg(L, 1);
    NSString *toolTipText = lua_to_nsstring(L, 2);
    lua_settop(L, 1); // FIXME: This seems unnecessary?
    [(__bridge NSStatusItem*)menuBarItem->menuBarItemObject setToolTip:toolTipText];

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.menubar:setClickCallback(fn) -> menubaritem
/// Method
/// Registers a function to be called when the menubar item is clicked
///
/// Parameters:
///  * `fn` - A function to be called when the menubar item is clicked. If the argument is `nil`, any existing function will be removed. The function can optionally accept a single argument, which will be a table containing boolean values indicating which keyboard modifiers were held down when the menubar item was clicked; The possible keys are:
///   * cmd
///   * alt
///   * shift
///   * ctrl
///   * fn
///
/// Returns:
///  * the menubaritem
///
/// Notes:
///  * If a menu has been attached to the menubar item, this callback will never be called
///  * Has no affect on the display of a pop-up menu, but changes will be be in effect if hs.menubar:returnToMenuBar() is called on the menubaritem.
static int menubarSetClickCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];

    menubaritem_t *menuBarItem = get_item_arg(L, 1);
    NSStatusItem *statusItem = (__bridge NSStatusItem*)menuBarItem->menuBarItemObject;
    if (lua_isnil(L, 2)) {
        menuBarItem->click_fn = [skin luaUnref:refTable ref:menuBarItem->click_fn];
        if (menuBarItem->click_callback) {
            [statusItem setTarget:nil];
            [statusItem setAction:nil];
            HSMenubarItemClickDelegate *object = (__bridge_transfer HSMenubarItemClickDelegate *)menuBarItem->click_callback;
            menuBarItem->click_callback = nil;
            object = nil;
        }
    } else {
        luaL_checktype(L, 2, LUA_TFUNCTION);
        lua_pushvalue(L, 2);
        menuBarItem->click_fn = [skin luaRef:refTable];
        HSMenubarItemClickDelegate *object = [[HSMenubarItemClickDelegate alloc] init];
        object.L = L;
        object.fn = menuBarItem->click_fn;
        menuBarItem->click_callback = (__bridge_retained void*) object;
        [statusItem setTarget:object];
        [statusItem setAction:@selector(click:)];
    }

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.menubar:setMenu(menuTable) -> menubaritem
/// Method
/// Attaches a dropdown menu to the menubar item
///
/// Parameters:
///  * `menuTable`:
///      * If this argument is `nil`:
///         * Removes any previously registered menu
///      * If this argument is a table:
///         * Sets the menu for this menubar item to the supplied table. The format of the table is documented below
///      * If this argument is a function:
///         * The function will be called each time the user clicks on the menubar item and the function should return a table that specifies the menu to be displayed. The table should be of the same format as described below. The function can optionally accept a single argument, which will be a table containing boolean values indicating which keyboard modifiers were held down when the menubar item was clicked; The possible keys are:
///            * cmd
///            * alt
///            * shift
///            * ctrl
///            * fn
///
/// Table Format:
/// ```
///    {
///        { title = "my menu item", fn = function() print("you clicked my menu item!") end },
///        { title = "-" },
///        { title = "other item", fn = some_function },
///        { title = "disabled item", disabled = true },
///        { title = "checked item", checked = true },
///    }
/// ```
///  * The available keys for each menu item are:
///      * `title` - A string to be displayed in the menu. If this is the special string `"-"` the item will be rendered as a menu separator
///      * `fn` - A function to be executed when the menu item is clicked
///      * `checked` - A boolean to indicate if the menu item should have a checkmark next to it or not. Defaults to false
///      * `disabled` - A boolean to indicate if the menu item should be unselectable or not. Defaults to false (i.e. menu items are selectable by default)
///      * `menu` - a table, in the same format as above, which will be presented as a sub-menu for this menu item.
///         * a menu item that is disabled and has a sub-menu will show the arrow at the right indicating that it has a sub-menu, but the items within the sub-menu will not be available, even if the sub-menu items are not disabled themselves.
///         * a menu item with a sub-menu is also a clickable target, so it can also have an `fn` key.
///
/// Returns:
///  * the menubaritem
///
/// Notes:
///  * If you are using the callback function, you should take care not to take too long to generate the menu, as you will block the process and the OS may decide to remove the menubar item
static int menubarSetMenu(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];

    menubaritem_t *menuBarItem = get_item_arg(L, 1);
    NSStatusItem *statusItem = (__bridge NSStatusItem*)menuBarItem->menuBarItemObject;
    NSMenu *menu = nil;
    HSMenubarItemMenuDelegate *delegate = nil;

    // We always need to start by erasing any pre-existing menu stuff
    erase_all_menu_parts(L, statusItem);

    switch (lua_type(L, 2)) {
        case LUA_TTABLE:
            // This is a static menu, so we can just parse the table and the menu will be populated
            menu = [[NSMenu alloc] initWithTitle:@"HammerspoonMenuItemStaticMenu"];
            if (menu) {
                [menu setAutoenablesItems:NO];
                parse_table(L, 2, menu);

                // If the table returned no useful menu items, we might as well get rid of the menu
                if ([menu numberOfItems] == 0) {
                    menu = nil;
                }
            }
            break;

        case LUA_TFUNCTION:
            // This is a dynamic menu, so create a delegate object that will allow us to fetch a table whenever the menu is about to be displayed
            menu = [[NSMenu alloc] initWithTitle:@"HammerspoonMenuItemDynamicMenu"];
            if (menu) {
                [menu setAutoenablesItems:NO];

                delegate = [[HSMenubarItemMenuDelegate alloc] init];
                delegate.L = L;
                lua_pushvalue(L, 2);
                delegate.fn = [skin luaRef:refTable];
                [dynamicMenuDelegates addObject:delegate]; // store a strong reference to the delegate object, so ARC doesn't deallocate it until we are destroying the menu later
            }
            break;
    }

    if (menu) {
        [statusItem setMenu:menu];
        if (delegate) {
            [menu setDelegate:delegate];
        }
    }

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.menubar:delete()
/// Method
/// Removes the menubar item from the menubar and destroys it
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int menubar_delete(lua_State *L) {
    menubaritem_t *menuBarItem = get_item_arg(L, 1);

    NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
    NSStatusItem *statusItem = (__bridge_transfer NSStatusItem*)menuBarItem->menuBarItemObject;

    // Remove any click callbackery the menubar item has
    lua_pushcfunction(L, menubarSetClickCallback);
    lua_pushvalue(L, 1);
    lua_pushnil(L);
    lua_call(L, 2, 0);

    // Remove all menu stuff associated with this item
    erase_all_menu_parts(L, statusItem);

    if (!menuBarItem->removed) {
        [statusBar removeStatusItem:statusItem];
    }

    menuBarItem->menuBarItemObject = nil;
    menuBarItem = nil;

    return 0;
}

/// hs.menubar:popupMenu(point) -> menubaritem
/// Method
/// Display a menubaritem as a pop up menu at the specified screen point.
///
/// Parameters:
///  * point -- the location of the upper left corner of the pop-up menu to be displayed.
///
/// Returns:
///  * The menubaritem
///
/// Notes:
///  * Items which trigger hs.menubar:setClickCallback() will invoke the callback function, but we cannot control the positioning of any visual elements the function may create -- calling this method on such an object is the equivalent of invoking its callback function directly.
///
///  * This method is blocking -- Hammerspoon will be unable to respond to any other activity while the pop-up menu is being displayed.
static int menubar_render(lua_State *L) {
    menubaritem_t *menuBarItem = get_item_arg(L, 1);
    NSStatusItem  *statusItem  = (__bridge NSStatusItem*)menuBarItem->menuBarItemObject;
    NSMenu        *menu        = [statusItem menu];

    NSPoint menuPoint ;

    switch (lua_type(L, 2)) {
        case LUA_TTABLE:
            lua_getfield(L, 2, "x") ;
            menuPoint.x = lua_tonumber(L, -1) ;
            lua_pop(L, 1) ;

            lua_getfield(L, 2, "y") ;
            menuPoint.y = lua_tonumber(L, -1) ;
            lua_pop(L, 1) ;

            break ;
        default:
            CLS_NSLOG(@"ERROR: Unexpected type passed to hs.menubar:render(): %d", lua_type(L, 2)) ;
            showError(L, (char *)[[NSString stringWithFormat:@"Unexpected type passed to hs.menubar:render(): %d", lua_type(L, 2)] UTF8String]) ;
            lua_pushnil(L) ;
            return 1 ;
    }

    if (!menu) {

        if (menuBarItem->click_callback)
            [((__bridge HSMenubarItemClickDelegate *)menuBarItem->click_callback) click:0] ;
        else {
            printToConsole(L, "-- Missing menu object for hs.menu.popupMenu()") ;

//     // Used for testing, but inconsistent with the rest of hs.menubar's behavior for empty menus.
//             menu = [[NSMenu alloc] init];
//             [menu insertItemWithTitle:@"-- empty/deleted menu --"
//                                action:nil
//                         keyEquivalent:@""
//                               atIndex:0];
//             [[menu itemAtIndex:0] setEnabled:NO] ;
        }
        // Not an error, per se, so return expected value.
        lua_settop(L, 1) ;
        return 1 ;
    }

    menuPoint.y = [[NSScreen screens][0] frame].size.height - menuPoint.y ;
    [menu popUpMenuPositioningItem:nil atLocation:menuPoint inView:nil] ;

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.menubar:removeFromMenuBar() -> menubaritem
/// Method
/// Removes a menu from the system menu bar.  The item can still be used as a pop-up menu, unless you also delete it.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the menubaritem
static int menubar_removeFromMenuBar(lua_State *L) {
    menubaritem_t *menuBarItem = get_item_arg(L, 1);

    if (!menuBarItem->removed) {
        NSStatusBar   *statusBar   = [NSStatusBar systemStatusBar];
        NSStatusItem  *statusItem  = (__bridge NSStatusItem*)menuBarItem->menuBarItemObject;

        [statusBar removeStatusItem:statusItem];
        menuBarItem->removed = YES ;
    }

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.menubar:returnToMenuBar() -> menubaritem
/// Method
/// Returns a previously removed menu back to the system menu bar.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the menubaritem
static int menubar_returnToMenuBar(lua_State *L) {
    menubaritem_t *menuBarItem     = get_item_arg(L, 1);

    if (menuBarItem->removed) {
        NSStatusBar   *statusBar       = [NSStatusBar systemStatusBar];
        NSStatusItem  *oldStatusItem   = (__bridge_transfer NSStatusItem*)menuBarItem->menuBarItemObject;

        NSStatusItem  *newStatusItem   = [statusBar statusItemWithLength:NSVariableStatusItemLength];
        menuBarItem->menuBarItemObject = (__bridge_retained void*)newStatusItem;
        [newStatusItem  setTarget:[oldStatusItem target]] ;
        [newStatusItem  setAction:[oldStatusItem action]] ;
        [newStatusItem    setMenu:[oldStatusItem menu]] ;
        [newStatusItem   setTitle:[oldStatusItem title]] ;
        [newStatusItem   setImage:[oldStatusItem image]] ;
        [newStatusItem setToolTip:[oldStatusItem toolTip]] ;

        menuBarItem->removed = NO ;
    }

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.menubar:title() -> string
/// Method
/// Returns the current title of the menubar item object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the menubar item title, or an empty string, if there isn't one.
static int menubarGetTitle(lua_State *L) {
    menubaritem_t *menuBarItem     = get_item_arg(L, 1);

    lua_pushstring(L, [[(__bridge NSStatusItem*)menuBarItem->menuBarItemObject title] UTF8String]) ;
    return 1 ;
}

/// hs.menubar:icon() -> hs.image object
/// Method
/// Returns the current icon of the menubar item object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the menubar item icon as an hs.image object, or nil, if there isn't one.
static int menubarGetIcon(lua_State *L) {
    menubaritem_t *menuBarItem     = get_item_arg(L, 1);

    NSImage* theImage = [(__bridge NSStatusItem*)menuBarItem->menuBarItemObject image] ;

    if (theImage)
        [[LuaSkin shared] pushNSObject:theImage];
    else
        lua_pushnil(L) ;

    return 1 ;
}

static int menubarFrame(lua_State *L) {
    menubaritem_t *menuBarItem = get_item_arg(L, 1);
    NSStatusItem *statusItem = (__bridge NSStatusItem*)menuBarItem->menuBarItemObject;
    NSRect frame = [[statusItem valueForKey:@"window"] frame];

    geom_pushrect(L, frame);

    return 1;
}

// ----------------------- Lua/hs glue GAR ---------------------

void menubar_setup() {
    if (!dynamicMenuDelegates) {
        dynamicMenuDelegates = [[NSMutableArray alloc] init];
    }
}

static int menubar_gc(lua_State* __unused L) {
    // TODO: Should we keep a registry of menubar items and clean them up here? They ought to have been __gc'd by this point.
    [dynamicMenuDelegates removeAllObjects];
    dynamicMenuDelegates = nil;
    return 0;
}

static int menubaritem_gc(lua_State *L) {
    lua_pushcfunction(L, menubar_delete) ; lua_pushvalue(L, 1); lua_call(L, 1, 1);
    return 0;
}

static int userdata_tostring(lua_State* L) {
    NSString *title = [((__bridge NSStatusItem*)(get_item_arg(L, 1))->menuBarItemObject) title] ;

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static const luaL_Reg menubarlib[] = {
    {"new", menubarNew},

    {NULL, NULL}
};

static const luaL_Reg menubar_metalib[] = {
    {"setTitle",          menubarSetTitle},
    {"_setIcon",          menubarSetIcon},
    {"title",             menubarGetTitle},
    {"icon",              menubarGetIcon},
    {"setTooltip",        menubarSetTooltip},
    {"setClickCallback",  menubarSetClickCallback},
    {"setMenu",           menubarSetMenu},
    {"popupMenu",         menubar_render},
    {"removeFromMenuBar", menubar_removeFromMenuBar},
    {"returnToMenuBar",   menubar_returnToMenuBar},
    {"delete",            menubar_delete},
    {"_frame",            menubarFrame},

    {"__tostring",        userdata_tostring},
    {"__gc",              menubaritem_gc},
    {NULL, NULL}
};

static const luaL_Reg menubar_gclib[] = {
    {"__gc", menubar_gc},

    {NULL, NULL}
};

/* NOTE: The substring "hs_menubar_internal" in the following function's name
         must match the require-path of this file, i.e. "hs.menubar.internal". */

int luaopen_hs_menubar_internal(lua_State *L __unused) {
    LuaSkin *skin = [LuaSkin shared];

    menubar_setup();

    refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:menubarlib metaFunctions:menubar_gclib objectFunctions:menubar_metalib];

    return 1;
}
