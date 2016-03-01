//
//  HSfs.m
//  Hammerspoon
//
//  Created by Michael Bujol on 03/01/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSfs : HSTestCase

@end

@implementation HSfs

- (void)setUp {
    [super setUpWithRequire:@"test_fs"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testRmdir {
    RUN_LUA_TEST()
}
- (void)testChdir {
    RUN_LUA_TEST()
}
- (void)testAttributes {
    RUN_LUA_TEST()
}



@end
