//
//  NSImage+Flipped.m
//  streamdeck
//
//  Created by Chris Jones on 25/11/2019.
//  Copyright © 2019 Hammerspoon. All rights reserved.
//

#import "NSImage+Flipped.h"

@implementation NSImage (Flipped)

- (NSImage *)flipImage:(BOOL)horiz vert:(BOOL)vert {
    if (!horiz && !vert) return self;

    NSImage *existingImage = self;
    NSSize existingSize = [existingImage size];
    NSSize newSize = NSMakeSize(existingSize.width, existingSize.height);
    NSImage *flipedImage = [[NSImage alloc] initWithSize:newSize];

    [flipedImage lockFocus];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];

    NSAffineTransform *t = [NSAffineTransform transform];
    CGFloat xTrans = horiz ? 0 : existingSize.width;
    CGFloat yTrans = vert ? 0 : existingSize.height;

    [t translateXBy:xTrans yBy:yTrans];
    [t scaleXBy:horiz ? 1 : -1 yBy:vert ? 1 : -1];

    [t concat];

    [existingImage drawAtPoint:NSZeroPoint fromRect:NSMakeRect(0, 0, newSize.width, newSize.height) operation:NSCompositingOperationSourceOver fraction:1.0];

    [flipedImage unlockFocus];

    return flipedImage;
}

@end

