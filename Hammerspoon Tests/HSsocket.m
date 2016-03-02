//
//  HSsocket.m
//  Hammerspoon
//
//  Created by Michael Bujol on 02/12/2016.

#import "HSTestcase.h"
#pragma GCC diagnostic ignored "-Wgnu-statement-expression"

@interface HSsocket : HSTestCase

@end

@implementation HSsocket

- (void)setUp {
    [super setUpWithRequire:@"test_socket"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testDefaultSocketCreation {
    RUN_LUA_TEST()
}

- (void)testDefaultSocketCreationWithCallback {
    RUN_LUA_TEST()
}

- (void)testListenerSocketCreation {
    RUN_LUA_TEST()
}

- (void)testListenerSocketCreationWithCallback {
    RUN_LUA_TEST()
}

- (void)testListenerSocketAttributes {
    RUN_LUA_TEST()
}

- (void)testDisconnectAndReuse {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:2 setupCode:@"testDisconnectAndReuse()" checkCode:@"testDisconnectAndReuseValues()"], @"testDisconnectAndReuse test failed");
}

- (void)testConnected {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:2 setupCode:@"testConnected()" checkCode:@"testConnectedValues()"], @"testConnected test failed");
}

- (void)testUserdataStrings {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:2 setupCode:@"testUserdataStrings()" checkCode:@"testUserdataStringValues()"], @"testUserdataStrings test failed");
}

- (void)testClientServerReadWriteDelimiter {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:2 setupCode:@"testClientServerReadWriteDelimiter()" checkCode:@"testClientServerReadWriteDelimiterValues()"], @"testClientServerReadWriteDelimiter test failed");
}

- (void)testClientServerReadWriteBytes {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:2 setupCode:@"testClientServerReadWriteBytes()" checkCode:@"testClientServerReadWriteBytesValues()"], @"testClientServerReadWriteBytes test failed");
}

- (void)testNoCallbackRead {
    RUN_LUA_TEST()
}

- (void)testAlreadyConnected {
    RUN_LUA_TEST()
}

@end
