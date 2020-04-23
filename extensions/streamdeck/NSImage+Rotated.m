//
//  NSImage+Rotated.m
//  streamdeck
//
//  Created by Chris Jones on 25/11/2019.
//  Copyright © 2019 Hammerspoon. All rights reserved.
//

#import "NSImage+Rotated.h"

@implementation NSImage (Rotated)
- (NSImage *)imageRotated:(int)degrees {
    if (0 == degrees) {
        return self;
    }
    if (0 != fmod(degrees,90.)) {
        NSLog( @"This code has only been tested for multiples of 90 degrees. (TODO: test and remove this line)");
    }
    degrees = fmod(degrees, 360.);

    NSSize size = [self size];
    NSSize maxSize;
    if (90 == degrees || 270 == degrees || -90 == degrees || -270 == degrees) {
        maxSize = NSMakeSize(size.height, size.width);
    } else if (180 == degrees || -180 == degrees) {
        maxSize = size;
    } else {
        maxSize = NSMakeSize(20+MAX(size.width, size.height), 20+MAX(size.width, size.height));
    }
    NSAffineTransform *rot = [NSAffineTransform transform];
    [rot rotateByDegrees:degrees];
    NSAffineTransform *center = [NSAffineTransform transform];
    [center translateXBy:maxSize.width / 2. yBy:maxSize.height / 2.];
    [rot appendTransform:center];
    NSImage *image = [[NSImage alloc] initWithSize:maxSize];
    [image lockFocus];
    [rot concat];
    NSRect rect = NSMakeRect(0, 0, size.width, size.height);
    NSPoint corner = NSMakePoint(-size.width / 2., -size.height / 2.);
    [self drawAtPoint:corner fromRect:rect operation:NSCompositingOperationCopy fraction:1.0];
    [image unlockFocus];
    return image;
}
@end
