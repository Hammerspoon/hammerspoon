//
//  Hammerspoon_Tests.m
//  Hammerspoon Tests
//
//  Created by Peter van Dijk on 28/10/14.
//  Copyright (c) 2014 Hammerspoon. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>

@interface Hammerspoon_Tests : XCTestCase

@end

@implementation Hammerspoon_Tests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testExample {
    // This is an example of a functional test case.
    XCTAssert(NO, @"Pass");
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
