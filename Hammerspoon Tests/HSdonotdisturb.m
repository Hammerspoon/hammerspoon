//
//  HSdonotdisturb.m
//  Hammerspoon Tests
//
//  Created by Linghua Zhang on 2018/03/15.
//  Copyright © 2018 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSdonotdisturb : HSTestCase

@end

@implementation HSdonotdisturb

- (void)setUp {
    [super setUpWithRequire:@"test_donotdisturb"];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testDoNotDisturb {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

@end

