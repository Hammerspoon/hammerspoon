#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>

#define USERDATA_TAG "hs.menubar"

@interface clickDelegate : NSObject
@property lua_State *L;
@property int fn;
@end

@implementation clickDelegate
- (void) click:(id __unused)sender {
    lua_State *L = self.L;
    lua_getglobal(L, "debug"); lua_getfield(L, -1, "traceback"); lua_remove(L, -2);
    lua_rawgeti(L, LUA_REGISTRYINDEX, self.fn);
    if (lua_pcall(L, 0, 0, -2) != 0) {
        NSLog(@"%s", lua_tostring(L, -1));
        lua_getglobal(L, "hs"); lua_getfield(L, -1, "showError"); lua_remove(L, -2);
        lua_pushvalue(L, -2);
        lua_pcall(L, 1, 0, 0);
    }
}
@end

typedef struct _menubaritem_t {
    void *menuBarItemObject;
    void *click_callback;
    int click_fn;
} menubaritem_t;

/// hs.menubar.new() -> menubaritem
/// Constructor
/// Creates a new menu bar item object, which can be added to the system menubar by calling menubaritem:add()
///
/// Note: You likely want to call either hs.menubar:setTitle() or hs.menubar:setIcon() after creating a menubar item, otherwise it will be invisible.
static int menubar_new(lua_State *L) {
    NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
    NSStatusItem *statusItem = [statusBar statusItemWithLength:NSVariableStatusItemLength];

    if (statusItem) {
        menubaritem_t *menuBarItem = lua_newuserdata(L, sizeof(menubaritem_t));
        memset(menuBarItem, 0, sizeof(menubaritem_t));
        menuBarItem->menuBarItemObject = (__bridge_retained void*)statusItem;
        menuBarItem->click_callback = nil;
        menuBarItem->click_fn = 0;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.menubar:setTitle(title)
/// Method
/// Sets the text on a menubar item. If an icon is also set, this text will be displayed next to the icon
static int menubar_settitle(lua_State *L) {
    menubaritem_t *menuBarItem = luaL_checkudata(L, 1, USERDATA_TAG);
    NSString *titleText = [NSString stringWithUTF8String:luaL_checkstring(L, 2)];
    lua_settop(L, 1);
    [(__bridge NSStatusItem*)menuBarItem->menuBarItemObject setTitle:titleText];

    return 0;
}

/// hs.menubar:setIcon(iconfilepath) -> bool
/// Method
/// Loads the image specified by iconfilepath and sets it as the menu bar item's icon
// FIXME: Talk about icon requirements, wrt size/colour and general suitability for retina and yosemite dark mode
static int menubar_seticon(lua_State *L) {
    menubaritem_t *menuBarItem = luaL_checkudata(L, 1, USERDATA_TAG);
    NSImage *iconImage = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithUTF8String:luaL_checkstring(L, 2)]];
    lua_settop(L, 1);
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
/// Sets the tooltip text on a menubar item.
static int menubar_settooltip(lua_State *L) {
    menubaritem_t *menuBarItem = luaL_checkudata(L, 1, USERDATA_TAG);
    NSString *toolTipText = [NSString stringWithUTF8String:luaL_checkstring(L, 2)];
    lua_settop(L, 1);
    [(__bridge NSStatusItem*)menuBarItem->menuBarItemObject setToolTip:toolTipText];

    return 0;
}

/// hs.menubar:clickCallback(fn)
/// Method
/// Registers a function to be called when the menubar icon is clicked. If the argument is nil, the previously registered callback is removed.
/// Note: If a menu has been attached to the menubar item, this callback will never be called
static int menubar_click_callback(lua_State *L) {
    menubaritem_t *menuBarItem = luaL_checkudata(L, 1, USERDATA_TAG);
    NSStatusItem *statusItem = (__bridge NSStatusItem*)menuBarItem->menuBarItemObject;
    if (lua_isnil(L, 2)) {
        if (menuBarItem->click_fn) {
            luaL_unref(L, LUA_REGISTRYINDEX, menuBarItem->click_fn);
            menuBarItem->click_fn = 0;
        }
        if (menuBarItem->click_callback) {
            [statusItem setTarget:nil];
            [statusItem setAction:nil];
            clickDelegate *object = (__bridge_transfer clickDelegate *)menuBarItem->click_callback;
            menuBarItem->click_callback = nil;
            object = nil;
        }
    } else {
        luaL_checktype(L, 2, LUA_TFUNCTION);
        lua_pushvalue(L, 2);
        menuBarItem->click_fn = luaL_ref(L, LUA_REGISTRYINDEX);
        clickDelegate *object = [[clickDelegate alloc] init];
        object.L = L;
        object.fn = menuBarItem->click_fn;
        menuBarItem->click_callback = (__bridge_retained void*) object;
        [statusItem setTarget:object];
        [statusItem setAction:@selector(click:)];
    }
    return 0;
}

/// hs.menubar:addMenu(items)
/// Method
/// Adds a menu to the menubar item with the supplied items in it, in the form:
///  { ["name"] = fn }
static int menubar_add_menu(lua_State *L) {
    menubaritem_t *menuBarItem = luaL_checkudata(L, 1, USERDATA_TAG);
    NSStatusItem *statusItem = (__bridge NSStatusItem*)menuBarItem->menuBarItemObject;
    luaL_checktype(L, 2, LUA_TTABLE);

    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"HammerspoonMenuItemMenu"];
    [menu setAutoenablesItems:NO];

    lua_pushnil(L); // Push a nil to the top of the stack, which lua_next() will interpret as "fetch the first item of the table"
    while (lua_next(L, 2) != 0) {
        // lua_next pushed two things onto the stack, the table item's key at -2 and its value at -1

        // Check that the value is a table
        if (lua_type(L, -1) != LUA_TTABLE) {
            NSLog(@"Error: table entry is not a menu item table");

            // Pop the value off the stack, leaving the key at the top
            lua_pop(L, 1);
            // Bail to the next lua_next() call
            continue;
        }

        // Inspect the menu item table at the top of the stack, fetch the value for the key "title" and push the result to the top of the stack
        lua_getfield(L, -1, "title");
        if (!lua_isstring(L, -1)) {
            NSLog(@"Error: malformed menu table entry");
            // We need to pop two things off the stack - the result of lua_getfield and the table it inspected
            lua_pop(L, 2);
            // Bail to the next lua_next() call
            continue;
        }

        // We have found the title of a menu bar item. Turn it into an NSString and pop it off the stack
        NSString *title = [NSString stringWithUTF8String:lua_tostring(L, -1)];
        lua_pop(L, 1);

        if ([title isEqualToString:@"-"]) {
            [menu addItem:[NSMenuItem separatorItem]];
        } else {
            NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];

            // Inspect the menu item table at the top of the stack, fetch the value for the key "fn" and push the result to the top of the stack
            lua_getfield(L, -1, "fn");
            if (lua_isfunction(L, -1)) {
                clickDelegate *delegate = [[clickDelegate alloc] init];

                // luaL_ref is going to store a reference to the item at the top of the stack and then pop it off. To avoid confusion, we're going to push the top item on top of itself, so luaL_ref leaves us where we are now
                lua_pushvalue(L, -1);
                delegate.fn = luaL_ref(L, LUA_REGISTRYINDEX);
                delegate.L = L;
                [menuItem setTarget:delegate];
                [menuItem setAction:@selector(click:)];
                [menuItem setRepresentedObject:delegate];
                [menuItem setEnabled:YES];
            }
            // Pop the result of lua_getfield off the stack
            lua_pop(L, 1);
            [menu addItem:menuItem];
        }
        // Pop the menu item table off the stack, leaving its key at the top, for lua_next()
        lua_pop(L, 1);
    }

    if ([menu numberOfItems] > 0) {
        [statusItem setMenu:menu];
    } else {
    }

    return 0;
}

/// hs.menubar:removeMenu()
/// Method
/// Removes the menu previously associated with a menubar item
static int menubar_remove_menu(lua_State *L) {
    menubaritem_t *menuBarItem = luaL_checkudata(L, 1, USERDATA_TAG);
    NSStatusItem *statusItem = (__bridge NSStatusItem*)menuBarItem->menuBarItemObject;
    NSMenu *menu = [statusItem menu];

    if (menu) {
        for (NSMenuItem *menuItem in [menu itemArray]) {
            clickDelegate *target = [menuItem representedObject];
            if (target) {
                luaL_unref(L, LUA_REGISTRYINDEX, target.fn);
                [menuItem setTarget:nil];
                [menuItem setAction:nil];
                [menuItem setRepresentedObject:nil];
                target = nil;
            }
        }
    }

    [statusItem setMenu:nil];

    return 0;
}

/// hs.menubar:delete(menubaritem)
/// Method
/// Removes the menubar item from the menubar and destroys it
static int menubar_delete(lua_State *L) {
    menubaritem_t *menuBarItem = luaL_checkudata(L, 1, USERDATA_TAG);

    NSStatusBar *statusBar = [NSStatusBar systemStatusBar];
    NSStatusItem *statusItem = (__bridge NSStatusItem*)menuBarItem->menuBarItemObject;

    // Remove any click callbackery the menubar item has
    lua_pushcfunction(L, menubar_click_callback);
    lua_pushvalue(L, 1);
    lua_pushnil(L);
    lua_call(L, 2, 0);

    // Remove a menu if the menubar item has one
    lua_pushcfunction(L, menubar_remove_menu);
    lua_pushvalue(L, 1);
    lua_call(L, 1, 0);

    [statusBar removeStatusItem:(__bridge NSStatusItem*)menuBarItem->menuBarItemObject];
    menuBarItem->menuBarItemObject = nil;
    menuBarItem = nil;

    return 0;
}

// ----------------------- Lua/hs glue GAR ---------------------

static int menubar_setup(lua_State* __unused L) {
    return 0;
}

static int meta_gc(lua_State* __unused L) {
    return 0;
}

static int menubar_gc(lua_State *L) {
    lua_pushcfunction(L, menubar_delete) ; lua_pushvalue(L, 1); lua_call(L, 1, 1);
    return 0;
}

static const luaL_Reg menubarlib[] = {
    {"new", menubar_new},

    {}
};

static const luaL_Reg menubar_metalib[] = {
    {"setTitle", menubar_settitle},
    {"setIcon", menubar_seticon},
    {"setTooltip", menubar_settooltip},
    {"clickCallback", menubar_click_callback},
    {"addMenu", menubar_add_menu},
    {"removeMenu", menubar_remove_menu},
    {"delete", menubar_delete},

    {"__gc", menubar_gc},
    {}
};

static const luaL_Reg meta_gclib[] = {
    {"__gc", meta_gc},

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
    luaL_newlib(L, meta_gclib);
    lua_setmetatable(L, -2);

    return 1;
}
