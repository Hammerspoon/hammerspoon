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
    [self luaTestFromSelector:_cmd];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [self luaTestFromSelector:_cmd];
    [super tearDown];
}

- (void)testMkdir {
    RUN_LUA_TEST()
}

- (void)testChdir {
    RUN_LUA_TEST()
}

- (void)testRmdir {
    RUN_LUA_TEST()
}

- (void)testAttributes {
    RUN_LUA_TEST()
}

- (void)testTags {
    RUN_LUA_TEST()
}

- (void)testLinks {
    RUN_LUA_TEST()
}

- (void)testTouch {
    RUN_LUA_TEST()
}

- (void)testFileUTI {
    RUN_LUA_TEST()
}

- (void)testDirWalker {
    RUN_LUA_TEST()
}

- (void)testLockDir {
    RUN_LUA_TEST()
}

- (void)testLock {
    RUN_LUA_TEST()
}

- (void)testVolumes {
    SKIP_IN_TRAVIS()
    SKIP_IN_GITHUB_ACTIONS()
    [self luaTestWithCheckAndTimeOut:10 setupCode:@"testVolumes()" checkCode:@"testVolumesValues()"];
}

@end
