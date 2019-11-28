//
//  NSImage+JPEG.h
//  streamdeck
//
//  Created by Chris Jones on 28/11/2019.
//  Copyright © 2019 Hammerspoon. All rights reserved.
//

@import Foundation;
@import Cocoa;

NS_ASSUME_NONNULL_BEGIN

@interface NSImage (JPEG)
- (NSData *)jpegData;
- (NSData *)jpegDataWithCompressionFactor:(CGFloat)compressionFactor;
@end

NS_ASSUME_NONNULL_END
