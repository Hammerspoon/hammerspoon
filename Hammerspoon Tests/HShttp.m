//
//  HShttp.m
//  Hammerspoon
//
//  Created by Alex Chen on 08/21/2022.

#import "HSTestCase.h"

@interface HThttp : HSTestCase

@end

@implementation HThttp

- (void)setUp {
    [super setUpWithRequire:@"test_http"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

// Http tests

- (void)testHttpDoAsyncRequestWithCachePolicyParam {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(5)
}

- (void)testHttpDoAsyncRequestWithRedirectParamButNoCachePolicyParam {
    RUN_LUA_TEST()
}

- (void)testHttpDoAsyncRequestWithNoEnableRedirectParam {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(5)
}

- (void)testHttpDoAsyncRequestWithRedirection {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(5)
}

- (void)testHttpDoAsyncRequestWithoutRedirection {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(5)
}

@end
