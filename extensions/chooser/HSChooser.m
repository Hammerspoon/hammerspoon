//
//  HSChooser.m
//  Hammerspoon
//
//  Created by Chris Jones on 29/12/2015.
//  Copyright © 2015 Hammerspoon. All rights reserved.
//

#import "HSChooser.h"
#import "chooser.h"

#pragma mark - Chooser object implementation

@implementation HSChooser

#pragma mark - Object initialisation

- (id)initWithRefTable:(LSRefTable)refTable completionCallbackRef:(int)completionCallbackRef {
    self = [super initWithWindowNibName:@"HSChooserWindow" owner:self];
    if (self) {
        self.refTable = refTable;
        self.selfRefCount = 0;

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
        _isObservingThemeChanges = NO;

        self.currentStaticChoices = nil;
        self.currentCallbackChoices = nil;
        self.filteredChoices = nil;

        self.hideCallbackRef = LUA_NOREF;
        self.showCallbackRef = LUA_NOREF;
        self.choicesCallbackRef = LUA_NOREF;
        self.queryChangedCallbackRef = LUA_NOREF;
        self.rightClickCallbackRef = LUA_NOREF;
        self.invalidCallbackRef = LUA_NOREF;
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

        // Start observing interface theme changes.
        self.isObservingThemeChanges = YES;
    }

    return self;
}

#pragma mark - Window related methods

- (void)windowDidLoad {
    [super windowDidLoad];

    [self.queryField setFocusRingType:NSFocusRingTypeNone];
    [self setAutoBgLightDark];
}

- (void)windowDidBecomeKey:(NSNotification *)notification {
    __weak id _self = self;
    __weak id _tableView = self.choicesTableView;
    __weak id _window = self.window;

    if (self.reloadWhenVisible) {
        [self.choicesTableView reloadData];
        self.reloadWhenVisible = NO;
    }

    [self addShortcut:@"1" keyCode:-1 mods:NSEventModifierFlagCommand handler:^{ [_self tableView:_tableView didClickedRow:0]; }];
    [self addShortcut:@"2" keyCode:-1 mods:NSEventModifierFlagCommand handler:^{ [_self tableView:_tableView didClickedRow:1]; }];
    [self addShortcut:@"3" keyCode:-1 mods:NSEventModifierFlagCommand handler:^{ [_self tableView:_tableView didClickedRow:2]; }];
    [self addShortcut:@"4" keyCode:-1 mods:NSEventModifierFlagCommand handler:^{ [_self tableView:_tableView didClickedRow:3]; }];
    [self addShortcut:@"5" keyCode:-1 mods:NSEventModifierFlagCommand handler:^{ [_self tableView:_tableView didClickedRow:4]; }];
    [self addShortcut:@"6" keyCode:-1 mods:NSEventModifierFlagCommand handler:^{ [_self tableView:_tableView didClickedRow:5]; }];
    [self addShortcut:@"7" keyCode:-1 mods:NSEventModifierFlagCommand handler:^{ [_self tableView:_tableView didClickedRow:6]; }];
    [self addShortcut:@"8" keyCode:-1 mods:NSEventModifierFlagCommand handler:^{ [_self tableView:_tableView didClickedRow:7]; }];
    [self addShortcut:@"9" keyCode:-1 mods:NSEventModifierFlagCommand handler:^{ [_self tableView:_tableView didClickedRow:8]; }];
    [self addShortcut:@"0" keyCode:-1 mods:NSEventModifierFlagCommand handler:^{ [_self tableView:_tableView didClickedRow:9]; }];

    [self addShortcut:@"Escape" keyCode:27 mods:0 handler:^{ [_window resignKeyWindow]; }];

    [self addShortcut:@"Up" keyCode:NSUpArrowFunctionKey mods:NSEventModifierFlagFunction|NSEventModifierFlagNumericPad handler:^{ [_self selectPreviousChoice]; }];
    [self addShortcut:@"Down" keyCode:NSDownArrowFunctionKey mods:NSEventModifierFlagFunction|NSEventModifierFlagNumericPad handler:^{ [_self selectNextChoice]; }];
    [self addShortcut:@"p" keyCode:-1 mods:NSEventModifierFlagControl handler:^{ [_self selectPreviousChoice]; }];
    [self addShortcut:@"n" keyCode:-1 mods:NSEventModifierFlagControl handler:^{ [_self selectNextChoice]; }];

    [self addShortcut:@"PageUp" keyCode:NSPageUpFunctionKey mods:NSEventModifierFlagFunction handler:^{ [_self selectPreviousPage]; }];
    [self addShortcut:@"PageDown" keyCode:NSPageDownFunctionKey mods:NSEventModifierFlagFunction handler:^{ [_self selectNextPage]; }];
    [self addShortcut:@"v" keyCode:-1 mods:NSEventModifierFlagControl handler:^{ [_self selectNextPage]; }];
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

- (BOOL)control: (NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (commandSelector == @selector(insertNewlineIgnoringFieldEditor:)) {
        // User hit cmd-enter
        [self queryDidPressEnter:self];
        return true;
    } else if (commandSelector == @selector(insertLineBreak:)) {
        // User hit option-enter
        [self queryDidPressEnter:self];
        return true;
    }

    return false;
}

- (void)resizeWindow {
    NSRect screenFrame = [[NSScreen mainScreen] visibleFrame];

    CGFloat rowHeight = [self.choicesTableView rowHeight];
    CGFloat intercellHeight =[self.choicesTableView intercellSpacing].height;
    CGFloat allRowsHeight = (rowHeight + intercellHeight) * self.numRows;

    CGFloat toolbarHeight = 0.0;
    if (self.window.toolbar && self.window.toolbar.visible) {
        NSRect windowFrame = [NSWindow contentRectForFrameRect:self.window.frame styleMask:self.window.styleMask];
        toolbarHeight = NSHeight(windowFrame) - NSHeight(self.window.contentView.frame);
    }

    CGFloat windowHeight = NSHeight([[self.window contentView] bounds]);
    CGFloat tableHeight = NSHeight([[self.choicesTableView superview] frame]);
    CGFloat finalHeight = (windowHeight - tableHeight) + allRowsHeight + toolbarHeight;

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

- (void)showAtPoint:(NSPoint)topLeft {
    [self showWithHints:NO atPoint:topLeft];
}

- (void)show {
    [self showWithHints:YES atPoint:NSMakePoint(0,0)];
}

- (void)showWithHints:(BOOL)center atPoint:(NSPoint)topLeft {
    self.hasChosen = NO;

    // Call hs.chooser.globalCallback("willShow")
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    lua_State *L = skin.L;
    _lua_stackguard_entry(L);
    [skin requireModule:"hs.chooser"] ;
    lua_getfield(L, -1, "globalCallback") ;
    lua_remove(L, -2) ;

    // Check the type of `globalCallback`
    if (lua_type(L, -1) == LUA_TNIL) {
        lua_remove(L, -1);
    } else if (lua_type(L, -1) != LUA_TFUNCTION) {
        [skin logError:[NSString stringWithFormat:@"hs.chooser.globalCallback is expected to be a function, but is a %s", lua_typename(L, lua_type(L, -1))]];
        // Remove whatever `globalCallback` is, from the stack
        lua_remove(L, -1);
    } else {
        [skin pushNSObject:self];
        lua_pushstring(L, "willOpen");
        [skin protectedCallAndError:@"hs.chooser.globalCallback willOpen" nargs:2 nresults:0];
    }

    [self resizeWindow];

    [self showWindow:self];
    self.window.isVisible = YES;

    if (center) {
        [self.window center];
    } else {
        [self.window setFrameTopLeftPoint:topLeft];
    }
    [self.window makeKeyAndOrderFront:self];
    [self.window makeFirstResponder:self.queryField];

    [self.window setLevel:(CGWindowLevelForKey(kCGMainMenuWindowLevelKey) + 3)];

    //if (!self.window.isKeyWindow) {
    //    NSApplication *app = [NSApplication sharedApplication];
    //    [app activateIgnoringOtherApps:YES];
    //}

    [self controlTextDidChange:[NSNotification notificationWithName:@"Unused" object:nil]];

    if (self.showCallbackRef != LUA_NOREF && self.showCallbackRef != LUA_REFNIL) {
        [skin pushLuaRef:self.refTable ref:self.showCallbackRef];
        [skin protectedCallAndError:@"hs.chooser:showCallback" nargs:0 nresults:0];
    }
    _lua_stackguard_exit(skin.L);
}

- (void)hide {
    self.window.isVisible = NO;

    // Call hs.chooser.globalCallback("didClose")
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    lua_State *L = skin.L;
    _lua_stackguard_entry(L);
    [skin requireModule:"hs.chooser"] ;
    lua_getfield(L, -1, "globalCallback") ;
    lua_remove(L, -2) ;

    // Check the type of `globalCallback`
    if (lua_type(L, -1) == LUA_TNIL) {
        lua_remove(L, -1);
    } else if (lua_type(L, -1) != LUA_TFUNCTION) {
        [skin logError:[NSString stringWithFormat:@"hs.chooser.globalCallback is expected to be a function, but is a %s", lua_typename(L, lua_type(L, -1))]];
        // Remove whatever `globalCallback` is, from the stack
        lua_remove(L, -1);
    } else {
        [skin pushNSObject:self];
        lua_pushstring(L, "didClose");
        [skin protectedCallAndError:@"hs.chooser.globalCallback didClose" nargs:2 nresults:0];
    }

    // Call hs.chooser:hideCallback()
    if (self.hideCallbackRef != LUA_NOREF && self.hideCallbackRef != LUA_REFNIL) {
        [skin pushLuaRef:self.refTable ref:self.hideCallbackRef];
        [skin protectedCallAndError:@"hs.chooser:hideCallback" nargs:0 nresults:0];
    }
    _lua_stackguard_exit(L);
}

- (BOOL)isVisible {
    return self.window.isVisible;
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

    id text                = [choice objectForKey:@"text"];
    id subText             = [choice objectForKey:@"subText"];
    NSString *shortcutText = @"";
    NSImage  *image        = [choice objectForKey:@"image"];

    if (text && ![text isKindOfClass:[NSString class]] && ![text isKindOfClass:[NSAttributedString class]]) {
        text = [NSString stringWithFormat:@"%@", text];
    }
    if (subText && ![subText isKindOfClass:[NSString class]] && ![subText isKindOfClass:[NSAttributedString class]]) {
        subText = [NSString stringWithFormat:@"%@", subText];
    }
    if (image && ![image isKindOfClass:[NSImage class]]) image = nil;

    if (row >= 0 && row < 9) {
        shortcutText = [NSString stringWithFormat:@"⌘%ld", (long)row + 1];
    } else {
        shortcutText = @"";
    }

    NSString *chooserCellIdentifier = subText ?  @"HSChooserCellSubtext" : @"HSChooserCell";
    HSChooserCell *cellView = [tableView makeViewWithIdentifier:chooserCellIdentifier owner:self];

    if ([text isKindOfClass:[NSAttributedString class]]) {
        cellView.text.attributedStringValue = (NSAttributedString *)text;
    } else {
        cellView.text.stringValue = text ? (NSString *)text : @"";
    }

    if (subText) {
        if ([subText isKindOfClass:[NSAttributedString class]]) {
            [cellView.subText setAttributedStringValue:(NSAttributedString *)subText];
        } else {
            cellView.subText.stringValue = subText ? (NSString *)subText : @"";
        }
    }

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
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        _lua_stackguard_entry(skin.L);
        NSDictionary *choice = [[self getChoices] objectAtIndex:row];

        if ([choice objectForKey:@"valid"] && ![[choice objectForKey:@"valid"] boolValue] && self.invalidCallbackRef != LUA_NOREF && self.invalidCallbackRef != LUA_REFNIL) {
            [skin pushLuaRef:self.refTable ref:self.invalidCallbackRef];
            [skin pushNSObject:choice];
            [skin protectedCallAndError:@"hs.chooser:invalidCallback" nargs:1 nresults:0];
        } else if (self.completionCallbackRef != LUA_NOREF && self.completionCallbackRef != LUA_REFNIL) {
            [self hide];
            [skin pushLuaRef:self.refTable ref:self.completionCallbackRef];
            [skin pushNSObject:choice];
            [skin protectedCallAndError:@"hs.chooser:completionCallback" nargs:1 nresults:0];
        }
        
        _lua_stackguard_exit(skin.L);
    }
}

- (void)didRightClickAtRow:(NSInteger)row {
    if (self.rightClickCallbackRef != LUA_NOREF && self.rightClickCallbackRef != LUA_REFNIL) {
        // We have a right click callback set
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:self.refTable ref:self.rightClickCallbackRef];
        lua_pushinteger(skin.L, row + 1);
        [skin protectedCallAndError:@"hs.chooser:rightClickCallback" nargs:1 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

#pragma mark - UI callbacks

- (IBAction)cancel:(id)sender {
    //NSLog(@"HSChooser::cancel:");
    [self hide];
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    _lua_stackguard_entry(skin.L);

    if (![skin checkRefs:self.refTable, self.completionCallbackRef, LS_RBREAK]) {
        [skin logWarn:@"Unable to call hs.chooser:completionCallback, reference is no longer valid"];
        _lua_stackguard_exit(skin.L);
        return;
    }

    [skin pushLuaRef:self.refTable ref:self.completionCallbackRef];
    lua_pushnil(skin.L);
    [skin protectedCallAndError:@"hs.chooser:completionCallback" nargs:1 nresults:0];
    _lua_stackguard_exit(skin.L);
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
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:self.refTable ref:self.queryChangedCallbackRef];
        [skin pushNSObject:queryString];
        [skin protectedCallAndError:@"hs.chooser:queryChangedCallback" nargs:1 nresults:0];
        _lua_stackguard_exit(skin.L);
    } else {
        // We do not have a query callback set, so we are doing the filtering
        if (queryString.length > 0) {
            NSMutableArray *filteredChoices = [[NSMutableArray alloc] init];

            for (NSDictionary *choice in [self getChoicesWithOptions:NO]) {
                NSString *text = [choice objectForKey:@"text"];
                if (text && ![text isKindOfClass:[NSString class]]) text = [NSString stringWithFormat:@"%@", text] ;
                if (!text) text = @"" ;
                if ([[text lowercaseString] containsString:[queryString lowercaseString]]) {
                    [filteredChoices addObject: choice];
                } else if (self.searchSubText) {
                    NSString *subText = [choice objectForKey:@"subText"];
                    if (subText && ![subText isKindOfClass:[NSString class]]) subText = [NSString stringWithFormat:@"%@", subText] ;
                    if (!subText) subText = @"" ;
                    if ([[subText lowercaseString] containsString:[queryString lowercaseString]]) {
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
        [LuaSkin logError:[NSString stringWithFormat:@"ERROR: unable to select row %li of %li", (long)row, (long)numRows]];
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

- (void)selectNextPage {
    NSInteger currentRow = [self.choicesTableView selectedRow];
	NSInteger count = [[self getChoices] count];
    if (currentRow == count-1) {
        [self selectChoice:0];
    } else if (currentRow >= count-10) {
        [self selectChoice:count-1];
    } else {
        [self selectChoice:currentRow+10];
    }
}

- (void)selectPreviousPage {
    NSInteger currentRow = [self.choicesTableView selectedRow];
    if (currentRow == 0) {
        [self selectChoice:[[self getChoices] count]-1];
    } else if (currentRow < 10) {
        [self selectChoice:0];
    } else {
        [self selectChoice:currentRow-10];
    }
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
            LuaSkin *skin = [LuaSkin sharedWithState:NULL];
            _lua_stackguard_entry(skin.L);
            [skin pushLuaRef:self.refTable ref:self.choicesCallbackRef];
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
                    [LuaSkin logError:@"ERROR: data returned by hs.chooser:choices() callback could not be parsed correctly"];
                    self.currentCallbackChoices = nil;
                }
            } else {
                [skin logError:[NSString stringWithFormat:@"%s:choices error - %@", USERDATA_TAG, [skin toNSObjectAtIndex:-1]]] ;
                // No need to lua_pop() here, see below
            }
            lua_pop(skin.L, 1) ; // remove result or error message
            _lua_stackguard_exit(skin.L);
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

- (void)applyDarkSetting:(BOOL)beDark {
    NSAppearance *appearance = beDark ? [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark] : [NSAppearance appearanceNamed:NSAppearanceNameVibrantLight];
    self.window.appearance = appearance;
}

- (void)setAutoBgLightDark {
    NSString *interfaceStyle = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    BOOL isDark = (interfaceStyle && [[interfaceStyle lowercaseString] isEqualToString:@"dark"]);

    [self applyDarkSetting:isDark];
}

- (void)setBgLightDark:(NSNotification *)notification {
    if (notification.object == nil) {
        self.isObservingThemeChanges = YES;
        [self setAutoBgLightDark];
        return;
    }
    self.isObservingThemeChanges = NO;

    [self applyDarkSetting:((NSNumber *)notification.object).boolValue];
}

- (BOOL)isBgLightDark {
    return [self.window.appearance.name isEqualToString:NSAppearanceNameVibrantDark];
}

#pragma mark - Utility methods

- (void) addShortcut:(NSString*)key keyCode:(unsigned short)keyCode mods:(NSEventModifierFlags)mods handler:(dispatch_block_t)action {
    //NSLog(@"Adding shortcut for %lu %@:%i", mods, key, keyCode);
    id x = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^ NSEvent*(NSEvent* event) {
        NSEventModifierFlags flags = ([event modifierFlags] & NSEventModifierFlagDeviceIndependentFlagsMask);
        //NSLog(@"Got an event: %lu %@:%i", (unsigned long)flags, [event charactersIgnoringModifiers], [[event charactersIgnoringModifiers] characterAtIndex:0]);

        if (flags == mods) {
            @try {
                if ([[event charactersIgnoringModifiers] isEqualToString: key] || [[event charactersIgnoringModifiers] characterAtIndex:0] == keyCode) {
                    //NSLog(@"firing action");
                    action();
                    return nil;
                }
            } @catch (NSException *exception) {
                ;
            } @finally {
                ;
            }
        }
        return event;
    }];
    [self.eventMonitors addObject: x];
}

#pragma mark - Interface theme changes observer

-(void)setIsObservingThemeChanges:(BOOL)isObservingThemeChanges {
    if (_isObservingThemeChanges == isObservingThemeChanges) {
        return;
    }

    _isObservingThemeChanges = isObservingThemeChanges;
    if (isObservingThemeChanges) {
        // Activate the observer.
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(setBgLightDark:) name:@"AppleInterfaceThemeChangedNotification" object:nil];
    } else {
        // Deactivate the observer.
        [[NSDistributedNotificationCenter defaultCenter] removeObserver:self name:@"AppleInterfaceThemeChangedNotification" object:nil];
    }
}

@end
