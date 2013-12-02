//
//  PHAppDelegate.h
//  Phoenix
//
//  Created by Steven on 11/30/13.
//  Copyright (c) 2013 Steven. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "PHConfigLoader.h"

@interface PHAppDelegate : NSObject <NSApplicationDelegate>

@property IBOutlet NSMenu *statusItemMenu;
@property NSStatusItem *statusItem;

@property PHConfigLoader* configLoader;

@end
