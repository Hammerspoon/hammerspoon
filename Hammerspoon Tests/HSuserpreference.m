//
//  HSuserpreference.m
//  Hammerspoon Tests
//
//  Created by Linghua Zhang on 2018/03/15.
//  Copyright © 2018 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSuserpreference: HSTestCase

@end

@implementation HSuserpreference

- (void)setUp {
    [super setUpWithRequire:@"test_userpreference"];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testUserPreference {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

@end

