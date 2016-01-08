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
        // Nothing at the momennt
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

@end
