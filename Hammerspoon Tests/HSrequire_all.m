//
//  Hammerspoon_Tests.m
//  Hammerspoon Tests
//
//  Created by Peter van Dijk on 28/10/14.
//  Copyright (c) 2014 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSrequire_all : HSTestCase

@end

@implementation HSrequire_all

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testRequireAll {
    // FIXME: this is hacky, we should be getting a table back so we can assert every extension, etc.
    NSString *res = [self runLua:@"return testrequires()"];
    NSLog(@"%@", res);
    XCTAssertEqualObjects(res, @"", @"one or more require statements failed");
}


@end
