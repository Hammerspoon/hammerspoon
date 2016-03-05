//
//  HSosascript.m
//
//  Created by Michael Bujol on 02/25/2016.
//

#import "HSTestCase.h"

@interface HSosascript : HSTestCase

@end

@implementation HSosascript

- (void)setUp {
    [super setUpWithRequire:@"test_osascript"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testJavaScriptParseError {
    RUN_LUA_TEST()
}

- (void)testJavaScriptAddition {
    RUN_LUA_TEST()
}

- (void)testJavaScriptDestructuring {
    RUN_LUA_TEST()
}

- (void)testJavaScriptString {
    RUN_LUA_TEST()
}

- (void)testJavaScriptArray {
    RUN_LUA_TEST()
}

- (void)testJavaScriptJsonStringify {
    RUN_LUA_TEST()
}

- (void)testJavaScriptJsonParse {
    RUN_LUA_TEST()
}

- (void)testJavaScriptJsonParseError {
    RUN_LUA_TEST()
}

- (void)testAppleScriptParseError {
    RUN_LUA_TEST()
}

- (void)testAppleScriptAddition {
    RUN_LUA_TEST()
}

- (void)testAppleScriptString {
    RUN_LUA_TEST()
}

- (void)testAppleScriptArray {
    RUN_LUA_TEST()
}

- (void)testAppleScriptDict {
    RUN_LUA_TEST()
}

- (void)testAppleScriptExecutionError {
    RUN_LUA_TEST()
}

@end
