//
//  HSChooserWindowController.h
//  Hammerspoon
//
//  Created by Chris Jones on 29/12/2015.
//  Copyright © 2015 Hammerspoon. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "HSChooserTableView.h"

@interface HSChooserWindowController : NSWindowController
@property (nonatomic, weak) id delegate;
@property (nonatomic, weak) IBOutlet NSTextField *queryField;
@property (nonatomic, weak) IBOutlet HSChooserTableView *listTableView;
@property (nonatomic, strong) NSMutableArray *eventMonitors;

-(id)initWithOwner:(id)owner;
@end
