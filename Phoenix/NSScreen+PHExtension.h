//
//  NSScreenProxy.h
//  Zephyros
//
//  Created by Steven on 4/14/13.
//  Copyright (c) 2013 Giant Robot Software. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NSScreen+JSExport.h"

@interface NSScreen (PHExtension) <NSScreenJSExport>

- (CGRect) frameIncludingDockAndMenu;
- (CGRect) frameWithoutDockOrMenu;

- (NSScreen*) nextScreen;
- (NSScreen*) previousScreen;

@end
