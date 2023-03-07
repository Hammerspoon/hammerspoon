#import "MJMenuIcon.h"
#import "variables.h"

static void reflect_defaults(void);

static NSStatusItem* statusItem;
static NSMenu* menuItemMenu;

void MJMenuIconSetup(NSMenu* menu) {
    menuItemMenu = menu;
    reflect_defaults();
}

BOOL MJMenuIconVisible(void) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:MJShowMenuIconKey];
}

void MJMenuIconSetVisible(BOOL visible) {
    [[NSUserDefaults standardUserDefaults] setBool:visible
                                            forKey:MJShowMenuIconKey];
    reflect_defaults();
}

static void reflect_defaults(void) {
    if (MJMenuIconVisible()) {
        NSImage* icon = [NSImage imageNamed:@"statusicon"];
        [icon setTemplate:YES];
        
        statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
        statusItem.button.image = icon;
        [statusItem setMenu: menuItemMenu];
    }
    else {
        if (statusItem) {
            [[NSStatusBar systemStatusBar] removeStatusItem: statusItem];
            statusItem = nil;
        }
    }
}
