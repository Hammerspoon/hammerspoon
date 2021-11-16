@import Cocoa ;
@import Carbon ;
@import LuaSkin ;

// ----------------------- Definitions ---------------------

#define USERDATA_TAG "hs.menubar"
static LSRefTable refTable;
#define get_item_arg(L, idx) ((menubaritem_t *)luaL_checkudata(L, idx, USERDATA_TAG))

// Adds undocumented "appearance" argument to "popUpMenuPositioningItem":
@interface NSMenu (MISSINGOrder)
- (BOOL)popUpMenuPositioningItem:(id)arg1 atLocation:(struct CGPoint)arg2 inView:(id)arg3 appearance:(id)arg4;
@end

// modified from https://github.com/shergin/NSStatusBar-MISSINGOrder

typedef NS_ENUM(NSInteger, NSStatusBarItemPriority) {
    NSStatusBarItemPriorityDefault = 1000,
    NSStatusBarItemPrioritySystem = 2147483645,
    NSStatusBarItemPrioritySpotlight = 2147483646,
    NSStatusBarItemPriorityNotificationCenter = 2147483647,
};

@interface NSStatusBar (MISSINGOrder)
- (NSStatusItem *)statusItemWithLength:(CGFloat)length withPriority:(NSStatusBarItemPriority)priority;
- (void)insertStatusItem:(NSStatusItem *)statusItem withPriority:(NSStatusBarItemPriority)priority;
@end

@implementation NSStatusBar (MISSINGOrder)
- (void)insertStatusItem:(NSStatusItem *)statusItem withPriority:(NSStatusBarItemPriority)priority {
    SEL insertStatusItemWithPrioritySelector = NSSelectorFromString(@"_insertStatusItem:withPriority:");
    if ([self respondsToSelector:insertStatusItemWithPrioritySelector]) {
        if (statusItem) {
            [self removeStatusItem:statusItem];
            // Perform `[self _insertStatusItem:statusItem withPriority:priority]`.
            NSMethodSignature *signature  = [[self class] instanceMethodSignatureForSelector:insertStatusItemWithPrioritySelector];
            NSInvocation *invocation      = [NSInvocation invocationWithMethodSignature:signature];
            [invocation setTarget:self];
            [invocation setSelector:insertStatusItemWithPrioritySelector];
            [invocation setArgument:(void *)&statusItem atIndex:2];
            [invocation setArgument:&priority atIndex:3];
            [invocation invoke];
        }
    } else {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:_insertStatusItem:withPriority: unavailable in this version of OS X", USERDATA_TAG]] ;
    }
}

- (NSStatusItem *)statusItemWithLength:(CGFloat)length withPriority:(NSStatusBarItemPriority)priority {
    SEL statusItemWithLengthWithPrioritySelector = NSSelectorFromString(@"_statusItemWithLength:withPriority:");
    NSStatusItem *statusItem;
    if ([self respondsToSelector:statusItemWithLengthWithPrioritySelector]) {
        // Perform `[self _statusItemWithLength:length withPriority:priority]`.
        void *tempResultValuePtr;
        NSMethodSignature *signature  = [[self class] instanceMethodSignatureForSelector:statusItemWithLengthWithPrioritySelector];
        NSInvocation      *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:self];
        [invocation setSelector:statusItemWithLengthWithPrioritySelector];
        [invocation setArgument:&length atIndex:2];
        [invocation setArgument:&priority atIndex:3];
        [invocation invoke];
        [invocation getReturnValue:&tempResultValuePtr];
        statusItem = (__bridge NSStatusItem *)tempResultValuePtr;

        [self insertStatusItem:statusItem withPriority:priority] ;
    } else {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:_statusItemWithLength:withPriority: unavailable in this version of OS X", USERDATA_TAG]] ;
    }

    if (!statusItem) {
        statusItem = [self statusItemWithLength:length];
    }

    return statusItem;
}

@end

@interface NSStatusItem (MISSINGOrder)
- (NSInteger)priority ;
@end

@implementation NSStatusItem (MISSINGOrder)
-(NSInteger)priority {
    NSInteger result = 0 ;
    SEL prioritySelector = NSSelectorFromString(@"_priority");
    if ([self respondsToSelector:prioritySelector]) {
        NSMethodSignature *signature  = [[self class] instanceMethodSignatureForSelector:prioritySelector] ;
        NSInvocation      *invocation = [NSInvocation invocationWithMethodSignature:signature] ;
        [invocation setTarget:self] ;
        [invocation setSelector:prioritySelector] ;
        [invocation invoke] ;
        [invocation getReturnValue:&result] ;
    }else {
        [LuaSkin logWarn:[NSString stringWithFormat:@"%s:_priority unavailable in this version of OS X", USERDATA_TAG]] ;
    }
    return result ;
}

@end
// Define a base object for our various callback handlers
@interface HSMenubarCallbackObject : NSObject
@property lua_State *L;
@property int fn;
@property int item;

- (void)callback_runner;
@end
@implementation HSMenubarCallbackObject
// Generic callback runner that will execute a Lua function stored in self.fn
- (void) callback_runner {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    lua_State *L = skin.L;

    BOOL fn_result;
    NSEvent *event = [NSApp currentEvent];

    [skin pushLuaRef:refTable ref:self.fn];

    if (event != nil) {
        NSUInteger theFlags = [event modifierFlags];
        BOOL isCommandKey = (theFlags & NSEventModifierFlagCommand) != 0;
        BOOL isShiftKey = (theFlags & NSEventModifierFlagShift) != 0;
        BOOL isOptKey = (theFlags & NSEventModifierFlagOption) != 0;
        BOOL isCtrlKey = (theFlags & NSEventModifierFlagControl) != 0;
        BOOL isFnKey = (theFlags & NSEventModifierFlagFunction) != 0;

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

        [skin pushLuaRef:refTable ref:self.item];

        fn_result = [skin protectedCallAndTraceback:2 nresults:1];
    } else {
        // event is very unlikely to be nil, but we'll handle it just in case
        fn_result = [skin protectedCallAndTraceback:0 nresults:1];
    }

    if (!fn_result) {
        const char *errorMsg = lua_tostring(L, -1);
        [skin logError:[NSString stringWithFormat:@"hs.menubar:setClickCallback() callback error: %s", errorMsg]];
        return;
    }

    // There are no lua_pop()s on errors here, they are handled by the functions that call this one
}

@end

// Define some basic helper functions
void parse_table(lua_State *L, int idx, NSMenu *menu, NSSize stateBoxImageSize);
void erase_menu_items(lua_State *L, NSMenu *menu);

// Define a datatype for hs.menubar meta-objects
typedef struct _menubaritem_t {
    void   *menuBarItemObject;
    void   *click_callback;
    int    click_fn;
    BOOL   removed ;
    NSSize stateBoxImageSize ;
} menubaritem_t;

// Define an array to track delegates for dynamic menu objects
static NSMutableArray *dynamicMenuDelegates;

// Define an object for delegate objects to handle clicks on menubar items that have no menu, but wish to act on clicks
@interface HSMenubarItemClickDelegate : HSMenubarCallbackObject
@end
@implementation HSMenubarItemClickDelegate
- (void) click:(id)sender {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    _lua_stackguard_entry(skin.L);
    // Issue #909 -- if the callback causes the menu to be replaced, we crash if this delegate disappears from beneath us... this keeps it from being collected before the callback is done.
    NSObject *myDelegate = sender ? [(NSMenuItem *)sender representedObject] : nil ;
    [self callback_runner];
    // error or return value (ignored in this case), we gotta cleanup
    lua_pop(skin.L, 1) ;
    _lua_stackguard_exit(skin.L);
    myDelegate = nil ; // NOTE: DO NOT USE `self` AFTER THIS POINT, IT WILL HAVE BEEN DEALLOCATED.
}
@end

// Define an object for dynamic menu objects
@interface HSMenubarItemMenuDelegate : HSMenubarCallbackObject <NSMenuDelegate>
@property NSSize stateBoxImageSize ;
@end
@implementation HSMenubarItemMenuDelegate
- (void) menuNeedsUpdate:(NSMenu *)menu {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    _lua_stackguard_entry(skin.L);
    [self callback_runner];

    // Ensure the callback pushed a table onto the stack, then remove any existing menu structure and parse the table into a new menu
    if (lua_type(skin.L, lua_gettop(skin.L)) == LUA_TTABLE) {
        erase_menu_items(skin.L, menu);
        parse_table(skin.L, lua_gettop(skin.L), menu, self.stateBoxImageSize);
    } else {
        [skin logError:@"hs.menubar:setMenu() callback must return a valid table"];
    }
    // error or return value, we gotta cleanup
    lua_pop(skin.L, 1) ;
    _lua_stackguard_exit(skin.L);
}
@end

// ----------------------- Helper functions ---------------------

// I'm not sure how this is going to work on  Retina display, so leave it as a function so we can
// modify it more easily and affect all (3) places where it is used...
static NSSize proportionallyScaleStateImageSize(NSImage *theImage, NSSize stateBoxImageSize) {
    NSSize sourceSize = [theImage size] ;
    CGFloat ratio = fmin(stateBoxImageSize.height / sourceSize.height, stateBoxImageSize.width / sourceSize.width) ;
    return NSMakeSize(sourceSize.width * ratio, sourceSize.height * ratio) ;
}

// Helper function to parse a Lua table and turn it into an NSMenu hierarchy (is recursive, so may do terrible things on huge tables)
void parse_table(lua_State *L, int idx, NSMenu *menu, NSSize stateBoxImageSize) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    lua_pushnil(L); // Push a nil to the top of the stack, which lua_next() will interpret as "fetch the first item of the table"
    while (lua_next(L, idx) != 0) {
        // lua_next pushed two things onto the stack, the table item's key at -2 and its value at -1

        // Check that the value is a table
        if (lua_type(L, -1) != LUA_TTABLE) {
            [skin logBreadcrumb:[NSString stringWithFormat:@"Error: table entry is not a menu item table: %s", lua_typename(L, lua_type(L, -1))]];

            // Pop the value off the stack, leaving the key at the top
            lua_pop(L, 1);
            // Bail to the next lua_next() call
            continue;
        }

// MARK: title key
        // Inspect the menu item table at the top of the stack, fetch the value for the key "title" and push the result to the top of the stack
        int titleType = lua_getfield(L, -1, "title");

        if (!lua_isstring(L, -1) && !luaL_testudata(L, -1, "hs.styledtext")) {
            // We can't proceed without the title, we'd have nothing to display in the menu, so let's just give up and move on
            [skin logBreadcrumb:[NSString stringWithFormat:@"Error: malformed menu table entry. Instead of a title string, we found: %s", lua_typename(L, lua_type(L, -1))]];
            // We need to pop two things off the stack - the result of lua_getfield and the table it inspected
            lua_pop(L, 2);
            // Bail to the next lua_next() call
            continue;
        }

        NSAttributedString *aTitle = [skin luaObjectAtIndex:-1 toClass:"NSAttributedString"] ;
        NSString           *title  = [aTitle string] ;

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
            // if title was just a string, don't bother setting attributed version to keep menu
            // default font, etc.
            if (titleType != LUA_TSTRING) [menuItem setAttributedTitle:aTitle] ;

// MARK: menu key
            // Check to see if we have a submenu, if so, recurse into it
            lua_getfield(L, -1, "menu");
            if (lua_istable(L, -1)) {
                // Create the submenu, populate it and attach it to our current menu item
                NSMenu *subMenu = [[NSMenu alloc] initWithTitle:@"HammerspoonSubMenu"];
                [subMenu setAutoenablesItems:NO];
                // We're about to recurse into ourselves. Each recursion to this point adds 3 items to the Lua stack, which defaults to 20 slots. Therefore at an 8th recursion we'll overflow the Lua stack. Since its theoretical limit is very high (typically 4096) we can make the risky assumption that nobody would recurse a menu over 200 times, and just grow the stack as we go.
                if (lua_checkstack(L, 20)) {
                    parse_table(L, lua_gettop(L), subMenu, stateBoxImageSize);
                    [menuItem setSubmenu:subMenu];
                } else {
                    [skin logError:@"hs.menubar menu recursion depth exceeded."];
                }
            }
            lua_pop(L, 1);

// MARK: fn key
            // Inspect the menu item table at the top of the stack, fetch the value for the key "fn" and push the result to the top of the stack
            lua_getfield(L, -1, "fn");
            if (lua_isfunction(L, -1)) {
                // Create the delegate object that will service clicks on this menu item
                HSMenubarItemClickDelegate *delegate = [[HSMenubarItemClickDelegate alloc] init];

                // luaL_ref is going to create a reference to the item at the top of the stack and then pop it off. To avoid confusion, we're going to push the top item on top of itself, so luaL_ref leaves us where we are now
                lua_pushvalue(L, -1);
                delegate.fn = [skin luaRef:refTable];
                delegate.L = L;
                delegate.item = [skin luaRef:refTable atIndex:-2];
                [menuItem setTarget:delegate];
                [menuItem setAction:@selector(click:)];
                [menuItem setRepresentedObject:delegate]; // representedObject is a strong reference, so we don't need to retain the delegate ourselves
            }
            // Pop the result of fetching "fn", off the stack
            lua_pop(L, 1);

// MARK: disabled key
            // Check if this item is enabled/disabled, defaulting to enabled
            lua_getfield(L, -1, "disabled");
            if (lua_isboolean(L, -1)) {
                [menuItem setEnabled:!lua_toboolean(L, -1)];
            } else {
                [menuItem setEnabled:YES];
            }
            lua_pop(L, 1);

// MARK: checked key
            // Check if this item is checked/unchecked, defaulting to unchecked
            lua_getfield(L, -1, "checked");
            if (lua_isboolean(L, -1)) {
                [menuItem setState:lua_toboolean(L, -1) ? NSOnState : NSOffState];
            } else {
                [menuItem setState:NSOffState];
            }
            lua_pop(L, 1);

// MARK: state key -- adds "mixed" state to checked
            lua_getfield(L, -1, "state");
            NSString *state = [skin toNSObjectAtIndex:-1] ;
            if ([state isKindOfClass:[NSString class]]) {
                if ([state isEqualToString:@"on"])    [menuItem setState:NSOnState] ;
                if ([state isEqualToString:@"off"])   [menuItem setState:NSOffState] ;
                if ([state isEqualToString:@"mixed"]) [menuItem setState:NSMixedState] ;
            }
            lua_pop(L, 1);

// MARK: tooltip key
            lua_getfield(L, -1, "tooltip");
            if (lua_isstring(L, -1)) {
                NSString *toolTip = [skin toNSObjectAtIndex:-1] ;
                [menuItem setToolTip:toolTip] ;
            }
            lua_pop(L, 1);

// MARK: indent key
            lua_getfield(L, -1, "indent");
            // will return zero if type is wrong, so we don't have to check return type
            NSInteger indentLevel = (NSInteger)lua_tointeger(L, -1) ;
            if (indentLevel < 0)  indentLevel = 0 ;
            if (indentLevel > 15) indentLevel = 15 ;
            [menuItem setIndentationLevel:indentLevel] ;
            lua_pop(L, 1);

// MARK: image keys
            lua_getfield(L, -1, "image") ;
            if (luaL_testudata(L, -1, "hs.image")) {
                NSImage *image = [skin luaObjectAtIndex:-1 toClass:"NSImage"] ;
                if (image) [menuItem setImage:[image copy]] ;
            }
            lua_pop(L, 1) ;

            lua_getfield(L, -1, "onStateImage") ;
            if (luaL_testudata(L, -1, "hs.image")) {
                NSImage *image = [skin luaObjectAtIndex:-1 toClass:"NSImage"] ;
                if (image) {
                    image = [image copy] ;
                    [image setSize:proportionallyScaleStateImageSize(image, stateBoxImageSize)] ;
                    [menuItem setOnStateImage:image] ;
                }
            }
            lua_pop(L, 1) ;

            lua_getfield(L, -1, "offStateImage") ;
            if (luaL_testudata(L, -1, "hs.image")) {
                NSImage *image = [skin luaObjectAtIndex:-1 toClass:"NSImage"] ;
                if (image) {
                    image = [image copy] ;
                    [image setSize:proportionallyScaleStateImageSize(image, stateBoxImageSize)] ;
                    [menuItem setOffStateImage:image] ;
                }
            }
            lua_pop(L, 1) ;

            lua_getfield(L, -1, "mixedStateImage") ;
            if (luaL_testudata(L, -1, "hs.image")) {
                NSImage *image = [skin luaObjectAtIndex:-1 toClass:"NSImage"] ;
                if (image) {
                    image = [image copy] ;
                    [image setSize:proportionallyScaleStateImageSize(image, stateBoxImageSize)] ;
                    [menuItem setMixedStateImage:image] ;
                }
            }
            lua_pop(L, 1) ;

// MARK: shortcut key
            lua_getfield(L, -1, "shortcut");
            if (lua_isstring(L, -1)) {
                NSString *shortcutKey = [skin toNSObjectAtIndex:-1];
                [menuItem setKeyEquivalent:shortcutKey];
                [menuItem setKeyEquivalentModifierMask:0];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    for (NSMenuItem *menuItem in [menu itemArray]) {
        HSMenubarItemClickDelegate *target = [menuItem representedObject];
        if (target) {
            // This menuitem has a delegate object. Destroy its Lua reference and nuke all the references to the object, so ARC will deallocate it
            target.fn = [skin luaUnref:refTable ref:target.fn];
            target.item = [skin luaUnref:refTable ref:target.item];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];

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
    NSStatusItem *statusItem ;
    if (lua_isboolean(L, 1) && !lua_toboolean(L, 1)) {
        statusItem = [[NSStatusItem alloc] init] ;
    } else {
        statusItem = [statusBar statusItemWithLength:NSVariableStatusItemLength];
    }

    if (statusItem) {
        menubaritem_t *menuBarItem = lua_newuserdata(L, sizeof(menubaritem_t));
        memset(menuBarItem, 0, sizeof(menubaritem_t));

        menuBarItem->menuBarItemObject = (__bridge_retained void*)statusItem;
        menuBarItem->click_callback = NULL;
        menuBarItem->click_fn = LUA_NOREF;
        menuBarItem->removed = NO ;

        CGFloat defaultFromFont        = [[NSFont menuFontOfSize:0] pointSize] ;
        menuBarItem->stateBoxImageSize = NSMakeSize(defaultFromFont, defaultFromFont) ;

        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);

        if (lua_isboolean(L, 1) && !lua_toboolean(L, 1)) {
              menuBarItem->removed = YES ;
        }
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.menubar.newWithPriority(priority) -> menubaritem or nil
/// Constructor
/// Creates a new menu bar item object with the specified priority
///
/// Parameters:
///  * priority - an integer specifying the menubar item's priority.  A menubar item's position is determined by its priority value.
///
/// Returns:
///  * menubar item object to use with other API methods, or nil if it could not be created
///
/// Notes:
///  * Default priority levels can be found in the [hs.menubar.priorities](#priorities) table.
///
///  * This constructor uses undocumented methods in the NSStatusBar and NSStatusItem classes; because of this, we cannot guarantee that it will work with future versions of OS X.  This constructor has been written so that if the necessary private methods are not present, then a warning will be sent to the Hammerspoon console and the menubar item will be created in its default position -- the equivalent of using the [hs.menubar.new](#new) constructor instead of this one.
static int menubarNewWithPriority(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TNUMBER | LS_TINTEGER,
                    LS_TBREAK] ;

    NSStatusBarItemPriority priority    = lua_tointeger(L, 1);
    NSStatusBar             *statusBar  = [NSStatusBar systemStatusBar];
    NSStatusItem            *statusItem = [statusBar statusItemWithLength:NSVariableStatusItemLength
                                                             withPriority:priority];

    if (statusItem) {
        menubaritem_t *menuBarItem = lua_newuserdata(L, sizeof(menubaritem_t));
        memset(menuBarItem, 0, sizeof(menubaritem_t));

        menuBarItem->menuBarItemObject = (__bridge_retained void*)statusItem;
        menuBarItem->click_callback = NULL;
        menuBarItem->click_fn = LUA_NOREF;
        menuBarItem->removed = NO ;

        CGFloat defaultFromFont        = [[NSFont menuFontOfSize:0] pointSize] ;
        menuBarItem->stateBoxImageSize = NSMakeSize(defaultFromFont, defaultFromFont) ;

        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
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
///  * `title` - A string or `hs.styledtext` object to use as the title, or nil to remove the title
///
/// Returns:
///  * the menubar item
///
/// Notes:
///  * If you set an icon as well as a title, they will both be displayed next to each other
///  * Has no affect on the display of a pop-up menu, but changes will be be in effect if hs.menubar:returnToMenuBar() is called on the menubaritem.
static int menubarSetTitle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TANY | LS_TOPTIONAL, LS_TBREAK];
    menubaritem_t *menuBarItem = get_item_arg(L, 1);

    NSString           *titleText = nil;
    NSAttributedString *titleAText = nil;

    if ((lua_type(L, 2) == LUA_TSTRING) || (lua_type(L, 2) == LUA_TNUMBER)) {
        luaL_checkstring(L, 2) ;
        titleText  = [skin toNSObjectAtIndex:2] ;
    } else if (luaL_testudata(L, 2, "hs.styledtext") || (lua_type(L, 2) == LUA_TTABLE)) {
        titleAText = [skin luaObjectAtIndex:2 toClass:"NSAttributedString"] ;
    } else if (!lua_isnoneornil(L, 2)) {
        return luaL_error(L, "expected string, styled-text object, or nil") ;
    }

    if (!titleText && !titleAText) [(__bridge NSStatusItem*)menuBarItem->menuBarItemObject setTitle:nil] ;
//     [(__bridge NSStatusItem*)menuBarItem->menuBarItemObject setTitle:nil];
//     [(__bridge NSStatusItem*)menuBarItem->menuBarItemObject setAttributedTitle:nil];
    if (titleText) [(__bridge NSStatusItem*)menuBarItem->menuBarItemObject setTitle:titleText];
    if (titleAText) [(__bridge NSStatusItem*)menuBarItem->menuBarItemObject setAttributedTitle:titleAText];

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.menubar:setIcon(imageData[, template]) -> menubaritem or nil
/// Method
/// Sets the image of a menubar item object. The image will be displayed in the system menubar
///
/// Parameters:
///  * imageData - This can one of the following:
///   * An `hs.image` object
///   * A string containing a path to an image file
///   * A string beginning with `ASCII:` which signifies that the rest of the string is interpreted as a special form of ASCII diagram, which will be rendered to an image and used as the icon. See the notes below for information about the special format of ASCII diagram.
///   * nil, indicating that the current image is to be removed
///  * template - An optional boolean value which defaults to true. If it's true, the provided image will be treated as a "template" image, which allows it to automatically support OS X 10.10's Dark Mode. If it's false, the image will be used as is, supporting colour.
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
///  * Icons should be small, transparent images that roughly match the size of normal menubar icons, otherwise they will look very strange. Note that if you're using an `hs.image` image object as the icon, you can force it to be resized with `hs.image:setSize({w=16,h=16})`
///  * Retina scaling is supported if the image is either scalable (e.g. a PDF produced by Adobe Illustrator) or contain multiple sizes (e.g. a TIFF with small and large images). Images will not automatically do the right thing if you have a @2x version present
///  * Icons are by default specified as "templates", which allows them to automatically support OS X 10.10's Dark Mode, but this also means they cannot be complicated, colour images.
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
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        iconImage = [skin luaObjectAtIndex:2 toClass:"NSImage"] ;

        if (!iconImage) {
            lua_pushnil(L);
            return 1;
        }
        if (lua_isboolean(L, 3) && !lua_toboolean(L, 3)) {
            [iconImage setTemplate:NO];
        } else {
            [iconImage setTemplate:YES];
        }
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK];
    menubaritem_t *menuBarItem = get_item_arg(L, 1);
    NSString *toolTipText = [skin toNSObjectAtIndex:2];
    lua_settop(L, 1); // FIXME: This seems unnecessary?
    [(__bridge NSStatusItem*)menuBarItem->menuBarItemObject setToolTip:toolTipText];

    lua_settop(L, 1) ;
    return 1 ;
}

/// hs.menubar:setClickCallback([fn]) -> menubaritem
/// Method
/// Registers a function to be called when the menubar item is clicked
///
/// Parameters:
///  * `fn` - An optional function to be called when the menubar item is clicked. If this argument is not provided, any existing function will be removed. The function can optionally accept a single argument, which will be a table containing boolean values indicating which keyboard modifiers were held down when the menubar item was clicked; The possible keys are:
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION|LS_TNIL|LS_TOPTIONAL, LS_TBREAK];

    menubaritem_t *menuBarItem = get_item_arg(L, 1);
    NSStatusItem *statusItem = (__bridge NSStatusItem*)menuBarItem->menuBarItemObject;

    // Remove any existing click callback
    menuBarItem->click_fn = [skin luaUnref:refTable ref:menuBarItem->click_fn];
    if (menuBarItem->click_callback) {
        [statusItem setTarget:nil];
        [statusItem setAction:nil];
        HSMenubarItemClickDelegate *object = (__bridge_transfer HSMenubarItemClickDelegate *)menuBarItem->click_callback;
        menuBarItem->click_callback = NULL;
        object = nil;
    }

    if (lua_isfunction(L, 2)) {
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
///  * The available keys for each menu item are (note that `title` is the only required key -- all other keys are optional):
///      * `title`           - A string or `hs.styledtext` object to be displayed in the menu. If this is the special string `"-"` the item will be rendered as a menu separator.  This key can be set to the empty string (""), but it must be present.
///      * `fn`              - A function to be executed when the menu item is clicked
///         * The function will be called with two arguments. The first argument will be a table containing boolean values indicating which keyboard modifiers were held down when the menubar item was clicked (see `menuTable` parameter for possible keys) and the second is the table representing the item.
///      * `checked`         - A boolean to indicate if the menu item should have a checkmark (by default) next to it or not. Defaults to false.
///      * `state`           - a text value of "on", "off", or "mixed" indicating the menu item state.  "on" and "off" are equivalent to `checked` being true or false respectively, and "mixed" will have a dash (by default) beside it.
///      * `disabled`        - A boolean to indicate if the menu item should be unselectable or not. Defaults to false (i.e. menu items are selectable by default)
///      * `menu`            - a table, in the same format as above, which will be presented as a sub-menu for this menu item.
///         * a menu item that is disabled and has a sub-menu will show the arrow at the right indicating that it has a sub-menu, but the items within the sub-menu will not be available, even if the sub-menu items are not disabled themselves.
///         * a menu item with a sub-menu is also a clickable target, so it can also have an `fn` key.
///      * `image`           - An image to display in the menu to the right of any state image or checkmark and to the left of the menu item title.  This image is not constrained by the size set with [hs.menubar:stateImageSize](#stateImageSize), so you should adjust it with `hs.image:setSize` if your image is extremely large or small.
///      * `tooltip`         - A tool tip to display if you hover the cursor over a menu item for a few seconds.
///      * `shortcut`        - A string containing a single character, which will be used as the keyboard shortcut for the menu item. Note that if you use a capital letter, the Shift key will be required to activate the shortcut.
///      * `indent`          - An integer from 0 to 15 indicating how far to the right a menu item should be indented.  Defaults to 0.
///      * `onStateImage`    - An image to display when `checked` is true or `state` is set to "on".  This image size is constrained to the size set by [hs.menubar:stateImageSize](#stateImageSize).  If this key is not set, a checkmark will be displayed for checked or "on" menu items.
///      * `offStateImage`   - An image to display when `checked` is false or `state` is set to "off".  This image size is constrained to the size set by [hs.menubar:stateImageSize](#stateImageSize).  If this key is not set, no special marking appears next to the menu item.
///      * `mixedStateImage` - An image to display when `state` is set to "mixed".  This image size is constrained to the size set by [hs.menubar:stateImageSize](#stateImageSize).  If this key is not set, a dash will be displayed for menu items with a state of "mixed".
///
/// Returns:
///  * the menubaritem
///
/// Notes:
///  * If you are using the callback function, you should take care not to take too long to generate the menu, as you will block the process and the OS may decide to remove the menubar item
static int menubarSetMenu(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

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
                parse_table(L, 2, menu, menuBarItem->stateBoxImageSize);

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
                delegate.stateBoxImageSize = menuBarItem->stateBoxImageSize ;

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
        menuBarItem->removed = YES;
    }

    menuBarItem->menuBarItemObject = NULL;
    menuBarItem = nil;

    return 0;
}

/// hs.menubar:popupMenu(point[, darkMode]) -> menubaritem
/// Method
/// Display a menubaritem as a pop up menu at the specified screen point.
///
/// Parameters:
///  * point - the location of the upper left corner of the pop-up menu to be displayed.
///  * darkMode - (optional) `true` to force the menubar dark (defaults to your macOS General Appearance settings)
///
/// Returns:
///  * The menubaritem
///
/// Notes:
///  * Items which trigger hs.menubar:setClickCallback() will invoke the callback function, but we cannot control the positioning of any visual elements the function may create -- calling this method on such an object is the equivalent of invoking its callback function directly.
///  * This method is blocking. Hammerspoon will be unable to respond to any other activity while the pop-up menu is being displayed.
///  * `darkMode` uses an undocumented macOS API call, so may break in a future release.
static int menubar_render(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    menubaritem_t *menuBarItem = get_item_arg(L, 1);
    NSStatusItem  *statusItem  = (__bridge NSStatusItem*)menuBarItem->menuBarItemObject;
    NSMenu        *menu        = [statusItem menu];

    NSPoint menuPoint ;

	// Support darkMode for popup menus:
	BOOL darkMode = false ;
    if (lua_gettop(L) > 2) {
        if ((lua_type(L, 3) == LUA_TBOOLEAN) || (lua_type(L, 3) == LUA_TNIL)) {
            if (lua_type(L, 3) == LUA_TBOOLEAN) {
                darkMode = (BOOL)lua_toboolean(L, 3) ;
            } else {
                NSString *ifStyle = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"] ;
                darkMode = (ifStyle && [ifStyle isEqualToString:@"Dark"]) ;
            }
            lua_remove(L, 3) ;
        }
    }
    NSAppearance *appearance = [NSAppearance appearanceNamed:(darkMode ? NSAppearanceNameVibrantDark : NSAppearanceNameVibrantLight)] ;

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
            [skin logError:@"hs.menubar:popupMenu() argument must be a valid hs.geometry.point table"];
            lua_pushnil(L) ;
            return 1 ;
    }

    if (!menu) {

        if (menuBarItem->click_callback)
            [((__bridge HSMenubarItemClickDelegate *)menuBarItem->click_callback) click:NULL] ;
        else {
            [skin logWarn:@"hs.menubar:popupMenu() Missing menu object"] ;

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

    [menu popUpMenuPositioningItem:nil atLocation:menuPoint inView:nil appearance:appearance ] ;

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
        NSStatusItem  *oldStatusItem  = (__bridge_transfer NSStatusItem*)menuBarItem->menuBarItemObject;
        NSStatusItem  *newStatusItem = [[NSStatusItem alloc] init] ;

        menuBarItem->menuBarItemObject = (__bridge_retained void*)newStatusItem;
        [newStatusItem  setTarget:[oldStatusItem target]] ;
        [newStatusItem  setAction:[oldStatusItem action]] ;
        [newStatusItem    setMenu:[oldStatusItem menu]] ;
        [newStatusItem   setTitle:[oldStatusItem title]] ;
        [newStatusItem   setImage:[oldStatusItem image]] ;
        [newStatusItem setToolTip:[oldStatusItem toolTip]] ;

        [statusBar removeStatusItem:oldStatusItem];
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

/// hs.menubar:isInMenuBar() -> boolean
/// Method
/// Returns a boolean indicating whether or not the specified menu is currently in the OS X menubar.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean indicating whether or not the specified menu is currently in the OS X menubar
static int menubar_isInMenubar(lua_State *L) {
    menubaritem_t *menuBarItem     = get_item_arg(L, 1);
    lua_pushboolean(L, !(menuBarItem->removed)) ;
    return 1;
}

/// hs.menubar:title([styled]) -> string | styledtextObject
/// Method
/// Returns the current title of the menubar item object.
///
/// Parameters:
///  * styled - an optional boolean, defaulting to false, indicating that a styledtextObject representing the text of the menu title should be returned
///
/// Returns:
///  * the menubar item title, or an empty string, if there isn't one.  If `styled` is not set or is false, then a string is returned; otherwise a styledtextObject will be returned.
static int menubarGetTitle(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    menubaritem_t *menuBarItem     = get_item_arg(L, 1);

    if ((lua_gettop(L) == 2) && lua_toboolean(L, 2)) {
        [skin pushNSObject:[(__bridge NSStatusItem*)menuBarItem->menuBarItemObject attributedTitle]] ;
    } else {
        [skin pushNSObject:[(__bridge NSStatusItem*)menuBarItem->menuBarItemObject title]] ;
    }
    return 1 ;
}

/// hs.menubar:priority([priority]) -> menubaritem | current-value
/// Method
/// Get or set a menubar item's priority
///
/// Parameters:
///  * priority - an optional integer specifying the menubar item's priority.  A menubar item's position is determined by its priority value.
///
/// Returns:
///  * if a priority is provided, then the menubaritem object is returned; otherwise the current priority value is returned.
///
/// Notes:
///  * Default priority levels can be found in the [hs.menubar.priorities](#priorities) table.
///
///  * This method uses undocumented methods in the NSStatusBar and NSStatusItem classes, which appear to have been removed in macOS 10.15 (Catalina), so this method will no longer work correctly.
static int menubarPriority(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG,
                    LS_TNUMBER | LS_TINTEGER | LS_TOPTIONAL,
                    LS_TBREAK] ;
    menubaritem_t *menuBarItem     = get_item_arg(L, 1);

    if (lua_gettop(L) == 2) {
        NSStatusBar   *statusBar       = [NSStatusBar systemStatusBar];
        [statusBar insertStatusItem:(__bridge NSStatusItem*)menuBarItem->menuBarItemObject
                       withPriority:lua_tointeger(L, 2)] ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushinteger(L, [(__bridge NSStatusItem*)menuBarItem->menuBarItemObject priority]) ;
    }
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

    if (theImage) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        [skin pushNSObject:theImage];
    } else {
        lua_pushnil(L) ;
    }

    return 1 ;
}

static int menubarFrame(lua_State *L) {
    menubaritem_t *menuBarItem = get_item_arg(L, 1);
    NSStatusItem *statusItem = (__bridge NSStatusItem*)menuBarItem->menuBarItemObject;
    NSWindow *statusBarWindow = [statusItem valueForKey:@"window"] ;
    if (statusBarWindow && [statusBarWindow isKindOfClass:[NSWindow class]]) {
        NSRect frame = [statusBarWindow frame];
        geom_pushrect(L, frame);
    } else {
        lua_pushnil(L) ;
    }
    return 1;
}

/// hs.menubar:stateImageSize([size]) -> hs.image object | current value
/// Method
/// Get or set the size for state images when the menu is displayed.
///
/// Parameters:
///  * size - an optional table specifying the size for state images displayed when using the `checked` or `state` key in a menu table definition.  Defaults to a size determined by the system menu font point size.  If you specify an explicit nil, the size is reset to this default.
///
/// Returns:
///  * if a parameter is provided, returns the menubar item; otherwise returns the current value.
///
/// Notes:
///  * An image is used rather than a checkmark or dash only when you set them with the `onStateImage`, `offStateImage`, or `mixedStateImage` keys.  If you are not using these keys, then this method will have no visible effect on the menu's rendering.  See  [hs.menubar:setMenu](#setMenu) for more information.
///  * If you are setting the menu contents with a static table, you should invoke this method before invoking [hs.menubar:setMenu](#setMenu), as changes will only go into effect when the table is next converted to a menu structure.
static int menubarStateImageSize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    menubaritem_t *menuBarItem = get_item_arg(L, 1);
    NSStatusItem *statusItem = (__bridge NSStatusItem*)menuBarItem->menuBarItemObject;
    if (lua_gettop(L) == 1) {
        [skin pushNSSize:menuBarItem->stateBoxImageSize] ;
    } else {
        NSSize newSize ;
        if (lua_type(L, 2) == LUA_TTABLE) {
            newSize = [skin tableToSizeAtIndex:2] ;
        } else {
            CGFloat defaultFromFont = [[NSFont menuFontOfSize:0] pointSize] ;
            newSize = NSMakeSize(defaultFromFont, defaultFromFont) ;
        }
        menuBarItem->stateBoxImageSize = newSize ;
        if (statusItem.menu && [[statusItem.menu delegate] isKindOfClass:[HSMenubarItemMenuDelegate class]]) {
            HSMenubarItemMenuDelegate *theDelegate = [statusItem.menu delegate] ;
            theDelegate.stateBoxImageSize = newSize ;
        }
        lua_pushvalue(L, 1) ;
    }
    return 1 ;
}

// ----------------------- Lua/hs glue GAR ---------------------

/// hs.menubar.priorities[]
/// Constant
/// Pre-defined list of priority levels which can be used for positioning menubar items.
///
/// The constants defined are as follows:
///  * default            - the default priority -- to the left of existing menubar items
///  * system             - the default priority for Apple system menubar icons (Wifi, Bluetooth, etc.)
///  * spotlight          - the Spotlight menubar icon priority
///  * notificationCenter - the Notification Center icon priority
///
/// You are not limited to these priorities, but the behavior is undefined if you specify a priority less than 0 or greater than 2147483647 (the `notificationCenter` priority).
static int pushPrioritiesTable(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, NSStatusBarItemPriorityDefault) ;            lua_setfield(L, -2, "default") ;
    lua_pushinteger(L, NSStatusBarItemPrioritySystem) ;             lua_setfield(L, -2, "system") ;
    lua_pushinteger(L, NSStatusBarItemPrioritySpotlight) ;          lua_setfield(L, -2, "spotlight") ;
    lua_pushinteger(L, NSStatusBarItemPriorityNotificationCenter) ; lua_setfield(L, -2, "notificationCenter") ;
    return 1 ;
}

void menubar_setup(void) {
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
    {"newWithPriority", menubarNewWithPriority},

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
    {"stateImageSize",    menubarStateImageSize},
    {"_frame",            menubarFrame},
    {"priority",          menubarPriority},
    {"isInMenubar",       menubar_isInMenubar},
    {"isInMenuBar",       menubar_isInMenubar},

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

int luaopen_hs_libmenubar(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    menubar_setup();

    refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:menubarlib metaFunctions:menubar_gclib objectFunctions:menubar_metalib];

    pushPrioritiesTable(L) ; lua_setfield(L, -2, "priorities") ;

    return 1;
}
