//
//  LVAutoUpdaterWindowController.h
//  Leviathan
//
//  Created by Steven Degutis on 1/7/14.
//  Copyright (c) 2014 Steven Degutis. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol LVAutoUpdaterWindowControllerDelegate <NSObject>

- (void) userDismissedAutoUpdaterWindow;
- (void) userWantsInstallAtQuit;

@end

@interface LVAutoUpdaterWindowController : NSWindowController

@property (weak) id<LVAutoUpdaterWindowControllerDelegate> delegate;

@property NSString* upcomingVersion;
@property NSString* oldVersion;

@property NSURL* releaseNotesAddress;

- (void) showWindow;

- (void) showCheckingPage;
- (void) showUpToDatePage;
- (void) showFoundPage;
- (void) showErrorPage;

@end
