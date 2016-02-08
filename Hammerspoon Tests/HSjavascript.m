//
//  HSjavascript.m
//
//  Created by Michael Bujol on 01/04/2016.
//

#import "HSTestcase.h"
#pragma GCC diagnostic ignored "-Wgnu-statement-expression"

@interface HSjavascript : HSTestCase

@end

@implementation HSjavascript

- (void)setUp {
    [super setUpWithRequire:@"test_javascript"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testParseError {
    RUN_LUA_TEST()
}

- (void)testAddition {
    RUN_LUA_TEST()
}

- (void)testDestructuring {
    RUN_LUA_TEST()
}

- (void)testString {
    RUN_LUA_TEST()
}

- (void)testJsonStringify {
    RUN_LUA_TEST()
}

// - (void)testJsonParse {
//     RUN_LUA_TEST()
// }

- (void)testJsonParseError {
    RUN_LUA_TEST()
}

@end
