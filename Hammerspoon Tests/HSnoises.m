//
//  HSnoises.m
//  Hammerspoon
//
//  Created by Tristan Hume on 2016-07-15.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSnoises : HSTestCase

@end

@implementation HSnoises

- (void)setUp {
  [super setUpWithRequire:@"test_noises"];
  // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the class.
  [super tearDown];
}

// FIXME: These tests don't really test anything other than the functions exist and don't throw errors

- (void)testStartStop {
  RUN_LUA_TEST()
}

@end