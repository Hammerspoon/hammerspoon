//
//  PHJSWindow.h
//  Phoenix
//
//  Created by Steven Degutis on 12/2/13.
//  Copyright (c) 2013 Steven. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <JavaScriptCore/JavaScriptCore.h>
@class PHWindow;
@class PHApp;

@protocol PHWindowJSExport <JSExport>

// getting windows

+ (NSArray*) allWindows;
+ (NSArray*) visibleWindows;
+ (PHWindow*) focusedWindow;
+ (NSArray*) visibleWindowsMostRecentFirst;
- (NSArray*) otherWindowsOnSameScreen;
- (NSArray*) otherWindowsOnAllScreens;


// window position & size

- (CGRect) frame;
- (CGPoint) topLeft;
- (CGSize) size;

- (void) setFrame:(CGRect)frame;
- (void) setTopLeft:(CGPoint)thePoint;
- (void) setSize:(CGSize)theSize;


- (void) maximize;
- (void) minimize;
- (void) unMinimize;


// other

- (NSScreen*) screen;
- (PHApp*) app;

- (BOOL) isNormalWindow;

// focus

- (BOOL) focusWindow;

- (void) focusWindowLeft;
- (void) focusWindowRight;
- (void) focusWindowUp;
- (void) focusWindowDown;

- (NSArray*) windowsToWest;
- (NSArray*) windowsToEast;
- (NSArray*) windowsToNorth;
- (NSArray*) windowsToSouth;


// other window properties

- (NSString*) title;
- (BOOL) isWindowMinimized;

@end
