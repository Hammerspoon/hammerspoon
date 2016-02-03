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

- (void)setUpWithRequire:(NSString *)requireName {
    [super setUp];
    NSString *result = [self runLua:[NSString stringWithFormat:@"require('%@')", requireName]];
    XCTAssertEqualObjects(@"true", result, @"Unable to load %@.lua", requireName);
}
- (void)tearDown {
    MJLuaReplace();
    [super tearDown];
}

- (NSString *)runLua:(NSString *)luaCode {
    return MJLuaRunString(luaCode);
}

- (void)luaTest:(NSString *)luaCode {
    NSString *result = [self runLua:luaCode];
    XCTAssertEqualObjects(@"Success", result, @"Test failed: %@", luaCode);
    NSLog(@"Test returned: %@", result);
}

- (void)luaTestFromSelector:(SEL)selector {
    NSString *funcName = NSStringFromSelector(selector);
    NSLog(@"Calling Lua function from selector: %@()", funcName);
    [self luaTest:[NSString stringWithFormat:@"%@()", funcName]];
}

// Tests of the above methods

- (void)testrunLua {
    NSString *result = [self runLua:@"return 'hello world!'"];
    XCTAssertEqualObjects(@"hello world!", result, @"Lua code evaluation is not working");
}

- (void)testTestLuaSuccess {
    [self luaTest:@"return 'Success'"];
}

@end