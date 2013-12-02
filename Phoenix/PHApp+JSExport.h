//
//  PHJSApp.h
//  Phoenix
//
//  Created by Steven Degutis on 12/2/13.
//  Copyright (c) 2013 Steven. All rights reserved.
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
