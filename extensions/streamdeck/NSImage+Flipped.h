//
//  NSImage+Flipped.h
//  streamdeck
//
//  Created by Chris Jones on 25/11/2019.
//  Copyright © 2019 Hammerspoon. All rights reserved.
//

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSImage (Flipped)
- (NSImage *)flipImage:(BOOL)horiz vert:(BOOL)vert;
@end

NS_ASSUME_NONNULL_END
