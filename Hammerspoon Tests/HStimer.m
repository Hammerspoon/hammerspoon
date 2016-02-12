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
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:5 setupCode:@"testDoAfterStart()" checkCode:@"testTimerValueCheck()"], @"hs.timer.doAfter test failed");
}

- (void)testDoAt {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:5 setupCode:@"testDoAtStart()" checkCode:@"testTimerValueCheck()"], @"hs.timer.doAt test failed");
}

- (void)testDoEvery {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:5 setupCode:@"testDoEveryStart()" checkCode:@"testTimerValueCheck()"], @"hs.timer.doEvery test failed");
}

- (void)testDoUntil {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:5 setupCode:@"testDoUntilStart()" checkCode:@"testTimerValueCheck()"], @"hs.timer.doUntil test failed");
}

- (void)testDoWhile {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:5 setupCode:@"testDoWhileStart()" checkCode:@"testTimerValueCheck()"], @"hs.timer.doWhile test failed");
}

- (void)testWaitUntil {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:5 setupCode:@"testWaitUntilStart()" checkCode:@"testTimerValueCheck()"], @"hs.timer.waitUntil test failed");
}

- (void)testWaitWhile {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:5 setupCode:@"testWaitWhileStart()" checkCode:@"testTimerValueCheck()"], @"hs.timer.waitWhile test failed");
}

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

@end
