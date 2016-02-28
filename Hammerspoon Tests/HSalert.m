//
//  HSalert.m
//  Hammerspoon
//
//  Created by Chris Jones on 10/02/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSalert : HSTestCase

@end

@implementation HSalert

- (void)setUp {
    [super setUpWithRequire:@"test_alert"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

// FIXME: These tests don't really test anything other than the functions exist and don't throw errors

- (void)testAlert {
    RUN_LUA_TEST()
}

- (void)testCloseAll {
    RUN_LUA_TEST()
}

@end