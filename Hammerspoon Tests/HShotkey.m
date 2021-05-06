//
//  HShotkey.m
//  Hammerspoon Tests
//
//  Created by Chris Jones on 06/05/2021.
//  Copyright © 2021 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HShotkey : HSTestCase

@end

@implementation HShotkey

- (void)setUp {
    [super setUpWithRequire:@"test_hotkey"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testAssignable {
    RUN_LUA_TEST()
}

- (void)testGetHotkeys {
    RUN_LUA_TEST()
}

- (void)testGetSystemAssigned {
    RUN_LUA_TEST()
}

- (void)testBasicHotkey {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

- (void)testRepeatingHotkey {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(5)
}

- (void)testHotkeyStates {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(5)
}
@end
