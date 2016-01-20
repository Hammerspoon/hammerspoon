//
//  HSChooser.m
//  Hammerspoon
//
//  Created by Chris Jones on 29/12/2015.
//  Copyright © 2015 Hammerspoon. All rights reserved.
//

#import "HSChooser.h"

#pragma mark - Chooser object implementation

@implementation HSChooser

#pragma mark - Object initialisation

- (id)initWithRefTable:(int *)refTable completionCallbackRef:(int)completionCallbackRef {
    self = [super initWithWindowNibName:@"HSChooserWindow" owner:self];
    if (self) {
        self.refTable = refTable;

        self.eventMonitors = [[NSMutableArray alloc] init];

        // Set our defaults
        self.numRows = 10;
        self.width = 40;
        self.fontName = nil;
        self.fontSize = 0;
        self.searchSubText = NO;

        // We're setting these directly, because we've overridden the setters and we don't need to invoke those now
        _fgColor = nil;
        _subTextColor = nil;

        self.currentStaticChoices = nil;
        self.currentCallbackChoices = nil;
        self.filteredChoices = nil;

        self.choicesCallbackRef = LUA_NOREF;
        self.queryChangedCallbackRef = LUA_NOREF;
        self.completionCallbackRef = completionCallbackRef;

        self.hasChosen = NO;
        self.reloadWhenVisible = NO;

        // Decide which font to use
        if (!self.fontName) {
            self.font = [NSFont systemFontOfSize:self.fontSize];
        } else {
            self.font = [NSFont fontWithName:self.fontName size:self.fontSize];
        }

        [self calculateRects];

        if (![self setupWindow]) {
            return nil;
        }
    }

    return self;
}

#pragma mark - Window related methods

- (void)windowDidLoad {
    [super windowDidLoad];

    [self.queryField setFocusRingType:NSFocusRingTypeNone];
}


- (void)windowDidBecomeKey:(NSNotification *)notification {
    __weak id _self = self;
    __weak id _tableView = self.choicesTableView;
    __weak id _window = self.window;

    if (self.reloadWhenVisible) {
        [self.choicesTableView reloadData];
        self.reloadWhenVisible = NO;
    }

    [self addShortcut:@"1" keyCode:-1 mods:NSCommandKeyMask handler:^{ [_self tableView:_tableView didClickedRow:0]; }];
    [self addShortcut:@"2" keyCode:-1 mods:NSCommandKeyMask handler:^{ [_self tableView:_tableView didClickedRow:1]; }];
    [self addShortcut:@"3" keyCode:-1 mods:NSCommandKeyMask handler:^{ [_self tableView:_tableView didClickedRow:2]; }];
    [self addShortcut:@"4" keyCode:-1 mods:NSCommandKeyMask handler:^{ [_self tableView:_tableView didClickedRow:3]; }];
    [self addShortcut:@"5" keyCode:-1 mods:NSCommandKeyMask handler:^{ [_self tableView:_tableView didClickedRow:4]; }];
    [self addShortcut:@"6" keyCode:-1 mods:NSCommandKeyMask handler:^{ [_self tableView:_tableView didClickedRow:5]; }];
    [self addShortcut:@"7" keyCode:-1 mods:NSCommandKeyMask handler:^{ [_self tableView:_tableView didClickedRow:6]; }];
    [self addShortcut:@"8" keyCode:-1 mods:NSCommandKeyMask handler:^{ [_self tableView:_tableView didClickedRow:7]; }];
    [self addShortcut:@"9" keyCode:-1 mods:NSCommandKeyMask handler:^{ [_self tableView:_tableView didClickedRow:8]; }];
    [self addShortcut:@"0" keyCode:-1 mods:NSCommandKeyMask handler:^{ [_self tableView:_tableView didClickedRow:9]; }];

    [self addShortcut:@"Escape" keyCode:27 mods:0 handler:^{ [_window resignKeyWindow]; }];

    [self addShortcut:@"Up" keyCode:NSUpArrowFunctionKey mods:NSFunctionKeyMask|NSNumericPadKeyMask handler:^{ [_self selectPreviousChoice]; }];
    [self addShortcut:@"Down" keyCode:NSDownArrowFunctionKey mods:NSFunctionKeyMask|NSNumericPadKeyMask handler:^{ [_self selectNextChoice]; }];
}

- (void)windowDidResignKey:(NSNotification *)notification {
    for (id monitor in self.eventMonitors) {
        [NSEvent removeMonitor:monitor];
    }
    [self.eventMonitors removeAllObjects];

    if (!self.hasChosen) {
        [self cancel:nil];
    }
}

- (void)calculateRects {
    // Calculate the sizes of the various bits of our UI
    NSRect winRect, contentViewRect, textRect, listRect, dividerRect;

    winRect = NSMakeRect(0, 0, 100, 100);
    contentViewRect = NSInsetRect(winRect, 10, 10);

    NSDivideRect(contentViewRect, &textRect, &listRect, NSHeight([self.font boundingRectForFont]), NSMaxYEdge);
    NSDivideRect(listRect, &dividerRect, &listRect, 20.0, NSMaxYEdge);
    dividerRect.origin.y += NSHeight(dividerRect) / 2.0;
    dividerRect.size.height = 1.0;

    self.winRect = winRect;
    self.textRect = textRect;
    self.listRect = listRect;
    self.dividerRect = dividerRect;
}

- (BOOL)setupWindow {
    // Create and configure our window

    // NOTE: This reference to self.window is critically important - it is the getter for this property which causes the window to be instantiated. Without it, we will have no window.
    if (!self.window || !self.windowLoaded) {
        NSLog(@"ERROR: Unable to load hs.chooser window NIB");
        return NO;
    }

    self.choicesTableView.delegate = self;
    self.choicesTableView.extendedDelegate = self;
    self.choicesTableView.dataSource = self;
    self.choicesTableView.target = self;

    self.queryField.delegate = self;
    self.queryField.target = self;
    self.queryField.action = @selector(queryDidPressEnter:);

    return YES;
}

- (void)resizeWindow {
    NSRect screenFrame = [[NSScreen mainScreen] visibleFrame];

    CGFloat rowHeight = [self.choicesTableView rowHeight];
    CGFloat intercellHeight =[self.choicesTableView intercellSpacing].height;
    CGFloat allRowsHeight = (rowHeight + intercellHeight) * self.numRows;

    CGFloat windowHeight = NSHeight([[self.window contentView] bounds]);
    CGFloat tableHeight = NSHeight([[self.choicesTableView superview] frame]);
    CGFloat finalHeight = (windowHeight - tableHeight) + allRowsHeight;

    CGFloat width;
    if (self.width >= 0 && self.width <= 100) {
        CGFloat percentWidth = self.width / 100.0;
        width = NSWidth(screenFrame) * percentWidth;
    } else {
        width = NSWidth(screenFrame) * 0.50;
        width = MIN(width, 800);
        width = MAX(width, 400);
    }

    NSRect winRect = NSMakeRect(0, 0, width, finalHeight);
    [self.window setFrame:winRect display:YES];
    [self.choicesTableView setFrameSize:NSMakeSize(winRect.size.width, self.choicesTableView.frame.size.height)];
}

- (void)show {
    self.hasChosen = NO;

    [self resizeWindow];

    [self showWindow:self];
    self.window.isVisible = YES;
    [self.window center];
    [self.window makeKeyAndOrderFront:self];
    [self.window makeFirstResponder:self.queryField];

    [self.window setLevel:(CGWindowLevelForKey(kCGMainMenuWindowLevelKey) + 3)];

    if (!self.window.isKeyWindow) {
        NSApplication *app = [NSApplication sharedApplication];
        [app activateIgnoringOtherApps:YES];
    }

    [self controlTextDidChange:[NSNotification notificationWithName:@"Unused" object:nil]];
}

- (void)hide {
    self.window.isVisible = NO;
}

#pragma mark - NSTableViewDataSource

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView {
    NSInteger rowCount = 0;
    NSArray *choices = [self getChoices];

    if (choices) {
        rowCount = choices.count;
    }

    return rowCount;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSArray *choices = [self getChoices];
    NSDictionary *choice = [choices objectAtIndex:row];

    HSChooserCell *cellView = [tableView makeViewWithIdentifier:@"HSChooserCell" owner:self];

    //cellView.backgroundStyle = NSBackgroundStyleDark;
    NSString *text         = [choice objectForKey:@"text"];
    NSString *subText      = [choice objectForKey:@"subText"];
    NSString *shortcutText = @"";
    NSImage  *image        = [choice objectForKey:@"image"];

    if (row >= 0 && row < 9) {
        shortcutText = [NSString stringWithFormat:@"⌘%ld", (long)row + 1];
    } else {
        shortcutText = @"";
    }

    cellView.text.stringValue = text ? text : @"UNKNOWN TEXT";
    cellView.subText.stringValue = subText ? subText : @"UNKNOWN SUBTEXT";
    cellView.shortcutText.stringValue = shortcutText ? shortcutText : @"??";
    cellView.image.image = image ? image : [NSImage imageNamed:NSImageNameFollowLinkFreestandingTemplate];

    if (self.fgColor) {
        cellView.text.textColor = self.fgColor;
        cellView.shortcutText.textColor = self.fgColor;
    }

    if (self.subTextColor) {
        cellView.subText.textColor = self.subTextColor;
    }

    return cellView;
}

#pragma mark - HSTableViewDelegate

- (void)tableView:(NSTableView *)tableView didClickedRow:(NSInteger)row {
    //NSLog(@"didClickedRow: %li", (long)row);
    if (row >= 0 && row < [[self getChoices] count]) {
        self.hasChosen = YES;
        [self hide];
        LuaSkin *skin = [LuaSkin shared];
        NSDictionary *choice = [[self getChoices] objectAtIndex:row];

        [skin pushLuaRef:*(self.refTable) ref:self.completionCallbackRef];
        [skin pushNSObject:choice];
        [skin protectedCallAndTraceback:1 nresults:0];
    }
}

#pragma mark - UI callbacks

- (IBAction)cancel:(id)sender {
    //NSLog(@"HSChooser::cancel:");
    [self hide];
    LuaSkin *skin = [LuaSkin shared];
    [skin pushLuaRef:*(self.refTable) ref:self.completionCallbackRef];
    lua_pushnil(skin.L);
    [skin protectedCallAndTraceback:1 nresults:0];
}

- (IBAction)queryDidPressEnter:(id)sender {
    //NSLog(@"in queryDidPressEnter:");
    [self tableView:self.choicesTableView didClickedRow:self.choicesTableView.selectedRow];
}

- (void)controlTextDidChange:(NSNotification *)aNotification {
    //NSLog(@"controlTextDidChange: %@", self.queryField.stringValue);
    NSString *queryString = self.queryField.stringValue;

    if (self.queryChangedCallbackRef != LUA_NOREF && self.queryChangedCallbackRef != LUA_REFNIL) {
        // We have a query callback set, we are passing on responsibility for displaying/filtering results, to Lua
        LuaSkin *skin = [LuaSkin shared];
        [skin pushLuaRef:*(self.refTable) ref:self.queryChangedCallbackRef];
        [skin pushNSObject:queryString];
        [skin protectedCallAndTraceback:1 nresults:0];
    } else {
        // We do not have a query callback set, so we are doing the filtering
        if (queryString.length > 0) {
            NSMutableArray *filteredChoices = [[NSMutableArray alloc] init];

            for (NSDictionary *choice in [self getChoicesWithOptions:NO]) {
                if ([[[choice objectForKey:@"text"] lowercaseString] containsString:[queryString lowercaseString]]) {
                    [filteredChoices addObject: choice];
                } else if (self.searchSubText) {
                    if ([[[choice objectForKey:@"subText"] lowercaseString] containsString:[queryString lowercaseString]]) {
                        [filteredChoices addObject:choice];
                    }
                }
            }

            self.filteredChoices = filteredChoices;
        } else {
            self.filteredChoices = nil;
        }
        [self.choicesTableView reloadData];
    }
}

- (void)selectChoice:(NSInteger)row {
    NSUInteger numRows = [[self getChoices] count];
    if (row < 0 || row > (numRows - 1)) {
        [[LuaSkin shared] logError:[NSString stringWithFormat:@"ERROR: unable to select row %li of %li", (long)row, (long)numRows]];
        return;
    }
    [self.choicesTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];

    // FIXME: This scrolling is awfully jumpy
    [self.choicesTableView scrollRowToVisible:row];
}

- (void)selectNextChoice {
    NSInteger currentRow = [self.choicesTableView selectedRow];
    if (currentRow == [[self getChoices] count] - 1) {
        currentRow = -1;
    }
    [self selectChoice:currentRow+1];
}

- (void)selectPreviousChoice {
    NSInteger currentRow = [self.choicesTableView selectedRow];
    if (currentRow == 0) {
        currentRow = [[self getChoices] count];
    }
    [self selectChoice:currentRow-1];
}

#pragma mark - Choice management methods

- (void)updateChoices {
    if (self.window.visible) {
        [self.choicesTableView reloadData];
    } else {
        self.reloadWhenVisible = YES;
    }
}

- (void)clearChoices {
    self.currentStaticChoices = nil;
    self.currentCallbackChoices = nil;
    self.filteredChoices = nil;
}

- (void)clearChoicesAndUpdate {
    [self clearChoices];
    [self updateChoices];
}

- (NSArray *)getChoices {
    return [self getChoicesWithOptions:YES];
}

- (NSArray *)getChoicesWithOptions:(BOOL)includeFiltered {
    NSArray *choices = nil;

    if (includeFiltered && self.filteredChoices != nil) {
        // We have some previously filtered choices, so we will return that
        choices = self.filteredChoices;
    } else if (self.choicesCallbackRef == LUA_NOREF) {
        // No callback is set, we can only return the static choices, even if it's nil
        choices = self.currentStaticChoices;
    } else if (self.choicesCallbackRef != LUA_NOREF) {
        // We have a callback set
        if (self.currentCallbackChoices == nil) {
            // We have previously cached the callback choices
            LuaSkin *skin = [LuaSkin shared];
            [skin pushLuaRef:*(self.refTable) ref:self.choicesCallbackRef];
            if ([skin protectedCallAndTraceback:0 nresults:1]) {
                self.currentCallbackChoices = [skin toNSObjectAtIndex:-1];

                BOOL callbackChoicesTypeCheckPass = NO;
                if ([self.currentCallbackChoices isKindOfClass:[NSArray class]]) {
                    callbackChoicesTypeCheckPass = YES;
                    for (id arrayElement in self.currentCallbackChoices) {
                        if (![arrayElement isKindOfClass:[NSDictionary class]]) {
                            callbackChoicesTypeCheckPass = NO;
                            break;
                        }
                    }
                }
                if (!callbackChoicesTypeCheckPass) {
                    // Light verification of the callback choices shows the format is wrong, so let's ignore it
                    [[LuaSkin shared] logError:@"ERROR: data returned by hs.chooser:choices() callback could not be parsed correctly"];
                    self.currentCallbackChoices = nil;
                }
            }
        }

        if (self.currentCallbackChoices != nil) {
            choices = self.currentCallbackChoices;
        }
    }

    //NSLog(@"HSChooser::getChoicesWithOptions: returning: %@", choices);
    return choices;
}

#pragma mark - UI customisation methods

- (void)setFgColor:(NSColor *)fgColor {
    _fgColor = fgColor;
    self.queryField.textColor = _fgColor;

    for (int x = 0; x < [self.choicesTableView numberOfRows]; x++) {
        NSTableCellView *cellView = [self.choicesTableView viewAtColumn:0 row:x makeIfNecessary:NO];
        NSTextField *text = [cellView viewWithTag:1];
        NSTextField *shortcutText = [cellView viewWithTag:2];
        text.textColor = _fgColor;
        shortcutText.textColor = _fgColor;
    }
}

- (void)setSubTextColor:(NSColor *)subTextColor {
    _subTextColor = subTextColor;

    for (int x = 0; x < [self.choicesTableView numberOfRows]; x++) {
        NSTableCellView *cellView = [self.choicesTableView viewAtColumn:0 row:x makeIfNecessary:NO];
        NSTextField *subText = [cellView viewWithTag:3];
        subText.textColor = _subTextColor;
    }
}

- (void)setBgLightDark:(BOOL)isDark {
    if (isDark) {
        self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
        [self.effectView setMaterial:NSVisualEffectMaterialDark];
    } else {
        self.window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameVibrantLight];
        [self.effectView setMaterial:NSVisualEffectMaterialLight];
    }
}

- (BOOL)isBgLightDark {
    return [self.window.appearance.name isEqualToString:NSAppearanceNameVibrantDark];
}

#pragma mark - Utility methods

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

@end
