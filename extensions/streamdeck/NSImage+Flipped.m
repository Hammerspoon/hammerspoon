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
    CGFloat xTrans = horiz ? existingSize.width : 0.0;
    CGFloat yTrans = vert ? existingSize.height : 0.0;
    CGFloat xScale = horiz ? -1.0 : 1.0;
    CGFloat yScale = vert ? -1.0 : 1.0;

    //NSLog(@"Flipping with xTrans,yTrans: %.1f,%.1f. xScale,yScale: %.1f,%.1f", xTrans, yTrans, xScale, yScale);

    [t translateXBy:xTrans yBy:yTrans];
    [t scaleXBy:xScale yBy:yScale];

    [t concat];

    [existingImage drawAtPoint:NSZeroPoint
                      fromRect:NSMakeRect(0, 0, newSize.width, newSize.height)
                     operation:NSCompositingOperationSourceOver
                      fraction:1.0];

    [flipedImage unlockFocus];

    return flipedImage;
}

@end

