//
//  HSscreen.m
//  Hammerspoon
//
//  Created by Chris Jones on 12/02/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSscreen : HSTestCase

@end

@implementation HSscreen

- (void)setUp {
    [super setUpWithRequire:@"test_screen"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

// Test functions/constructors

- (void)testMainScreen {
    RUN_LUA_TEST()
}

- (void)testPrimaryScreen {
    RUN_LUA_TEST()
}

- (void)testAllScreens {
    RUN_LUA_TEST()
}

- (void)testFind {
    RUN_LUA_TEST()
}

- (void)testScreenPositions {
    RUN_LUA_TEST()
}

- (void)testAvailableModes {
    RUN_LUA_TEST()
}

- (void)testCurrentMode {
    RUN_LUA_TEST()
}

- (void)testSetMode {
    SKIP_IN_GITHUB_ACTIONS()
    RUN_LUA_TEST()
}

- (void)testSetOrigin {
    RUN_LUA_TEST()
}

- (void)testFrames {
    RUN_LUA_TEST()
}

- (void)testFromUnitRect {
    RUN_LUA_TEST()
}

- (void)testBrightness {
    RUN_LUA_TEST()
}

- (void)testGamma {
    // FIXME: This should really be an async test which checks that the setGamme() happened. Right now we are just blindly assuming it happens.
    RUN_LUA_TEST()
}

- (void)testId {
    RUN_LUA_TEST()
}

- (void)testName {
    RUN_LUA_TEST()
}

- (void)testPosition {
    RUN_LUA_TEST()
}

- (void)testNextPrevious {
    RUN_LUA_TEST()
}

- (void)testRotation {
    // FIXME: This should really be an async test which checks that rotations happened. Right now we are just blindly assuming they happen.
    RUN_LUA_TEST()
}

- (void)testSetPrimary {
    RUN_LUA_TEST()
}

- (void)testScreenshots {
    RUN_LUA_TEST()
}

- (void)testToUnitRect {
    RUN_LUA_TEST()
}

// FIXME: Untested: toEast/toWest/toSouth/toNorth

@end
