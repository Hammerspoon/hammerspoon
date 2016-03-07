//
//  HSappfinder.m
//  Hammerspoon
//
//  Created by Chris Jones on 10/02/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSappfinder : HSTestCase

@end

@implementation HSappfinder

- (void)setUp {
    [super setUpWithRequire:@"test_appfinder"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testAppFromName {
    // FIXME: This uses assertIsUserdata() instead of assertIsUserdataOfType(), because hs.application doesn't support typed userdata yet
    RUN_LUA_TEST()
}

- (void)testAppFromWindowTitle {
    RUN_LUA_TEST()
}

- (void)testAppFromWindowTitlePattern {
    RUN_LUA_TEST()
}

- (void)testWindowFromWindowTitle {
    RUN_LUA_TEST()
}

- (void)testWindowFromWindowTitlePattern {
    RUN_LUA_TEST()
}

@end