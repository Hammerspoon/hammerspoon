//
//  MJAppDelegate.h
//  Hammerspoon
//
//  Created by Chris Jones on 02/09/2015.
//  Copyright (c) 2015 Hammerspoon. All rights reserved.
//
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wvariadic-macros"
#import "Sentry.h"
#pragma clang diagnostic pop

#ifndef NO_INTENTS
#import "HSExecuteLuaIntentHandler.h"
#endif

@protocol HSOpenFileDelegate <NSObject>

-(void)callbackWithURL:(NSString *)openUrl senderPID:(pid_t)pid;

@end

@interface MJAppDelegate : NSObject <NSApplicationDelegate> /* CRASHLYTICS DELEGATE WAS HERE */
@property IBOutlet NSMenu* menuBarMenu;
@property (nonatomic, copy) NSAppleEventDescriptor *startupEvent;
@property (nonatomic, copy) NSString *startupFile;
@property (nonatomic, weak) id<HSOpenFileDelegate> openFileDelegate;
@property (nonatomic, strong) NSString* updateAvailable;
@property (nonatomic, strong) NSString* updateAvailableDisplayVersion;
@end
