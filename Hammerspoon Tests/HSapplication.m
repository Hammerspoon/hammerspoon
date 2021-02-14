//
//  HSapplication.m
//  Hammerspoon
//
//  Created by Michael Bujol on 13/04/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSapplicationTests : HSTestCase

@end

@implementation HSapplicationTests

- (void)setUp {
    [super setUpWithRequire:@"test_application"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInitWithPidFailures {
    RUN_LUA_TEST()
}

- (void)testInitWithPid {
    SKIP_IN_GITHUB_ACTIONS() // Added by @asmagill
    RUN_LUA_TEST()
}

- (void)testAttributesFromBundleID {
    RUN_LUA_TEST()
}

- (void)testBasicAttributes {
    RUN_LUA_TEST()
}

// - (void)testActiveAttributes {
//     RUN_LUA_TEST()
// }

- (void)testFrontmostApplication {
    SKIP_IN_TRAVIS()
    SKIP_IN_GITHUB_ACTIONS()
    RUN_LUA_TEST()
}

- (void)testRunningApplications {
    RUN_LUA_TEST()
}

- (void)testHiding {
    SKIP_IN_TRAVIS()
    SKIP_IN_GITHUB_ACTIONS()
    [self luaTestWithCheckAndTimeOut:5 setupCode:@"testHiding()" checkCode:@"testHidingValues()"];
}

- (void)testKilling {
    SKIP_IN_TRAVIS()
    [self luaTestWithCheckAndTimeOut:5 setupCode:@"testKilling()" checkCode:@"testKillingValues()"];
}

- (void)testForceKilling {
    SKIP_IN_TRAVIS()
    [self luaTestWithCheckAndTimeOut:5 setupCode:@"testForceKilling()" checkCode:@"testForceKillingValues()"];
}

- (void)testWindows {
    SKIP_IN_TRAVIS()
    SKIP_IN_GITHUB_ACTIONS()
    [self luaTestWithCheckAndTimeOut:5 setupCode:@"testWindows()" checkCode:@"testWindowsValues()"];
}

- (void)testMenus {
    RUN_LUA_TEST()
}

- (void)testMenusAsync {
    [self luaTestWithCheckAndTimeOut:5 setupCode:@"testMenusAsync()" checkCode:@"testMenusAsyncValues()"];
}

- (void)testUTI {
    RUN_LUA_TEST()
}
@end
