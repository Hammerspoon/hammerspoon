#import "lua/lauxlib.h"

@interface PHMenuItemDelegator : NSObject
@property (copy) dispatch_block_t handler;
@end

@implementation PHMenuItemDelegator
- (void) callCustomPhoenixMenuItemDelegator:(id)sender {
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

int menu_icon_show(lua_State* L) {
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
            
            NSMenuItem* item = [[NSMenuItem alloc] init];
            PHMenuItemDelegator* delegator = [[PHMenuItemDelegator alloc] init];
            
            item.title = @"foobar";
            item.action = @selector(callCustomPhoenixMenuItemDelegator:);
            item.target = delegator;
            item.representedObject = delegator;
            
            delegator.handler = ^{
                NSLog(@"called!");
            };
            
            [menu addItem:item];
        };
        menu.delegate = menuDelegate;
        [statusItem setMenu: menu];
    }
    
    return 0;
}

int menu_icon_hide(lua_State* L) {
    if (statusItem) {
        [[statusItem statusBar] removeStatusItem: statusItem];
        statusItem = nil;
    }
    return 0;
}

int phoenix_show_about_panel(lua_State* L) {
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp orderFrontStandardAboutPanel:nil];
    return 0;
}

//- (IBAction) toggleOpenAtLogin:(NSMenuItem*)sender {
//    [PHOpenAtLogin setOpensAtLogin:[sender state] == NSOffState];
//}
//
//- (void) menuNeedsUpdate:(NSMenu *)menu {
//    [[menu itemWithTitle:@"Open at Login"] setState:([PHOpenAtLogin opensAtLogin] ? NSOnState : NSOffState)];
//}
