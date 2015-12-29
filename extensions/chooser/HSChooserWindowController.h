//
//  HSChooserWindowController.h
//  Hammerspoon
//
//  Created by Chris Jones on 29/12/2015.
//  Copyright © 2015 Hammerspoon. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface HSChooserWindowController : NSWindowController
@property (nonatomic, weak) IBOutlet NSTextField *queryField;
@property (nonatomic, weak) IBOutlet NSTableView *listTableView;

-(id)initWithOwner:(id)owner;
@end
