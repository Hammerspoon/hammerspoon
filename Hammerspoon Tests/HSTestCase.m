//
//  HSTestCase.m
//  Hammerspoon
//
//  Created by Chris Jones on 01/02/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"
#pragma GCC diagnostic ignored "-Wgnu-statement-expression"

@implementation HSTestCase

- (NSString *)runLua:(NSString *)luaCode {
    return MJLuaRunString(luaCode);
}

- (void)testrunLua {
    NSString *result = [self runLua:@"return 'hello world!'"];
    XCTAssertEqualObjects(@"hello world!", result, @"Lua code evaluation is not working");
}

@end