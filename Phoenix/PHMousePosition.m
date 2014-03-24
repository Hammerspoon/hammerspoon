//
//  PHMousePosition.m
//  Phoenix
//
//  Created by Steven Degutis on 3/24/14.
//  Copyright (c) 2014 Steven. All rights reserved.
//

#import "PHMousePosition.h"

@implementation PHMousePosition

+ (NSPoint) capture {
    CGEventRef ourEvent = CGEventCreate(NULL);
    return CGEventGetLocation(ourEvent);
}

+ (void) restore:(NSPoint)p {
    CGWarpMouseCursorPosition(p);
}

@end
