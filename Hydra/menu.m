#import "lua/lauxlib.h"

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

int menu_show(lua_State* L) {
    // these are intentionally in reverse order, since they pop off the stack
    int click_closureref = luaL_ref(L, LUA_REGISTRYINDEX);
    int show_closureref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    NSImage* img = [NSImage imageNamed:@"menu"];
    [img setTemplate:YES];
    
    if (!statusItem) {
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
                            lua_rawgeti(L, LUA_REGISTRYINDEX, click_closureref);
                            lua_pushnumber(L, menuitem_index);
                            
                            if (lua_pcall(L, 1, 0, 0) == LUA_OK) {
                            }
                            else {
                                // handle handle-click error
                            }
                        };
                        
                        [menu addItem:item];
                    }
                    
                    
                    
                    
                    
                    lua_pop(L, 1);
                }
            }
            else {
                // handle show-menu error
            }
        };
        menu.delegate = menuDelegate;
        [statusItem setMenu: menu];
    }
    
    lua_pushnumber(L, click_closureref);
    lua_pushnumber(L, show_closureref);
    return 2;
}

int menu_hide(lua_State* L) {
    luaL_unref(L, LUA_REGISTRYINDEX, lua_tonumber(L, 1));
    luaL_unref(L, LUA_REGISTRYINDEX, lua_tonumber(L, 2));
    
    if (statusItem) {
        [[statusItem statusBar] removeStatusItem: statusItem];
        statusItem = nil;
    }
    return 0;
}

int luaopen_menu(lua_State* L) { return 0; }
