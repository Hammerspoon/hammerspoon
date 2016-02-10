//
//  HStimer.m
//  Hammerspoon
//
//  Created by Chris Jones on 10/02/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"
#pragma GCC diagnostic ignored "-Wgnu-statement-expression"

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

@end
