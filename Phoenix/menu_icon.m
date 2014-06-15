#import "lua/lauxlib.h"

static NSStatusItem *statusItem;

int menu_icon_show(lua_State* L) {
    NSImage* img = [NSImage imageNamed:@"statusitem"];
    [img setTemplate:YES];
    
    if (!statusItem) {
        statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
        [statusItem setHighlightMode:YES];
        [statusItem setImage:img];
        
//        [statusItem setMenu:self.statusItemMenu];
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
