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

- (void)testAlreadyConnected {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:2 setupCode:@"testAlreadyConnected()" checkCode:@"testAlreadyConnectedValues()"], @"testAlreadyConnected test failed");
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

- (void)testTagging {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:3 setupCode:@"testTagging()" checkCode:@"testTaggingValues()"], @"testTagging test failed");
}

- (void)testClientServerTimeout {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:3 setupCode:@"testClientServerTimeout()" checkCode:@"testClientServerTimeoutValues()"], @"testClientServerTimeout test failed");
}

- (void)testTLS {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:3 setupCode:@"testTLS()" checkCode:@"testTLSValues()"], @"testTLS test failed");
}

- (void)testNoTLSWhenRequiredByServer {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:3 setupCode:@"testNoTLSWhenRequiredByServer()" checkCode:@"testNoTLSWhenRequiredByServerValues()"], @"testNoTLSWhenRequiredByServer test failed");
}

- (void)testTLSVerifyPeer {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:3 setupCode:@"testTLSVerifyPeer()" checkCode:@"testTLSVerifyPeerValues()"], @"testTLSVerifyPeer test failed");
}

- (void)testTLSVerifyBadPeerFails {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:3 setupCode:@"testTLSVerifyBadPeerFails()" checkCode:@"testTLSVerifyBadPeerFailsValues()"], @"testTLSVerifyBadPeerFails test failed");
}

- (void)testTLSNoVerify {
    XCTAssertTrue([self luaTestWithCheckAndTimeOut:3 setupCode:@"testTLSNoVerify()" checkCode:@"testTLSNoVerifyValues()"], @"testTLSNoVerify test failed");
}

- (void)testNoCallbackRead {
    RUN_LUA_TEST()
}

@end
