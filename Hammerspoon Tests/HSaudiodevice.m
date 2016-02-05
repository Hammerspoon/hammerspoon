//
//  HSaudiodevice.m
//  Hammerspoon
//
//  Created by Chris Jones on 01/02/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestcase.h"
#pragma GCC diagnostic ignored "-Wgnu-statement-expression"

@interface HSaudiodevice : HSTestCase

@end

@implementation HSaudiodevice

- (void)setUp {
    [super setUpWithRequire:@"test_audiodevice"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}


// Test functions/constructors

- (void)testGetDefaultOutput {
    RUN_LUA_TEST()
}

- (void)testGetDefaultInput {
    RUN_LUA_TEST()
}

- (void)testGetCurrentOutput {
    RUN_LUA_TEST()
}

- (void)testGetCurrentInput {
    RUN_LUA_TEST()
}

- (void)testGetAllDevices {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

- (void)testGetAllOutputDevices {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

- (void)testGetAllInputDevices {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

- (void)testFindDeviceByName {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

- (void)testFindDeviceByUID {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

- (void)testFindInputByName {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

- (void)testFindInputByUID {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

- (void)testFindOutputByName {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

- (void)testFindOutputByUID {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

// Test hs.audiodevice methods
- (void)testToString {
    RUN_LUA_TEST()
}

- (void)testName {
    RUN_LUA_TEST()
}

- (void)testUID {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

- (void)testIsInputDevice {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

- (void)testIsOutputDevice {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

- (void)testMute {
    RUN_LUA_TEST()
}

- (void)testVolume {
    RUN_LUA_TEST()
}

- (void)testJackConnected {
    RUN_LUA_TEST()
}

- (void)testTransportType {
    RUN_LUA_TEST()
}

- (void)testWatcher {
    RUN_LUA_TEST()
}
@end
