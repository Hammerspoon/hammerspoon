//
//  HSmath.m
//  Hammerspoon Tests
//
//  Created by Chris Jones on 23/12/2019.
//  Copyright © 2019 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSmouseTests : HSTestCase

@end

@implementation HSmouseTests

- (void)setUp {
    [super setUpWithRequire:@"test_mouse"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

// FIXME: These tests don't really test anything other than the functions exist and don't throw errors

- (void)testMouseCount {
    RUN_LUA_TEST()
}

- (void)testMouseNames {
    RUN_LUA_TEST()
}

- (void)testMouseAbsolutePosition {
    RUN_LUA_TEST()
}

- (void)testScrollDirection {
    RUN_LUA_TEST()
}

- (void)testMouseTrackingSpeed {
    RUN_LUA_TEST()
}
@end
