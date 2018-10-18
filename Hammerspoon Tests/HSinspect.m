//
//  HSinspect.m
//  Hammerspoon
//
//  Created by David Peterson on 18-Oct-2018.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSinspect : HSTestCase

@end

@implementation HSinspect

- (void)setUp {
    [super setUpWithRequire:@"test_inspect"];
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