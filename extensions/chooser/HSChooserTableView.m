//
//  HSChooserTableView.m
//  Hammerspoon
//
//  Created by Chris Jones on 30/12/2015.
//  Copyright © 2015 Hammerspoon. All rights reserved.
//

#import "HSChooserTableView.h"

@implementation HSChooserTableView

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        self.trackingArea = [[NSTrackingArea alloc] initWithRect:self.frame options:(NSTrackingActiveInKeyWindow|NSTrackingMouseMoved) owner:self userInfo:nil];
        [self addTrackingArea:self.trackingArea];
        self.lastHoveredRow = -1;
    }
    return self;
}

- (void)updateTrackingAreas {
    [self removeTrackingArea:self.trackingArea];
    self.trackingArea = [[NSTrackingArea alloc] initWithRect:self.frame options:(NSTrackingMouseMoved|NSTrackingActiveInKeyWindow) owner:self userInfo:nil];
    [self addTrackingArea:self.trackingArea];
}

- (void)mouseDown:(NSEvent *)theEvent {
    NSPoint globalLocation = [theEvent locationInWindow];
    NSPoint localLocation = [self convertPoint:globalLocation fromView:nil];
    NSInteger clickedRow = [self rowAtPoint:localLocation];

    [super mouseDown:theEvent];

    if (clickedRow != -1 && [self.extendedDelegate respondsToSelector:@selector(tableView:didClickedRow:)]) {
        [self.extendedDelegate tableView:self didClickedRow:clickedRow];
    }
}

- (void)mouseMoved:(NSEvent *)theEvent {
    NSPoint globalLocation = [theEvent locationInWindow];
    NSPoint localLocation = [self convertPoint:globalLocation fromView:nil];
    NSInteger row = [self rowAtPoint:localLocation];

    [super mouseMoved:theEvent];

    if (row != -1 && row != self.lastHoveredRow) {
        self.lastHoveredRow = row;
        [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
        [self scrollRowToVisible:row];
    }
}

- (void)rightMouseDown:(NSEvent *)theEvent {
    if ([self.extendedDelegate respondsToSelector:@selector(didRightClickAtRow:)]) {
        NSPoint globalLocation = [theEvent locationInWindow];
        NSPoint localLocation = [self convertPoint:globalLocation fromView:nil];
        NSInteger row = [self rowAtPoint:localLocation];
        [self.extendedDelegate didRightClickAtRow:row];
    }
}

- (BOOL) allowsVibrancy {
    return NO;
}

@end
