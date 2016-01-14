//
//  HSChooserTableView.m
//  Hammerspoon
//
//  Created by Chris Jones on 30/12/2015.
//  Copyright © 2015 Hammerspoon. All rights reserved.
//

#import "HSChooserTableView.h"

@implementation HSChooserTableView

- (void)mouseDown:(NSEvent *)theEvent {

    NSPoint globalLocation = [theEvent locationInWindow];
    NSPoint localLocation = [self convertPoint:globalLocation fromView:nil];
    NSInteger clickedRow = [self rowAtPoint:localLocation];

    [super mouseDown:theEvent];

    if (clickedRow != -1 && [self.extendedDelegate respondsToSelector:@selector(tableView:didClickedRow:)]) {
        [self.extendedDelegate tableView:self didClickedRow:clickedRow];
    }
}

@end
