//
//  NSScreenProxy.m
//  Zephyros
//
//  Created by Steven on 4/14/13.
//  Copyright (c) 2013 Giant Robot Software. All rights reserved.
//

#import "NSScreen+PHExtension.h"

@implementation NSScreen (PHExtension)

- (CGRect) frameIncludingDockAndMenu {
    NSScreen* primaryScreen = [[NSScreen screens] objectAtIndex:0];
    CGRect f = [self frame];
    f.origin.y = NSHeight([primaryScreen frame]) - NSHeight(f) - f.origin.y;
    return f;
}

- (CGRect) frameWithoutDockOrMenu {
    NSScreen* primaryScreen = [[NSScreen screens] objectAtIndex:0];
    CGRect f = [self visibleFrame];
    f.origin.y = NSHeight([primaryScreen frame]) - NSHeight(f) - f.origin.y;
    return f;
}

- (NSScreen*) nextScreen {
    NSArray* screens = [NSScreen screens];
    NSUInteger idx = [screens indexOfObject:self];

    idx += 1;
    if (idx == [screens count])
        idx = 0;

    return [screens objectAtIndex:idx];
}

- (NSScreen*) previousScreen {
    NSArray* screens = [NSScreen screens];
    NSUInteger idx = [screens indexOfObject:self];

    idx -= 1;
    if (idx == -1)
        idx = [screens count] - 1;

    return [screens objectAtIndex:idx];
}

@end
