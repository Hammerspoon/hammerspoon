//
//  MJAppDelegate.h
//  Hammerspoon
//
//  Created by Chris Jones on 02/09/2015.
//  Copyright (c) 2015 Hammerspoon. All rights reserved.
//
#import <Fabric/Fabric.h>
#import <Crashlytics/Crashlytics.h>

@interface MJAppDelegate : NSObject <NSApplicationDelegate, CrashlyticsDelegate>
@property IBOutlet NSMenu* menuBarMenu;
@property (nonatomic, copy) NSAppleEventDescriptor *startupEvent;
@end
