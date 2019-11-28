//
//  NSImage+BMP.m
//  Hammerspoon
//
// Copyright 1997-2017 Omni Development, Inc. All rights reserved.
//
// 	Omni Source License 2007
// OPEN PERMISSION TO USE AND REPRODUCE OMNI SOURCE CODE SOFTWARE
// Omni Source Code software is available from The Omni Group on their web site at http://www.omnigroup.com/
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// Any original copyright notices and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "NSImage+BMP.h"

@implementation NSImage (BMP)

- (NSImageRep *)imageRepOfClass:(Class)imageRepClass{
    for (NSImageRep *rep in [self representations])
        if ([rep isKindOfClass:imageRepClass])
            return rep;
    return nil;
}

- (NSData *)bmpData {
    return [self bmpDataWithBackgroundColor:nil];
}

- (NSData *)bmpDataWithBackgroundColor:(NSColor *)backgroundColor {
    /* 	This is a Unix port of the bitmap.c code that writes .bmp files to disk.
     It also runs on Win32, and should be easy to get to run on other platforms.
     Please visit my web page, http://www.ece.gatech.edu/~slabaugh and click on "c" and "Writing Windows Bitmaps" for a further explanation.  This code has been tested and works on HP-UX 11.00 using the cc compiler.  To compile, just type "cc -Ae bitmapUnix.c" at the command prompt.
     The Windows .bmp format is little endian, so if you're running this code on a big endian system it will be necessary to swap bytes to write out a little endian file.
     Thanks to Robin Pitrat for testing on the Linux platform.
     Greg Slabaugh, 11/05/01
     */


    // This pragma is necessary so that the data in the structures is aligned to 2-byte boundaries.  Some different compilers have a different syntax for this line.  For example, if you're using cc on Solaris, the line should be #pragma pack(2).
#pragma pack(2)

    // Default data types.  Here, uint16 is an unsigned integer that has size 2 bytes (16 bits), and uint32 is datatype that has size 4 bytes (32 bits).  You may need to change these depending on your compiler.
#define uint16 unsigned short
#define uint32 unsigned int

#define BI_RGB 0
#define BM 19778

    typedef struct {
        uint16 bfType;
        uint32 bfSize;
        uint16 bfReserved1;
        uint16 bfReserved2;
        uint32 bfOffBits;
    } BITMAPFILEHEADER;

    typedef struct {
        uint32 biSize;
        uint32 biWidth;
        uint32 biHeight;
        uint16 biPlanes;
        uint16 biBitCount;
        uint32 biCompression;
        uint32 biSizeImage;
        uint32 biXPelsPerMeter;
        uint32 biYPelsPerMeter;
        uint32 biClrUsed;
        uint32 biClrImportant;
    } BITMAPINFOHEADER;

    // CMSJ HAX BEGINS
    // This originally used NSImage to decide the size, but that turns out to produce @2x images on a retina Mac.
    // I've replaced it with an explicitly created NSBitmapImageRep that is set to the actual pixel size we need

    /*
    NSBitmapImageRep *bitmapImageRep = (id)[self imageRepOfClass:[NSBitmapImageRep class]];
    if (bitmapImageRep == nil || backgroundColor != nil) {
        NSRect imageBounds = {NSZeroPoint, [self size]};
        NSImage *newImage = [[NSImage alloc] initWithSize:imageBounds.size];
        [newImage lockFocus]; {
            [backgroundColor ? backgroundColor : [NSColor clearColor] set];
            NSRectFill(imageBounds);
            [self drawInRect:imageBounds fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:(CGFloat)1.0f];
            bitmapImageRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:imageBounds];
        } [newImage unlockFocus];
    }
     */

    // Create an NSBitmapImageRep locked to our size
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

    // Render our image into the bitmaprep
    [self drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:1.0];
    [ctx flushGraphics];

    [NSGraphicsContext restoreGraphicsState];
    // CMSJ HAX ENDS

    // Can't export huge images; these are NSInteger
    assert([bitmapImageRep pixelsWide] < INT32_MAX);
    assert([bitmapImageRep pixelsHigh] < INT32_MAX);

    uint32 width = (uint32)[bitmapImageRep pixelsWide];
    uint32 height = (uint32)[bitmapImageRep pixelsHigh];
    unsigned char *image = [bitmapImageRep bitmapData];
    uint32 samplesPerPixel = (uint32)[bitmapImageRep samplesPerPixel];

    /*
     This function writes out a 24-bit Windows bitmap file that is readable by Microsoft Paint.
     The image data is a 1D array of (r, g, b) triples, where individual (r, g, b) values can
     each take on values between 0 and 255, inclusive.
     The input to the function is:
     uint32 width:					The width, in pixels, of the bitmap
     uint32 height:					The height, in pixels, of the bitmap
     unsigned char *image:				The image data, where each pixel is 3 unsigned chars (r, g, b)
     Written by Greg Slabaugh (slabaugh@ece.gatech.edu), 10/19/00
     */
    uint32 extrabytes = (4 - (width * 3) % 4) % 4;

    /* This is the size of the padded bitmap */
    uint32 bytesize = (width * 3 + extrabytes) * height;

    NSMutableData *mutableBMPData = [NSMutableData data];

    /* Fill the bitmap file header structure */
    BITMAPFILEHEADER bmpFileHeader;
    bmpFileHeader.bfType = NSSwapHostShortToLittle(BM);   /* Bitmap header */
    bmpFileHeader.bfSize = NSSwapHostIntToLittle(0);      /* This can be 0 for BI_RGB bitmaps */
    bmpFileHeader.bfReserved1 = NSSwapHostShortToLittle(0);
    bmpFileHeader.bfReserved2 = NSSwapHostShortToLittle(0);
    bmpFileHeader.bfOffBits = NSSwapHostIntToLittle(sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER));
    [mutableBMPData appendBytes:&bmpFileHeader length:sizeof(BITMAPFILEHEADER)];

    /* Fill the bitmap info structure */
    BITMAPINFOHEADER bmpInfoHeader;
    bmpInfoHeader.biSize = NSSwapHostIntToLittle(sizeof(BITMAPINFOHEADER));
    bmpInfoHeader.biWidth = NSSwapHostIntToLittle(width);
    bmpInfoHeader.biHeight = NSSwapHostIntToLittle(height);
    bmpInfoHeader.biPlanes = NSSwapHostShortToLittle(1);
    bmpInfoHeader.biBitCount = NSSwapHostShortToLittle(24);            /* 24 - bit bitmap */
    bmpInfoHeader.biCompression = NSSwapHostIntToLittle(BI_RGB);
    bmpInfoHeader.biSizeImage = NSSwapHostIntToLittle(bytesize);     /* includes padding for 4 byte alignment */
    bmpInfoHeader.biXPelsPerMeter = NSSwapHostIntToLittle(0);
    bmpInfoHeader.biYPelsPerMeter = NSSwapHostIntToLittle(0);
    bmpInfoHeader.biClrUsed = NSSwapHostIntToLittle(0);
    bmpInfoHeader.biClrImportant = NSSwapHostIntToLittle(0);
    [mutableBMPData appendBytes:&bmpInfoHeader length:sizeof(BITMAPINFOHEADER)];

    /* Allocate memory for some temporary storage */
    unsigned char *paddedImage = (unsigned char *)calloc(sizeof(unsigned char), bytesize);

    // This code does three things.  First, it flips the image data upside down, as the .bmp format requires an upside down image.  Second, it pads the image data with extrabytes number of bytes so that the width in bytes of the image data that is written to the file is a multiple of 4.  Finally, it swaps (r, g, b) for (b, g, r).  This is another quirk of the .bmp file format.

    uint32 row, column;
    for (row = 0; row < height; row++) {
        unsigned char *imagePtr = image + (height - 1 - row) * width * samplesPerPixel;
        unsigned char *paddedImagePtr = paddedImage + row * (width * 3 + extrabytes);
        for (column = 0; column < width; column++) {
            *paddedImagePtr = *(imagePtr + 2);
            *(paddedImagePtr + 1) = *(imagePtr + 1);
            *(paddedImagePtr + 2) = *imagePtr;
            imagePtr += samplesPerPixel;
            paddedImagePtr += 3;
        }
    }

    /* Write bmp data */
    [mutableBMPData appendBytes:paddedImage length:bytesize];

    free(paddedImage);

    return mutableBMPData;
}

@end
