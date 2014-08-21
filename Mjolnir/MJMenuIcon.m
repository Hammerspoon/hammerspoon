#import "MJMenuIcon.h"
#import "variables.h"

static void reflect_defaults(void);

static NSStatusItem* statusItem;

void MJMenuIconSetup() {
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
        [statusItem setImage:icon];
        [statusItem setHighlightMode:YES];
    }
    else {
        if (statusItem) {
            [[NSStatusBar systemStatusBar] removeStatusItem: statusItem];
            statusItem = nil;
        }
    }
}
