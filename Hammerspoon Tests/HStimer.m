//
//  HStimer.m
//  Hammerspoon
//
//  Created by Chris Jones on 10/02/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HStimer : HSTestCase

@end

@implementation HStimer

- (void)setUp {
    [super setUpWithRequire:@"test_timer"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

// Test functions/constructors

- (void)testDays {
    RUN_LUA_TEST()
}

- (void)testHours {
    RUN_LUA_TEST()
}

- (void)testLocalTime {
    RUN_LUA_TEST()
}

- (void)testMinutes {
    RUN_LUA_TEST()
}

- (void)testSeconds {
    RUN_LUA_TEST()
}

- (void)testSecondsSinceEpoch {
    RUN_LUA_TEST()
}

- (void)testUsleep {
    RUN_LUA_TEST()
}

- (void)testWeeks {
    RUN_LUA_TEST()
}

- (void)testDoAfter {
    [self luaTestWithCheckAndTimeOut:5 setupCode:@"testDoAfterStart()" checkCode:@"testTimerValueCheck()"];
}

- (void)testDoAt {
    [self luaTestWithCheckAndTimeOut:5 setupCode:@"testDoAtStart()" checkCode:@"testTimerValueCheck()"];
}

- (void)testDoEvery {
    [self luaTestWithCheckAndTimeOut:5 setupCode:@"testDoEveryStart()" checkCode:@"testTimerValueCheck()"];
}

- (void)testDoUntil {
    [self luaTestWithCheckAndTimeOut:5 setupCode:@"testDoUntilStart()" checkCode:@"testTimerValueCheck()"];
}

- (void)testDoWhile {
    [self luaTestWithCheckAndTimeOut:5 setupCode:@"testDoWhileStart()" checkCode:@"testTimerValueCheck()"];
}

- (void)testWaitUntil {
    [self luaTestWithCheckAndTimeOut:5 setupCode:@"testWaitUntilStart()" checkCode:@"testTimerValueCheck()"];
}

- (void)testWaitWhile {
    [self luaTestWithCheckAndTimeOut:5 setupCode:@"testWaitWhileStart()" checkCode:@"testTimerValueCheck()"];
}

/* This test isn't possible with the current XCTestCase Expectations API - there's no way to set an expectation of failure
- (void)testNonRunning {
    [self luaTestWithCheckAndTimeOut:5 setupCode:@"testNeverStart()" checkCode:@"testTimerValueCheck()"];
}
 */

- (void)testNew {
    RUN_LUA_TEST()
}

- (void)testToString {
    RUN_LUA_TEST()
}

- (void)testRunningAndStartStop {
    RUN_LUA_TEST()
}

- (void)testTriggers {
    RUN_LUA_TEST()
}

- (void)testImmediateFire {
    [self luaTestWithCheckAndTimeOut:5 setupCode:@"testImmediateFireStart()" checkCode:@"testTimerValueCheck()"];
}

@end
