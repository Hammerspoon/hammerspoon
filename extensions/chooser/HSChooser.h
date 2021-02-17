//
//  HSChooser.h
//  Hammerspoon
//
//  Created by Chris Jones on 29/12/2015.
//  Copyright © 2015 Hammerspoon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import "HSChooserWindow.h"
#import "HSChooserTableView.h"
#import "HSChooserCell.h"

#pragma mark - Chooser definition
@interface HSChooser : NSWindowController <NSWindowDelegate, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, HSChooserTableViewDelegate>

@property (nonatomic, weak) IBOutlet NSTextField *queryField;
@property (nonatomic, weak) IBOutlet HSChooserTableView *choicesTableView;
@property (nonatomic, weak) IBOutlet NSVisualEffectView *effectView;

@property (nonatomic, strong) NSMutableArray *eventMonitors;
@property (nonatomic) BOOL hasChosen;
@property (nonatomic) BOOL reloadWhenVisible;

// Customisable options
@property(nonatomic) NSInteger numRows;
@property(nonatomic) CGFloat width;
@property(nonatomic, retain) NSString *fontName;
@property(nonatomic) CGFloat fontSize;
@property(nonatomic) BOOL searchSubText;
@property(nonatomic) NSColor *fgColor;
@property(nonatomic) NSColor *subTextColor;

@property(nonatomic, retain) NSFont *font;

// Size information we calculate for ourselves
@property(nonatomic) NSRect winRect;
@property(nonatomic) NSRect textRect;
@property(nonatomic) NSRect listRect;
@property(nonatomic) NSRect dividerRect;

// Storage for different types of choice
@property(nonatomic, retain) NSArray *currentStaticChoices;
@property(nonatomic, retain) NSArray *currentCallbackChoices;
@property(nonatomic, retain) NSArray *filteredChoices;

// Lua callback references
@property(nonatomic) int hideCallbackRef;
@property(nonatomic) int showCallbackRef;
@property(nonatomic) int choicesCallbackRef;
@property(nonatomic) int queryChangedCallbackRef;
@property(nonatomic) int completionCallbackRef;
@property(nonatomic) int rightClickCallbackRef;
@property(nonatomic) int invalidCallbackRef;

// A pointer to the hs.chooser module's references table
@property(nonatomic) LSRefTable refTable;

// Our self-ref count
@property(nonatomic) int selfRefCount;

// Keep track of whether we are observing macOS interface theme (light/dark)
@property(nonatomic) BOOL isObservingThemeChanges;

// Initialiser
- (id)initWithRefTable:(LSRefTable )refTable completionCallbackRef:(int)completionCallbackRef;

// Setup/display related methods
- (void)calculateRects;
- (BOOL)setupWindow;

- (void)resizeWindow;
- (void)show;
- (void)showAtPoint:(NSPoint)topLeft;
- (void)showWithHints:(BOOL)center atPoint:(NSPoint)topLeft;
- (void)hide;
- (BOOL)isVisible;

// NSTableViewDataSource
- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView;

// HSChooserTableViewDelegate
- (void)tableView:(NSTableView *)tableView didClickedRow:(NSInteger)row;
- (void)didRightClickAtRow:(NSInteger)row;

// NSTextFieldDelgate

// Actions
- (IBAction)queryDidPressEnter:(id)sender;
- (IBAction)cancel:(id)sender;

// Choice related methods
- (void)updateChoices;
- (void)clearChoices;
- (void)clearChoicesAndUpdate;
- (NSArray *)getChoices;
- (NSArray *)getChoicesWithOptions:(BOOL)includeFiltered;

// UI customisation methods
- (void)setBgLightDark:(NSNotification *)notification;
- (BOOL)isBgLightDark;
@end
