#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import "../Hammerspoon.h"
#import "chooser.h"

#pragma mark - Chooser object implementation

@implementation HSChooser
- (id)initWithRows:(NSInteger)numRows width:(CGFloat)width fontName:(NSString *)fontName fontSize:(CGFloat)fontSize {
    self = [super init];
    if (self) {
        self.numRows = numRows;
        self.width = width;
        self.fontName = fontName;
        self.fontSize = fontSize;

        self.currentStaticChoices = nil;
        self.currentCallbackChoices = nil;
        self.choicesCallbackRef = LUA_NOREF;
        self.queryChangedCallbackRef = LUA_NOREF;

        // Decide which font to use
        if (!self.fontName) {
            self.font = [NSFont systemFontOfSize:self.fontSize];
        } else {
            self.font = [NSFont fontWithName:self.fontName size:self.fontSize];
        }

        [self calculateRects];

        [self setupWindow];
        [self setupQueryField];
        [self setupDivider];
        [self setupResultsTable];
    }

    return self;
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

- (void)setupWindow {
    // Create and configure our window
    HSChooserWindow *window = [[HSChooserWindow alloc] initWithContentRect:self.winRect
                                                                 styleMask:(NSFullSizeContentViewWindowMask | NSTitledWindowMask)
                                                                   backing:NSBackingStoreBuffered
                                                                     defer:YES];
    self.window = window;

    window.titlebarAppearsTransparent = YES;
    NSVisualEffectView* blur = [[NSVisualEffectView alloc] initWithFrame: [[window contentView] bounds]];
    [blur setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable ];
    blur.material = NSVisualEffectMaterialLight;
    blur.state = NSVisualEffectBlendingModeBehindWindow;
    [[window contentView] addSubview: blur];
}

- (void)setupQueryField {
    // Create and configure the query field
    NSRect textRect, iconRect, space;

    textRect = self.textRect;
    NSDivideRect(textRect, &iconRect, &textRect, NSHeight(textRect) / 1.25, NSMinXEdge);
    NSDivideRect(textRect, &space, &textRect, 5.0, NSMinXEdge);
    self.textRect = textRect;

    CGFloat d = NSHeight(iconRect) * 0.10;
    iconRect = NSInsetRect(iconRect, d, d);

    NSImageView* icon = [[NSImageView alloc] initWithFrame: iconRect];
    [icon setAutoresizingMask: NSViewMaxXMargin | NSViewMinYMargin ];
    [icon setImage: [NSImage imageNamed:  NSImageNameRightFacingTriangleTemplate]];
    [icon setImageScaling: NSImageScaleProportionallyDown];
    //    [icon setImageFrameStyle: NSImageFrameButton];
    [[self.window contentView] addSubview: icon];

    NSTextField *queryField = [[NSTextField alloc] initWithFrame: textRect];
    self.queryField = queryField;

    [queryField setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin ];
    [queryField setDelegate: self];
    [queryField setBezelStyle: NSTextFieldSquareBezel];
    [queryField setBordered: NO];
    [queryField setDrawsBackground: NO];
    [queryField setFocusRingType: NSFocusRingTypeNone];
    [queryField setFont: self.font];
    [queryField setEditable: YES];
    [queryField setTarget: self];
    [queryField setAction: @selector(choose:)];
    [[queryField cell] setSendsActionOnEndEditing: NO];
    [[self.window contentView] addSubview: self.queryField];
}

- (void)setupDivider {
    NSBox* border = [[NSBox alloc] initWithFrame: self.dividerRect];
    [border setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin ];
    [border setBoxType: NSBoxCustom];
    [border setFillColor: [NSColor lightGrayColor]];
    [border setBorderWidth: 0.0];
    [[self.window contentView] addSubview: border];
}

- (void)setupResultsTable {
    NSFont* rowFont = [NSFont fontWithName:[self.font fontName] size: [self.font pointSize] * 0.70];

    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"thing"]; // FIXME: "thing" is not cool
    [col setEditable: NO];
    [col setWidth: 10000];
    [[col dataCell] setFont: rowFont];

    NSTextFieldCell* cell = [col dataCell];
    [cell setLineBreakMode: NSLineBreakByCharWrapping];

    self.listTableView = [[HSChooserTableView alloc] init];
    [self.listTableView setDataSource: self];
    [self.listTableView setDelegate: self];
    [self.listTableView setBackgroundColor: [NSColor clearColor]];
    [self.listTableView setHeaderView: nil];
    [self.listTableView setAllowsEmptySelection: NO];
    [self.listTableView setAllowsMultipleSelection: NO];
    [self.listTableView setAllowsTypeSelect: NO];
    [self.listTableView setRowSizeStyle:NSTableViewRowSizeStyleCustom];
    [self.listTableView setRowHeight: (CGFloat)40.0];
    [self.listTableView addTableColumn:col];
    [self.listTableView setTarget: self];
    [self.listTableView setDoubleAction: @selector(chooseByDoubleClicking:)];
    [self.listTableView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];

    NSScrollView* listScrollView = [[NSScrollView alloc] initWithFrame: self.listRect];
    [listScrollView setVerticalScrollElasticity: NSScrollElasticityAutomatic];
    [listScrollView setAutoresizingMask: NSViewHeightSizable | NSViewWidthSizable ];
    [listScrollView setDocumentView: self.listTableView];
    [listScrollView setDrawsBackground: NO];

    [[self.window contentView] addSubview: listScrollView];
}

- (void)resizeWindow {
    NSRect screenFrame = [[NSScreen mainScreen] visibleFrame];

    CGFloat rowHeight = [self.listTableView rowHeight];
    CGFloat intercellHeight =[self.listTableView intercellSpacing].height;
    CGFloat allRowsHeight = (rowHeight + intercellHeight) * self.numRows;

    CGFloat windowHeight = NSHeight([[self.window contentView] bounds]);
    CGFloat tableHeight = NSHeight([[self.listTableView superview] frame]);
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
    [self.listTableView setFrameSize:NSMakeSize(winRect.size.width, self.listTableView.frame.size.height)];
}

- (void)show {
    [self resizeWindow];

    self.window.isVisible = YES;
    [self.window center];
    [self.window makeKeyAndOrderFront:nil];

    [self updateChoices];
}

- (void)hide {
    self.window.isVisible = NO;
}

- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView {
    NSInteger rowCount = 0;
    NSArray *choices = [self getChoices];

    if (choices) {
        rowCount = choices.count;
    }

    NSLog(@"numberOfRowsInTableView: returning %ld", (long)rowCount);
    return rowCount;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSArray *choices = [self getChoices];
    NSDictionary *choice = [choices objectAtIndex:row];

    HSChooserTableCellView *cellView = [tableView makeViewWithIdentifier:@"HSChooserTableCellView" owner:self];

    //cellView.backgroundStyle = NSBackgroundStyleDark;
    NSString *text         = [choice objectForKey:@"text"];
    NSString *subText      = [choice objectForKey:@"subText"];
    NSString *shortcutText = @"";

    if (row >= 0 && row < 9) {
        shortcutText = [NSString stringWithFormat:@"⌘%ld", (long)row + 1];
    }

    cellView.textField.stringValue = text;
    cellView.subTextField.stringValue = subText;
    cellView.shortcutTextField.stringValue = shortcutText;
    cellView.imageView.image = [NSImage imageNamed:NSImageNameFollowLinkFreestandingTemplate];

    return cellView;
}

/*
- (id) tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSArray *choices = [self getChoices];
    NSDictionary *choice = [choices objectAtIndex:row];

    return [choice objectForKey:@"text"];
}
 */

- (IBAction)choose:(id)sender {
    NSLog(@"in choose:");
}

- (IBAction)chooseByDoubleClicking:(id)sender {
    NSLog(@"in chooseByDoubleClicking:");
}

- (void)updateChoices {
    [self.listTableView reloadData];
}

- (void)clearChoices {
    self.currentStaticChoices = nil;
    self.currentCallbackChoices = nil;
}

- (void)clearChoicesAndUpdate {
    [self clearChoices];
    [self updateChoices];
}

- (NSArray *)getChoices {
    NSArray *choices = nil;

    if (self.choicesCallbackRef == LUA_NOREF) {
        // No callback is set, we can only return the static choices, even if it's nil
        choices = self.currentStaticChoices;
    } else if (self.choicesCallbackRef != LUA_NOREF) {
        // We have a callback set
        if (!self.currentCallbackChoices) {
            // We have previously cached the callback choices
            LuaSkin *skin = [LuaSkin shared];
            [skin pushLuaRef:refTable ref:self.choicesCallbackRef];
            if ([skin protectedCallAndTraceback:0 nresults:1]) {
                self.currentCallbackChoices = [skin toNSObjectAtIndex:-1];
            } else {
                self.currentCallbackChoices = nil;
            }
        }
        choices = self.currentCallbackChoices;
    }
    return choices;
}
@end

#pragma mark - Chooser window implementation
@implementation HSChooserWindow
- (BOOL) canBecomeKeyWindow  { return YES; }
- (BOOL) canBecomeMainWindow { return YES; }
@end

#pragma mark - Chooser tableview implementation
@implementation HSChooserTableView

- (id) initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        NSNib *cellNib = [[NSNib alloc] initWithNibNamed:@"HSChooserTableCellView" bundle:nil];
        [self registerNib:cellNib forIdentifier:@"HSChooserTableCellView"];
    }
    return self;
}
- (BOOL) acceptsFirstResponder { return NO; }
- (BOOL) becomeFirstResponder  { return NO; }
- (BOOL) canBecomeKeyView      { return NO; }

@end

#pragma mark - Chooser tableview cell implementation
@implementation HSChooserTableCellView
@end

#pragma mark - Lua API - Constructors

/// hs.chooser.new(numRows, width[, fontName[, fontSize]]) -> hs.chooser object
/// Constructor
/// Creates a new chooser object
///
/// Parameters:
///  * numRows - The number of results rows to show
///  * width - The width of the chooser window as a percentage of the main screen's width
///  * fontName - An optional font name to use
///  * fontSize - An optional floating point font size to use
///
/// Returns:
///  * An `hs.chooser` object
///
/// Notes:
///  * You can get a list of available font names with `hs.styledtext.fontNames()`
static int chooserNew(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TNUMBER, LS_TNUMBER, LS_TSTRING|LS_TNUMBER|LS_TOPTIONAL, LS_TNUMBER|LS_TOPTIONAL, LS_TBREAK];

    // Create the userdata object
    chooser_userdata_t *userData = lua_newuserdata(L, sizeof(chooser_userdata_t));
    memset(userData, 0, sizeof(chooser_userdata_t));
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    // Parse function arguents
    NSInteger numRows = (NSInteger)lua_tointeger(L, 1);
    CGFloat width = (CGFloat)lua_tonumber(L, 2);

    NSString *chooseFontName = nil;
    CGFloat chooseFontSize = 0.0;

    if (lua_type(L, 3) == LUA_TSTRING) {
        chooseFontName = [skin toNSObjectAtIndex:3];
    } else if (lua_type(L, 3) == LUA_TNUMBER) {
        chooseFontSize = (CGFloat)lua_tonumber(L, 3);
    }
    if (lua_type(L, 4) == LUA_TNUMBER) {
        chooseFontSize = (CGFloat)lua_tonumber(L, 4);
    }

    // Create the HSChooser object with our arguments
    HSChooser *chooser = [[HSChooser alloc] initWithRows:numRows width:width fontName:chooseFontName fontSize:chooseFontSize];
    userData->chooser = (__bridge_retained void*)chooser;

    return 1;
}

#pragma mark - Lua API - Methods

/// hs.chooser:show() -> hs.chooser object
/// Method
/// Displays the chooser
///
/// Parameters:
///  * Nonw
///
/// Returns:
///  * The hs.chooser object
static int chooserShow(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

    [chooser show];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:hide() -> hs.chooser object
/// Method
/// Hides the chooser
///
/// Parameters:
///  * None
///
/// Returns:
///  * The hs.chooser object
static int chooserHide(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

    [chooser hide];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:setChoices(choices) -> hs.chooser object
/// Method
/// Sets the choices for a chooser
///
/// Parameters:
///  * choices - Either a function to call when the list of choices is needed, or a table containing static choices, or nil to remove any existing choices
///
/// Returns:
///  * The hs.chooser object
static int chooserSetChoices(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TTABLE | LS_TNIL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

    [chooser clearChoices];

    switch (lua_type(L, 2)) {
        case LUA_TNIL:
            break;

        case LUA_TFUNCTION:
            chooser.choicesCallbackRef = [skin luaRef:refTable atIndex:2];
            break;

        case LUA_TTABLE:
            chooser.choicesCallbackRef = [skin luaUnref:refTable ref:chooser.choicesCallbackRef];
            chooser.currentStaticChoices = [skin toNSObjectAtIndex:2];
            break;

        default:
            NSLog(@"Unknown type in chooserSetChoices. This should be impossible");
            break;
    }

    [chooser updateChoices];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:queryChangedCallback([fn]) -> hs.chooser object
/// Method
/// Sets/clears a callback for when the search query changes
///
/// Parameters:
///  * fn - An optional function that will be called whenever the search query changes. The function should accept a single argument, a string containing the new search query. It should return nothing. If this parameter is omitted, the existing callback will be removed
///
/// Returns:
///  * The hs.chooser object
static int chooserQueryCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION|LS_TOPTIONAL, LS_TBREAK];

    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge HSChooser *)userData->chooser;

    chooser.queryChangedCallbackRef = [skin luaUnref:refTable ref:chooser.queryChangedCallbackRef];
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        chooser.queryChangedCallbackRef = [skin luaRef:refTable atIndex:2];
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.chooser:delete()
/// Method
/// Deletes a chooser
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int chooserDelete(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    return userdata_gc(L);
}

#pragma mark - Hammerspoon Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    chooser_userdata_t *userData = lua_touserdata(L, 1);
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, userData]];
    return 1;
}

static int userdata_gc(lua_State* L) {
    chooser_userdata_t *userData = lua_touserdata(L, 1);
    HSChooser *chooser = (__bridge_transfer HSChooser *)userData->chooser;
    userData->chooser = nil;
    chooser = nil;

    return 0;
}

static const luaL_Reg chooserLib[] = {
    {"new", chooserNew},

    {NULL, NULL}
};

// Metatable for userdata objects
static const luaL_Reg userdataLib[] = {
    {"show", chooserShow},
    {"hide", chooserHide},
    {"choices", chooserSetChoices},
    {"queryChangedCallback", chooserQueryCallback},
    {"delete", chooserDelete},

    {"__tostring", userdata_tostring},
    {"__gc", userdata_gc},
    {NULL, NULL}
};

int luaopen_hs_chooser_internal(__unused lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:chooserLib
                                 metaFunctions:nil // metalib
                               objectFunctions:userdataLib];

    return 1;
}
