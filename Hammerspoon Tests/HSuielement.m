//
//  HSuielement.m
//  Hammerspoon
//
//  Created by Michael Bujol on 17/04/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSuielementTests : HSTestCase

@end

@implementation HSuielementTests

- (void)setUp {
    [super setUpWithRequire:@"test_uielement"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testWindowWatcher {
    SKIP_IN_TRAVIS()
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(5)
}

- (void)testHammerspoonElements {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

- (void)testSelectedText {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

@end
