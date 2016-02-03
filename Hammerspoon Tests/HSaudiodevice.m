//
//  HSaudiodevice.m
//  Hammerspoon
//
//  Created by Chris Jones on 01/02/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestcase.h"
#pragma GCC diagnostic ignored "-Wgnu-statement-expression"

@interface HSaudiodevice : HSTestCase

@end

@implementation HSaudiodevice

- (void)setUp {
    [super setUpWithRequire:@"test_audiodevice"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testGetDefaultOutput {
    [self luaTestFromSelector:_cmd];
}

- (void)testGetDefaultInput {
    [self luaTestFromSelector:_cmd];
}

- (void)testGetCurrentOutput {
    [self luaTestFromSelector:_cmd];
}

- (void)testGetCurrentInput {
    [self luaTestFromSelector:_cmd];
}

- (void)testGetAllDevices {
    [self luaTestFromSelector:_cmd];
}

- (void)testGetAllOutputDevices {
    [self luaTestFromSelector:_cmd];
}

- (void)testGetAllInputDevices {
    [self luaTestFromSelector:_cmd];
}

@end
