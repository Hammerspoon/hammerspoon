//
//  HSapplication.m
//  Hammerspoon
//
//  Created by Michael Bujol on 13/04/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSapplication : HSTestCase

@end

@implementation HSapplication

- (void)setUp {
    [super setUpWithRequire:@"test_application"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testAttributesFromBundleID {
    RUN_LUA_TEST()
}

- (void)testBasicAttributes {
    RUN_LUA_TEST()
}

// - (void)testActiveAttributes {
//     RUN_LUA_TEST()
// }

- (void)testFrontmostApplication {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

- (void)testRunningApplications {
    RUN_LUA_TEST()
}

- (void)testHiding {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

- (void)testKilling {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

- (void)testForceKilling {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

- (void)testWindows {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}
@end
