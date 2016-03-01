//
//  HSbase64.m
//  Hammerspoon
//
//  Created by Chris Jones on 10/02/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSbase64 : HSTestCase

@end

@implementation HSbase64

- (void)setUp {
    [super setUpWithRequire:@"test_base64"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testEncode {
    RUN_LUA_TEST()
}

- (void)testDecode {
    RUN_LUA_TEST()
}

@end