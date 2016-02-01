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
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    NSString *result = [self runLua:@"require('test_audiodevice')"];
    XCTAssertEqualObjects(@"true", result, @"Unable to load test_audiodevice.lua");
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testAudiodeviceGetDefaultOutput {
    NSString *result = [self runLua:@"testGetDefaultOutput()"];
    XCTAssertEqualObjects(@"hs.audiodevice", result, @"Unable to get default audio device");
}

@end
