//
//  HSnotdisturbmode.m
//  Hammerspoon Tests
//
//  Created by Linghua Zhang on 2018/03/15.
//  Copyright © 2018 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSnotdisturbmode : HSTestCase

@end

@implementation HSnotdisturbmode

- (void)setUp {
    [super setUpWithRequire:@"test_notdisturbmode"];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testNotDisturbMode {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

@end

