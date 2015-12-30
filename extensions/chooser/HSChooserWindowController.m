//
//  HSChooserWindowController.m
//  Hammerspoon
//
//  Created by Chris Jones on 29/12/2015.
//  Copyright © 2015 Hammerspoon. All rights reserved.
//

#import "HSChooserWindowController.h"

@implementation HSChooserWindowController

- (id)initWithOwner:(id)owner {
    self = [super initWithWindowNibName:@"HSChooserWindow" owner:self];
    if (self) {
        self.eventMonitors = [[NSMutableArray alloc] init];
    }
    return self;
}

- (id)initWithWindowNibName: (NSString *)name {
    NSLog(@"External clients are not allowed to call -[%@ initWithWindowNibName:] directly!", [self class]);
    [self doesNotRecognizeSelector: _cmd];
    return nil;
}

- (void)windowDidLoad {
    [super windowDidLoad];

    [self.queryField setFocusRingType:NSFocusRingTypeNone];
}

- (void)selectChoice:(NSInteger)row {
    [self.listTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
}

- (void)selectNextChoice {
    NSInteger currentRow = [self.listTableView selectedRow];
    [self selectChoice:currentRow+1];
}

- (void)selectPreviousChoice {
    NSInteger currentRow = [self.listTableView selectedRow];
    [self selectChoice:currentRow-1];
}

- (void)cancel {
    if ([self.delegate respondsToSelector:@selector(cancel:)]) {
        [self.delegate cancel:nil];
    }
}

- (void) addShortcut:(NSString*)key keyCode:(unsigned short)keyCode mods:(NSEventModifierFlags)mods handler:(dispatch_block_t)action {
    //NSLog(@"Adding shortcut for %lu %@:%i", mods, key, keyCode);
    id x = [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask handler:^ NSEvent*(NSEvent* event) {
        NSEventModifierFlags flags = ([event modifierFlags] & NSDeviceIndependentModifierFlagsMask);
        //NSLog(@"Got an event: %lu %@:%i", (unsigned long)flags, [event charactersIgnoringModifiers], [[event charactersIgnoringModifiers] characterAtIndex:0]);

        if (flags == mods) {
            if ([[event charactersIgnoringModifiers] isEqualToString: key] || [[event charactersIgnoringModifiers] characterAtIndex:0] == keyCode) {
                //NSLog(@"firing action");
                action();
                return nil;
            }
        }
        return event;
    }];
    [self.eventMonitors addObject: x];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    __weak id _self = self;
    [self addShortcut:@"1" keyCode:-1 mods:NSCommandKeyMask handler:^{ [_self selectChoice: 0]; }];
    [self addShortcut:@"2" keyCode:-1 mods:NSCommandKeyMask handler:^{ [_self selectChoice: 1]; }];
    [self addShortcut:@"3" keyCode:-1 mods:NSCommandKeyMask handler:^{ [_self selectChoice: 2]; }];
    [self addShortcut:@"4" keyCode:-1 mods:NSCommandKeyMask handler:^{ [_self selectChoice: 3]; }];
    [self addShortcut:@"5" keyCode:-1 mods:NSCommandKeyMask handler:^{ [_self selectChoice: 4]; }];
    [self addShortcut:@"6" keyCode:-1 mods:NSCommandKeyMask handler:^{ [_self selectChoice: 5]; }];
    [self addShortcut:@"7" keyCode:-1 mods:NSCommandKeyMask handler:^{ [_self selectChoice: 6]; }];
    [self addShortcut:@"8" keyCode:-1 mods:NSCommandKeyMask handler:^{ [_self selectChoice: 7]; }];
    [self addShortcut:@"9" keyCode:-1 mods:NSCommandKeyMask handler:^{ [_self selectChoice: 8]; }];

    //    [self addShortcut:@"a" mods:NSCommandKeyMask handler:^{ [_self selectAll: nil]; }]; // FIXME: Do we care?

    [self addShortcut:@"Escape" keyCode:27 mods:0 handler:^{ [_self cancel]; }];

    [self addShortcut:@"Up" keyCode:NSUpArrowFunctionKey mods:NSFunctionKeyMask|NSNumericPadKeyMask handler:^{ [_self selectPreviousChoice]; }];
    [self addShortcut:@"Down" keyCode:NSDownArrowFunctionKey mods:NSFunctionKeyMask|NSNumericPadKeyMask handler:^{ [_self selectNextChoice]; }];
}

- (void)windowDidResignKey:(NSNotification *)notification {
    for (id monitor in self.eventMonitors) {
        [NSEvent removeMonitor:monitor];
    }
    [self.eventMonitors removeAllObjects];
    [self cancel];
}


@end
