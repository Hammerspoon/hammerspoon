//
//  HSuserpreferences.m
//  Hammerspoon Tests
//
//  Created by Linghua Zhang on 2018/03/15.
//  Copyright © 2018 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSuserpreferences: HSTestCase

@end

@implementation HSuserpreferences

- (void)setUp {
    [super setUpWithRequire:@"test_userpreferences"];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testUserPreferences {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

@end

