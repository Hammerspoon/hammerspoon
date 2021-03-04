//
//  Hammerspoon_Tests.m
//  Hammerspoon Tests
//
//  Created by Peter van Dijk on 28/10/14.
//  Copyright (c) 2014 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"
#pragma GCC diagnostic ignored "-Wgnu-statement-expression"

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
    NSArray *errors = [res componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"💩"]];

    // If Hammerspoon is already running, hs.ipc will fail to load, so let's filter that error out if it exists.
    NSArray *filteredErrors = [errors filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"NOT (SELF contains 'failed to create new local port') AND NOT (SELF == '')"]];

    XCTAssertEqual(0, filteredErrors.count, @"Some modules failed to load: %@", filteredErrors);
}


@end
