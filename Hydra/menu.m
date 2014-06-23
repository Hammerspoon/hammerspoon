#import "hydra.h"

@interface PHMenuItemDelegator : NSObject
@property (copy) dispatch_block_t handler;
@property BOOL disabled;
@end

@implementation PHMenuItemDelegator

- (BOOL) respondsToSelector:(SEL)aSelector {
    if (aSelector == @selector(callCustomHydraMenuItemDelegator:))
        return !self.disabled;
    else
        return [super respondsToSelector:aSelector];
}

- (void) callCustomHydraMenuItemDelegator:(id)sender {
    self.handler();
}

@end


@interface PHMenuDelegate : NSObject <NSMenuDelegate>
@property (copy) dispatch_block_t handler;
@end

@implementation PHMenuDelegate

- (void) menuNeedsUpdate:(NSMenu *)menu {
    self.handler();
}

@end


static NSStatusItem *statusItem;
static PHMenuDelegate* menuDelegate;

static int show_closureref;

static hydradoc doc_menu_show = {
    "menu", "show", "api.menu.show(fn() -> itemstable)",
    "Shows Hyra's menubar icon. The function should return a table of tables with keys: title, fn, checked (optional), disabled (optional)"
};

int menu_show(lua_State* L) {
    if (!statusItem) {
        show_closureref = luaL_ref(L, LUA_REGISTRYINDEX);
        
        NSImage* img = [NSImage imageNamed:@"menu"];
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [img setTemplate:YES];
        });
        
        statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
        [statusItem setHighlightMode:YES];
        [statusItem setImage:img];
        
        NSMenu* menu = [[NSMenu alloc] init];
        
        menuDelegate = [[PHMenuDelegate alloc] init];
        menuDelegate.handler = ^{
            [menu removeAllItems];
            
            lua_rawgeti(L, LUA_REGISTRYINDEX, show_closureref);
            
            if (lua_pcall(L, 0, 1, 0) == LUA_OK) {
                // table is at top; enumerate each row
                lua_pushvalue(L, -1);
                int tableref = luaL_ref(L, LUA_REGISTRYINDEX);
                
                int menuitem_index = 0;
                
                lua_pushnil(L);
                while (lua_next(L, -2) != 0) {
                    // table is at top; enumerate each k/v pair
                    
                    lua_getfield(L, -1, "title");
                    NSString* title = [NSString stringWithUTF8String: lua_tostring(L, -1)];
                    lua_pop(L, 1);
                    
                    
                    ++menuitem_index;
                    
                    if ([title isEqualToString: @"-"]) {
                        [menu addItem:[NSMenuItem separatorItem]];
                    }
                    else {
                        lua_getfield(L, -1, "checked");
                        BOOL checked = lua_toboolean(L, -1);
                        lua_pop(L, 1);
                        
                        lua_getfield(L, -1, "disabled");
                        BOOL disabled = lua_toboolean(L, -1);
                        lua_pop(L, 1);
                        
                        NSMenuItem* item = [[NSMenuItem alloc] init];
                        PHMenuItemDelegator* delegator = [[PHMenuItemDelegator alloc] init];
                        delegator.disabled = disabled;
                        
                        item.title = title;
                        item.state = checked ? NSOnState : NSOffState;
                        item.action = @selector(callCustomHydraMenuItemDelegator:);
                        item.target = delegator;
                        item.representedObject = delegator;
                        
                        delegator.handler = ^{
                            // get clicked menu item
                            lua_rawgeti(L, LUA_REGISTRYINDEX, tableref);
                            lua_pushnumber(L, menuitem_index);
                            lua_gettable(L, -2);
                            
                            // call function
                            lua_getfield(L, -1, "fn");
                            if (lua_pcall(L, 0, 0, 0))
                                hydra_handle_error(L);
                            
                            // pop menu items table and menu item
                            lua_pop(L, 2);
                            luaL_unref(L, LUA_REGISTRYINDEX, tableref);
                        };
                        
                        [menu addItem:item];
                    }
                    
                    
                    
                    
                    
                    lua_pop(L, 1);
                }
            }
            else {
                hydra_handle_error(L);
            }
        };
        menu.delegate = menuDelegate;
        [statusItem setMenu: menu];
    }
    
    return 0;
}

static hydradoc doc_menu_hide = {
    "menu", "hide", "api.menu.hide()",
    "Hides Hydra's menubar icon."
};

int menu_hide(lua_State* L) {
    if (statusItem) {
        luaL_unref(L, LUA_REGISTRYINDEX, show_closureref);
        
        [[statusItem statusBar] removeStatusItem: statusItem];
        statusItem = nil;
    }
    return 0;
}

static const luaL_Reg menulib[] = {
    {"show", menu_show},
    {"hide", menu_hide},
    {NULL, NULL}
};

int luaopen_menu(lua_State* L) {
    hydra_add_doc_group(L, "menu", "Control Hydra's menu-bar icon.");
    hydra_add_doc_item(L, &doc_menu_show);
    hydra_add_doc_item(L, &doc_menu_hide);
    
    luaL_newlib(L, menulib);
    return 1;
}
