//
//  HSTestCase.h
//  Hammerspoon
//
//  Created by Chris Jones on 01/02/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MJLua.h"

@interface HSTestCase : XCTestCase
- (NSString *)runLua:(NSString *)luaCode;
@end
