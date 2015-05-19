#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lua/lauxlib.h>
#import "../hammerspoon.h"

// ----------------------- Definitions ---------------------

#define USERDATA_TAG "hs.menubar"
#define get_item_arg(L, idx) ((menubaritem_t *)luaL_checkudata(L, idx, USERDATA_TAG))

// Define a base object for our various callback handlers
@interface HSMenubarCallbackObject : NSObject
@property lua_State *L;
@property int fn;
@end
@implementation HSMenubarCallbackObject
// Generic callback runner that will execute a Lua function stored in self.fn
- (void) callback_runner {
    int fn_result;
    NSEvent *event = [NSApp currentEvent];
    lua_State *L = self.L;
    lua_getglobal(L, "debug"); lua_getfield(L, -1, "traceback"); lua_remove(L, -2);
    lua_rawgeti(L, LUA_REGISTRYINDEX, self.fn);
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

        fn_result = lua_pcall(L, 1, 1, -3);
    } else {
        // event is very unlikely to be nil, but we'll handle it just in case
        fn_result = lua_pcall(L, 0, 1, -2);
    }

    if (fn_result != LUA_OK) {
        CLS_NSLOG(@"%s", lua_tostring(L, -1));
        lua_getglobal(L, "hs"); lua_getfield(L, -1, "showError"); lua_remove(L, -2);
        lua_pushvalue(L, -2);
        lua_pcall(L, 1, 0, 0);
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
    int click_fn;
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
            NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];

            // Check to see if we have a submenu, if so, recurse into it
            lua_getfield(L, -1, "menu");
            if (lua_istable(L, -1)) {
                // Create the submenu, populate it and attach it to our current menu item
                NSMenu *subMenu = [[NSMenu alloc] initWithTitle:@"HammerspoonSubMenu"];
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
                delegate.fn = luaL_ref(L, LUA_REGISTRYINDEX);
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
    for (NSMenuItem *menuItem in [menu itemArray]) {
        HSMenubarItemClickDelegate *target = [menuItem representedObject];
        if (target) {
            // This menuitem has a delegate object. Destroy its Lua reference and nuke all the references to the object, so ARC will deallocate it
            luaL_unref(L, LUA_REGISTRYINDEX, target.fn);
            target.fn = LUA_NOREF;
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
void erase_menu_delegate(lua_State *L, NSMenu *menu) {
    HSMenubarItemMenuDelegate *delegate = [menu delegate];
    if (delegate) {
        luaL_unref(L, LUA_REGISTRYINDEX, delegate.fn);
        delegate.fn = LUA_NOREF;
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

// ----------------------- API implementations ---------------------

/// hs.menubar.new() -> menubaritem or nil
/// Constructor
/// Creates a new menu bar item object and add it to the system menubar
///
/// Parameters:
///  * None
///
/// Returns:
///  * menubar item object to use with other API methods, or nil if it could not be created
///
/// Notes:
///  * You should call hs.menubar:setTitle() or hs.menubar:setIcon() after creatng the object, otherwise it will be invisible
static int menubarNew(lua_State *L) {
    NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
    NSStatusItem *statusItem = [statusBar statusItemWithLength:NSVariableStatusItemLength];

    if (statusItem) {
        menubaritem_t *menuBarItem = lua_newuserdata(L, sizeof(menubaritem_t));
        memset(menuBarItem, 0, sizeof(menubaritem_t));

        menuBarItem->menuBarItemObject = (__bridge_retained void*)statusItem;
        menuBarItem->click_callback = nil;
        menuBarItem->click_fn = LUA_NOREF;

        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.menubar:setTitle(title)
/// Method
/// Sets the title of a menubar item object. The title will be displayed in the system menubar
///
/// Parameters:
///  * `title` - A string to use as the title
///
/// Returns:
///  * None
///
/// Notes:
///  * If you set an icon as well as a title, they will both be displayed next to each other
static int menubarSetTitle(lua_State *L) {
    menubaritem_t *menuBarItem = get_item_arg(L, 1);
    NSString *titleText = lua_to_nsstring(L, 2);
    lua_settop(L, 1); // FIXME: This seems unnecessary? neither preceeding luaL_foo function pushes things onto the stack?
    [(__bridge NSStatusItem*)menuBarItem->menuBarItemObject setTitle:titleText];

    return 0;
}

/// hs.menubar:setIcon(iconfilepath) -> bool
/// Method
/// Sets the image of a menubar item object. The image will be displayed in the system menubar
///
/// Parameters:
///  * `iconfilepath` - A filesystem path to an image to be used for the icon
///
/// Returns:
///  * `true` if the image was loaded and set, `nil` if it could not be found or loaded
///
/// Notes:
///  * If you set a title as well as an icon, they will both be displayed next to each other
///  * Icons should be small, transparent images that roughly match the size of normal menubar icons, otherwise they will look very strange
///  * Retina scaling is supported if the image is either scalable (e.g. a PDF produced by Adobe Illustrator) or contain multiple sizes (e.g. a TIFF with small and large images). Images will not automatically do the right thing if you have a @2x version present
///  * Icons are specified as "templates", which allows them to automatically support OS X 10.10's Dark Mode, but this also means they cannot be complicated, colour images
///  * For examples of images that work well, see Hammerspoon.app/Contents/Resources/statusicon.tiff (for a retina-capable multi-image TIFF icon) or [https://github.com/jigish/slate/blob/master/Slate/status.pdf](https://github.com/jigish/slate/blob/master/Slate/status.pdf) (for a scalable vector PDF icon)
///  * For guidelines on the sizing of images, see [http://alastairs-place.net/blog/2013/07/23/nsstatusitem-what-size-should-your-icon-be/](http://alastairs-place.net/blog/2013/07/23/nsstatusitem-what-size-should-your-icon-be/)
static int menubarSetIcon(lua_State *L) {
    menubaritem_t *menuBarItem = get_item_arg(L, 1);
    NSImage *iconImage = [[NSImage alloc] initWithContentsOfFile:lua_to_nsstring(L, 2)];
    lua_settop(L, 1); // FIXME: This seems unnecessary?
    if (!iconImage) {
        lua_pushnil(L);
        return 1;
    }
    [iconImage setTemplate:YES];
    [(__bridge NSStatusItem*)menuBarItem->menuBarItemObject setImage:iconImage];

    lua_pushboolean(L, 1);
    return 1;
}

/// hs.menubar:setTooltip(tooltip)
/// Method
/// Sets the tooltip text on a menubar item
///
/// Parameters:
///  * `tooltip` - A string to use as the tooltip
///
/// Returns:
///  * None
static int menubarSetTooltip(lua_State *L) {
    menubaritem_t *menuBarItem = get_item_arg(L, 1);
    NSString *toolTipText = lua_to_nsstring(L, 2);
    lua_settop(L, 1); // FIXME: This seems unnecessary?
    [(__bridge NSStatusItem*)menuBarItem->menuBarItemObject setToolTip:toolTipText];

    return 0;
}

/// hs.menubar:setClickCallback(fn)
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
///  * None
///
/// Notes:
///  * If a menu has been attached to the menubar item, this callback will never be called
static int menubarSetClickCallback(lua_State *L) {
    menubaritem_t *menuBarItem = get_item_arg(L, 1);
    NSStatusItem *statusItem = (__bridge NSStatusItem*)menuBarItem->menuBarItemObject;
    if (lua_isnil(L, 2)) {
        luaL_unref(L, LUA_REGISTRYINDEX, menuBarItem->click_fn);
        menuBarItem->click_fn = LUA_NOREF;
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
        menuBarItem->click_fn = luaL_ref(L, LUA_REGISTRYINDEX);
        HSMenubarItemClickDelegate *object = [[HSMenubarItemClickDelegate alloc] init];
        object.L = L;
        object.fn = menuBarItem->click_fn;
        menuBarItem->click_callback = (__bridge_retained void*) object;
        [statusItem setTarget:object];
        [statusItem setAction:@selector(click:)];
    }
    return 0;
}

/// hs.menubar:setMenu(menuTable)
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
///
/// Returns:
///  * None
///
/// Notes:
///  * If you are using the callback function, you should take care not to take too long to generate the menu, as you will block the process and the OS may decide to remove the menubar item
static int menubarSetMenu(lua_State *L) {
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
                delegate.fn = luaL_ref(L, LUA_REGISTRYINDEX);
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

    return 0;
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
    NSStatusItem *statusItem = (__bridge NSStatusItem*)menuBarItem->menuBarItemObject;

    // Remove any click callbackery the menubar item has
    lua_pushcfunction(L, menubarSetClickCallback);
    lua_pushvalue(L, 1);
    lua_pushnil(L);
    lua_call(L, 2, 0);

    // Remove all menu stuff associated with this item
    erase_all_menu_parts(L, statusItem);

    [statusBar removeStatusItem:(__bridge NSStatusItem*)menuBarItem->menuBarItemObject];
    menuBarItem->menuBarItemObject = nil;
    menuBarItem = nil;

    return 0;
}

// ----------------------- Lua/hs glue GAR ---------------------

static int menubar_setup(lua_State* __unused L) {
    if (!dynamicMenuDelegates) {
        dynamicMenuDelegates = [[NSMutableArray alloc] init];
    }
    return 0;
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

static const luaL_Reg menubarlib[] = {
    {"new", menubarNew},

    {}
};

static const luaL_Reg menubar_metalib[] = {
    {"setTitle", menubarSetTitle},
    {"setIcon", menubarSetIcon},
    {"setTooltip", menubarSetTooltip},
    {"setClickCallback", menubarSetClickCallback},
    {"setMenu", menubarSetMenu},
    {"delete", menubar_delete},

    {"__gc", menubaritem_gc},
    {}
};

static const luaL_Reg menubar_gclib[] = {
    {"__gc", menubar_gc},

    {}
};

/* NOTE: The substring "hs_menubar_internal" in the following function's name
         must match the require-path of this file, i.e. "hs.menubar.internal". */

int luaopen_hs_menubar_internal(lua_State *L) {
    menubar_setup(L);

    // Metatable for created objects
    luaL_newlib(L, menubar_metalib);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    lua_setfield(L, LUA_REGISTRYINDEX, USERDATA_TAG);

    // Table for luaopen
    luaL_newlib(L, menubarlib);
    luaL_newlib(L, menubar_gclib);
    lua_setmetatable(L, -2);

    return 1;
}
