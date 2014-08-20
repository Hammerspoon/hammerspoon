#import "MJMenuIcon.h"
#import "variables.h"

@interface MJMenuIcon ()
@property NSStatusItem* statusItem;
@end

@implementation MJMenuIcon

+ (MJMenuIcon*) sharedIcon {
    static MJMenuIcon* sharedIcon;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedIcon = [[MJMenuIcon alloc] init];
    });
    return sharedIcon;
}

- (void) setup {
    [self reflectDefaults];
}

- (BOOL) visible {
    return [[NSUserDefaults standardUserDefaults] boolForKey:MJShowMenuIconKey];
}

- (void) setVisible:(BOOL)visible {
    [[NSUserDefaults standardUserDefaults] setBool:visible
                                            forKey:MJShowMenuIconKey];
    [self reflectDefaults];
}

- (void) reflectDefaults {
    if (self.visible) {
        NSImage* icon = [NSImage imageNamed:@"statusicon"];
        [icon setTemplate:YES];
        
        self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
        [self.statusItem setImage:icon];
        [self.statusItem setHighlightMode:YES];
    }
    else {
        if (self.statusItem) {
            [[NSStatusBar systemStatusBar] removeStatusItem:self.statusItem];
            self.statusItem = nil;
        }
    }
}

@end
