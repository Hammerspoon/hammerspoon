//
//  SDAppProxy.h
//  Zephyros
//
//  Created by Steven on 4/21/13.
//  Copyright (c) 2013 Giant Robot Software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <JavaScriptCore/JavaScriptCore.h>

@protocol SuperDuperLame <JSExport>

- (id) initWithPID:(pid_t)pid;
- (id) initWithRunningApp:(NSRunningApplication*)app;

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

@interface SDApp : NSObject <SuperDuperLame>

@end
