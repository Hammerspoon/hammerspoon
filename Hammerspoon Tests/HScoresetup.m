//
//  HScoresetup.m
//  Hammerspoon
//
//  Created by Chris Jones on 06/03/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

BOOL testFlag;

@interface HScoresetup : HSTestCase
@end

@implementation HScoresetup

- (void)setUp {
    [super setUpWithRequire:@"test_coresetup"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    testFlag = NO;
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testOSExit {
    RUN_LUA_TEST()
}

- (void)testConfigDir {
    RUN_LUA_TEST()
}

- (void)testDocstringsJSONFile {
    RUN_LUA_TEST()
}

- (void)testProcessInfo {
    RUN_LUA_TEST()
}

static int verifyShutdown(lua_State *L) {
    testFlag = YES;
    return 0;
}

- (void)testShutdownCallback {
    luaL_Reg shutdownLib[] = {
        {"verifyShutdown", verifyShutdown},
        {NULL, NULL}
    };
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    [skin registerLibrary:"shutdownLib" functions:shutdownLib metaFunctions:nil];
    lua_setglobal(skin.L, "shutdownLib");

    RUN_LUA_TEST()

    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:5];
    BOOL result = NO;

    while (result == NO && ([timeoutDate timeIntervalSinceNow] > 0)) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.5, NO);
        result = testFlag;
    }
    XCTAssertTrue(testFlag, @"hs.shutdownCallback was not called successfully");
}

- (void)testAccessibilityState {
    RUN_LUA_TEST()
}

- (void)testAutoLaunch {
    RUN_LUA_TEST()
}

- (void)testAutomaticallyCheckForUpdates {
    RUN_LUA_TEST()
}

- (void)testCheckForUpdates {
    RUN_LUA_TEST()
}

- (void)testCleanUTF8forConsole {
    RUN_LUA_TEST()
}

- (void)testConsoleOnTop {
    RUN_LUA_TEST()
}

- (void)testDockIcon {
    RUN_LUA_TEST()
}

// FIXME: This test is disabled for now, it doesn't seem to work from within Xcode
//- (void)testExecute {
//    RUN_LUA_TEST()
//}

- (void)testGetObjectMetatable {
    RUN_LUA_TEST()
}

- (void)testMenuIcon {
    RUN_LUA_TEST()
}

// FIXME: Quite a few things here are untested, like opening About/Console/Prefs windows, because I'm not yet sure how to test them
@end
