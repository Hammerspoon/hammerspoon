//
//  chooser.h
//  Hammerspoon
//
//  Created by Chris Jones on 27/12/2015.
//  Copyright © 2015 Hammerspoon. All rights reserved.
//

#pragma mark - Module metadata

#define USERDATA_TAG "hs.chooser"

static int refTable = LUA_NOREF;

typedef struct _chooser_userdata_t {
    int selfRef;
    void * _Nullable chooser;
} chooser_userdata_t;

#pragma mark - Chooser window definition

@interface HSChooserWindow : NSWindow
@end

#pragma mark - Chooser table definition
@interface HSChooserTableView : NSTableView
@end

#pragma mark - Chooser table cell definition
@interface HSChooserTableCellView : NSTableCellView
@property (unsafe_unretained) IBOutlet NSTextField * _Nullable shortcutTextField;
@property (unsafe_unretained) IBOutlet NSTextField * _Nullable subTextField;
@end

#pragma mark - Chooser definition
@interface HSChooser : NSObject <NSWindowDelegate, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate>
@property(nonatomic) NSInteger numRows;
@property(nonatomic) CGFloat width;

@property(nonatomic, retain) NSString * _Nullable fontName;
@property(nonatomic) CGFloat fontSize;
@property(nonatomic, retain) NSFont * _Nullable font;

@property(nonatomic) NSRect winRect;
@property(nonatomic) NSRect textRect;
@property(nonatomic) NSRect listRect;
@property(nonatomic) NSRect dividerRect;

@property(nonatomic, retain) HSChooserWindow * _Nullable window;
@property(nonatomic, retain) NSTextField * _Nullable queryField;
@property(nonatomic, retain) HSChooserTableView * _Nullable listTableView;

@property(nonatomic, retain) NSArray * _Nullable currentStaticChoices;
@property(nonatomic, retain) NSArray * _Nullable currentCallbackChoices;

@property(nonatomic) int choicesCallbackRef;
@property(nonatomic) int queryChangedCallbackRef;

// Initialiser
- (id _Nullable)initWithRows:(NSInteger)numRows width:(CGFloat)width fontName:(NSString * _Nullable)fontName fontSize:(CGFloat)fontSize;

// Setup/display related methods
- (void)calculateRects;
- (void)setupWindow;
- (void)setupQueryField;
- (void)setupResultsTable;

- (void)resizeWindow;
- (void)show;
- (void)hide;

// NSTableViewDataSource
- (NSInteger) numberOfRowsInTableView:(NSTableView * _Nullable)tableView;

// NSTableViewDelegate

// NSTextFieldDelgate

// NSWindowDelegate

// Actions
- (IBAction)chooseByDoubleClicking:(id _Nullable)sender;
- (IBAction)choose:(id _Nullable)sender;

// Choice related methods
- (void)updateChoices;
- (void)clearChoices;
- (void)clearChoicesAndUpdate;
- (NSArray * _Nullable)getChoices;
@end

#pragma mark - Lua API defines
static int userdata_gc(lua_State* L);