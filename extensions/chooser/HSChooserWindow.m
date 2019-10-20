//
//  HSChooserWindow.m
//  Hammerspoon
//
//  Created by Chris Jones on 29/12/2015.
//  Copyright © 2015 Hammerspoon. All rights reserved.
//

#import "HSChooserWindow.h"

@implementation HSChooserWindow

-(BOOL)canBecomeMainWindow { return YES; }
-(BOOL)canBecomeKeyWindow { return YES; }
-(BOOL)allowsVibrancy { return NO; }
@end
