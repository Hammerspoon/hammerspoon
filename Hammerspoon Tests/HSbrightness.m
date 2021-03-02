//
//  HSbrightness.m
//  Hammerspoon
//
//  Created by Chris Jones on 29/12/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSbrightness : HSTestCase

@end

@implementation HSbrightness

- (void)setUp {
    [super setUpWithRequire:@"test_brightness"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testGet {
    SKIP_IN_TRAVIS()
    SKIP_IN_GITHUB_ACTIONS()
    RUN_LUA_TEST()
}

- (void)testSet {
    SKIP_IN_TRAVIS()
    SKIP_IN_XCODE_SERVER()
    SKIP_IN_GITHUB_ACTIONS()
    RUN_LUA_TEST()
}

- (void)testAmbient {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

@end
