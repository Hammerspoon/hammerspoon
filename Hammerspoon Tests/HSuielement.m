//
//  HSuielement.m
//  Hammerspoon
//
//  Created by Michael Bujol on 17/04/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSuielement : HSTestCase

@end

@implementation HSuielement

- (void)setUp {
    [super setUpWithRequire:@"test_uielement"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testWatcher {
    SKIP_IN_TRAVIS()
    [self luaTestWithCheckAndTimeOut:5 setupCode:@"testWatcher()" checkCode:@"testWatcherValues()"];
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
