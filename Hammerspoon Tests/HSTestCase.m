//
//  HSTestCase.m
//  Hammerspoon
//
//  Created by Chris Jones on 01/02/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@implementation HSTestCase

- (void)setUpWithRequire:(NSString *)requireName {
    [super setUp];
    self.isTravis = [self runningInTravis];

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

- (BOOL)luaTest:(NSString *)luaCode {
    NSString *result = [self runLua:luaCode];
    NSLog(@"Test returned: %@ for: %@", result, luaCode);
    return [result isEqualToString:@"Success"];
}

- (void)luaTestWithCheckAndTimeOut:(NSTimeInterval)timeOut setupCode:(NSString *)setupCode checkCode:(NSString *)checkCode {
    XCTestExpectation *expectation = [self expectationWithDescription:setupCode];
    NSLog(@"Calling setup code: %@", setupCode);
    [self runLua:setupCode];

    [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *timer) {
        NSLog(@"Calling check code: %@", checkCode);
        BOOL result = [self luaTest:checkCode];
        if (result) {
            [expectation fulfill];
            [timer invalidate];
        }
    }];
/*    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"Calling check code: %@", checkCode);
        BOOL result = [self luaTest:checkCode];
        if (result) {
            [expectation fulfill];
        }
    });*/
    [self waitForExpectationsWithTimeout:timeOut handler:^(NSError *error) {
        if (error) {
            NSLog(@"%@ failed", setupCode);
        } else {
            NSLog(@"%@ succeeded", setupCode);
        }
    }];
}

- (BOOL)luaTestFromSelector:(SEL)selector {
    NSString *funcName = NSStringFromSelector(selector);
    NSLog(@"Calling Lua function from selector: %@()", funcName);
    return [self luaTest:[NSString stringWithFormat:@"%@()", funcName]];
}

- (BOOL)runningInTravis {
    return (getenv("TRAVIS") != NULL);
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
