//
//  NSImage+Rotated.h
//  streamdeck
//
//  Created by Chris Jones on 25/11/2019.
//  Copyright © 2019 Hammerspoon. All rights reserved.
//

@import Foundation;
@import Cocoa;

@interface NSImage (Rotated)
- (NSImage *)imageRotated:(int)degrees;
@end
