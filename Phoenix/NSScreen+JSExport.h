//
//  NSScreen_PHJSExport.h
//  Phoenix
//
//  Created by Steven Degutis on 12/2/13.
//  Copyright (c) 2013 Steven. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <JavaScriptCore/JavaScriptCore.h>

@protocol NSScreenJSExport <JSExport>

- (CGRect) frameIncludingDockAndMenu;
- (CGRect) frameWithoutDockOrMenu;

- (NSScreen*) nextScreen;
- (NSScreen*) previousScreen;

@end
