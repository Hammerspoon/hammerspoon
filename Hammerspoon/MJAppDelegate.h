//
//  MJAppDelegate.h
//  Hammerspoon
//
//  Created by Chris Jones on 02/09/2015.
//  Copyright (c) 2015 Hammerspoon. All rights reserved.
//
@import Crashlytics;

@protocol HSOpenFileDelegate <NSObject>

-(void)callbackWithURL:(NSString *)openUrl;

@end

@interface MJAppDelegate : NSObject <NSApplicationDelegate, CrashlyticsDelegate>
@property IBOutlet NSMenu* menuBarMenu;
@property (nonatomic, copy) NSAppleEventDescriptor *startupEvent;
@property (nonatomic, copy) NSString *startupFile;
@property (nonatomic, weak) id<HSOpenFileDelegate> openFileDelegate;
@property (nonatomic, strong) NSString* updateAvailable;
@end
