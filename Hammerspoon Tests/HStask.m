//
//  HStask.m
//  Hammerspoon Tests
//
//  Created by Chris Jones on 02/03/2018.
//  Copyright © 2018 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HStask : HSTestCase

@end

@implementation HStask

- (void)setUp {
    [super setUpWithRequire:@"test_task"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testNewTask {
    RUN_LUA_TEST()
}

- (void)testSimpleTask {
        XCTAssertTrue([self luaTestWithCheckAndTimeOut:5 setupCode:@"testSimpleTask()" checkCode:@"testSimpleTaskValueCheck()"], @"hs.task simple task test failed");
}

- (void)testSimpleTaskFail {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:5 setupCode:@"testSimpleTaskFail()" checkCode:@"testSimpleTaskFailValueCheck()"], @"hs.task simple fail task test failed");
}

- (void)testStreamingTask {
        SKIP_IN_TRAVIS()
        XCTAssertTrue([self luaTestWithCheckAndTimeOut:10 setupCode:@"testStreamingTask()" checkCode:@"testStreamingTaskValueCheck()"], @"hs.task streaming test failed");
}

- (void)testTaskLifecycle {
    RUN_LUA_TEST()
}

- (void)testTaskEnvironment {
    RUN_LUA_TEST()
}

- (void)testTaskBlock {
    RUN_LUA_TEST()
}

- (void)testTaskWorkingDirectory {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}
@end
