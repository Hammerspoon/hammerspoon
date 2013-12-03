//
//  SDAppProxy.h
//  Zephyros
//
//  Created by Steven on 4/21/13.
//  Copyright (c) 2013 Giant Robot Software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <JavaScriptCore/JavaScriptCore.h>
@class PHApp;

@protocol PHAppJSExport <JSExport>

+ (NSArray*) runningApps;

- (NSArray*) allWindows;
- (NSArray*) visibleWindows;

- (NSString*) title;
- (BOOL) isHidden;
- (void) show;
- (void) hide;

@property (readonly) pid_t pid;

- (void) kill;
- (void) kill9;

@end

@interface PHApp : NSObject <PHAppJSExport>

- (id) initWithPID:(pid_t)pid;
- (id) initWithRunningApp:(NSRunningApplication*)app;

@property (readonly) pid_t pid;

@end
