//  ASCIImage
//  Created by Charles Parnot on 5/29/13.
//  Copyright (c) 2013 Charles Parnot. All rights reserved.


#import <Foundation/Foundation.h>


extern NSString * const ASCIIContextShapeIndex;
extern NSString * const ASCIIContextFillColor;
extern NSString * const ASCIIContextStrokeColor;
extern NSString * const ASCIIContextLineWidth;
extern NSString * const ASCIIContextShouldClose;
extern NSString * const ASCIIContextShouldAntialias;


// iOS
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR

    #import <UIKit/UIKit.h>
    #define PARImage UIImage
    #define PARColor UIColor

// Mac
#elif TARGET_OS_MAC

    #import <Cocoa/Cocoa.h>
    #define PARImage NSImage
    #define PARColor NSColor

#endif


@interface PARImage (ASCIIInput)


/// @name Creating Images from ASCII Input

/// This simple version only needs a color and a flag for anti-aliasing. The specified color is used to draw lines at 1 pixel width, draw pixels as 1-pixel sqaure, and to fill polygons and ellipses.
+ (PARImage *)imageWithASCIIRepresentation:(NSArray *)rep color:(PARColor *)color shouldAntialias:(BOOL)shouldAntialias;

/// This method offers more advanced options that can be set on each "shape", using the `contextHandler` block. The mutable dictionary passed by the block can be modified using the keys listed in the constant above. The dictionary initially contains the `ASCIIContextShapeIndex` key to indicate which shape will be drawn. You cannot manipulate the current graphic context directly within that block.
+ (PARImage *)imageWithASCIIRepresentation:(NSArray *)rep contextHandler:(void(^)(NSMutableDictionary *context))contextHandler;


/// @name Example Images

+ (PARImage *)arrowImageWithColor:(PARColor *)color;
+ (PARImage *)chevronImageWithColor:(PARColor *)color;


/// @name Private Methods

// methods exposed only for testing

+ (NSArray *)strictASCIIRepresentationFromLenientASCIIRepresentation:(NSArray *)lenientRep;
+ (NSArray *)numberedASCIIRepresentationFromASCIIRepresentation:(NSArray *)rep;

#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
+ (PARImage *)imageWithASCIIRepresentation:(NSArray *)rep scaleFactor:(CGFloat)scaleFactor color:(PARColor *)color shouldAntialias:(BOOL)shouldAntialias;
+ (PARImage *)imageWithASCIIRepresentation:(NSArray *)rep scaleFactor:(CGFloat)scaleFactor contextHandler:(void(^)(NSMutableDictionary *context))contextHandler;
#endif

@end
