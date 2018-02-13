//
//  HSwindow.m
//  Hammerspoon Tests
//
//  Created by Chris Jones on 15/01/2018.
//  Copyright © 2018 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSwindow : HSTestCase

@end

@implementation HSwindow

- (void)setUp {
    [super setUpWithRequire:@"test_window"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testAllWindows {
    RUN_LUA_TEST()
}

- (void)testDesktop {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

- (void)testOrderedWindows {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}
@end
