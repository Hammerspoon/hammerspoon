//
//  HSmath.m
//  Hammerspoon Tests
//
//  Created by Chris Jones on 23/12/2019.
//  Copyright © 2019 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSmath : HSTestCase

@end

@implementation HSmath

- (void)setUp {
  [super setUpWithRequire:@"test_math"];
  // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the class.
  [super tearDown];
}

// FIXME: These tests don't really test anything other than the functions exist and don't throw errors

- (void)testRandomFloat {
  RUN_LUA_TEST()
}

- (void)testRandomFromRange {
  RUN_LUA_TEST()
}

@end
