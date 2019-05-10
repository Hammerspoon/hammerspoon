//
//  NSImage+BMP.h
//  Hammerspoon
//
//  Created by Chris Jones on 07/09/2017.
//  Copyright © 2017 Hammerspoon. All rights reserved.
//

@import Foundation;
@import Cocoa;

@interface NSImage (BMP)
- (NSImageRep *)imageRepOfClass:(Class)imageRepClass;
- (NSData *)bmpDataWithRotation:(int)degree;
- (NSData *)bmpDataWithBackgroundColor:(NSColor *)backgroundColor withRotation:(int)degree;
@end

