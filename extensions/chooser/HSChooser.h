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
#import "HSChooserWindowController.h"
#import "HSChooserWindow.h"
#import "HSChooserTableView.h"
#import "HSChooserCell.h"

#pragma mark - Chooser definition
@interface HSChooser : NSObject <NSWindowDelegate, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate, HSChooserTableViewDelegate>
@property(nonatomic) NSInteger numRows;
@property(nonatomic) CGFloat width;

@property(nonatomic, retain) NSString *fontName;
@property(nonatomic) CGFloat fontSize;
@property(nonatomic, retain) NSFont *font;

@property(nonatomic) NSRect winRect;
@property(nonatomic) NSRect textRect;
@property(nonatomic) NSRect listRect;
@property(nonatomic) NSRect dividerRect;

@property(nonatomic, retain) HSChooserWindowController *windowController;
@property(nonatomic, weak) IBOutlet HSChooserWindow *window;

@property(nonatomic, retain) NSArray *currentStaticChoices;
@property(nonatomic, retain) NSArray *currentCallbackChoices;

@property(nonatomic) int choicesCallbackRef;
@property(nonatomic) int queryChangedCallbackRef;

@property(nonatomic) int *refTable;

// Initialiser
- (id)initWithRows:(NSInteger)numRows width:(CGFloat)width fontName:(NSString *)fontName fontSize:(CGFloat)fontSize refTable:(int *)refTable;

// Setup/display related methods
- (void)calculateRects;
- (BOOL)setupWindow;

- (void)resizeWindow;
- (void)show;
- (void)hide;

// NSTableViewDataSource
- (NSInteger) numberOfRowsInTableView:(NSTableView *)tableView;

// NSTableViewDelegate

// NSTextFieldDelgate

// Actions
- (IBAction)queryDidPressEnter:(id)sender;

// Choice related methods
- (void)updateChoices;
- (void)clearChoices;
- (void)clearChoicesAndUpdate;
- (NSArray *)getChoices;
@end
