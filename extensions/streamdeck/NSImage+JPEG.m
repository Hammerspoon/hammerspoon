//
//  NSImage+JPEG.m
//  streamdeck
//
//  Created by Chris Jones on 28/11/2019.
//  Copyright © 2019 Hammerspoon. All rights reserved.
//

#import "NSImage+JPEG.h"

@implementation NSImage (JPEG)

- (NSData *)jpegData {
    return [self jpegDataWithCompressionFactor:100.0];
}

- (NSData *)jpegDataWithCompressionFactor:(CGFloat)compressionFactor {
    NSBitmapImageRep *bitmapImageRep = [[NSBitmapImageRep alloc]
                                        initWithBitmapDataPlanes:NULL
                                        pixelsWide:self.size.width
                                        pixelsHigh:self.size.height
                                        bitsPerSample:8
                                        samplesPerPixel:4
                                        hasAlpha:YES
                                        isPlanar:NO
                                        colorSpaceName:NSCalibratedRGBColorSpace
                                        bytesPerRow:self.size.width * 4
                                        bitsPerPixel:32];

    NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithBitmapImageRep:bitmapImageRep];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:ctx];

    // Draw a black background
    NSColor *black = [NSColor blackColor];
    [black drawSwatchInRect:NSMakeRect(0, 0, self.size.width, self.size.height)];

    // Render our image into the bitmaprep
    [self drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0];
    [ctx flushGraphics];

    [NSGraphicsContext restoreGraphicsState];

    NSData *data = [bitmapImageRep representationUsingType:NSBitmapImageFileTypeJPEG
                                                properties:@{NSImageCompressionFactor: @(compressionFactor)}];
    return data;
}
@end
