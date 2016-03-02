//
//  HSsocket.m
//  Hammerspoon
//
//  Created by Michael Bujol on 02/12/2016.

#import "HSTestcase.h"
#pragma GCC diagnostic ignored "-Wgnu-statement-expression"

#define RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(timeout) XCTAssertTrue([self twoPartTestName:_cmd withTimeout:timeout], @"Test failed: %@", NSStringFromSelector(_cmd));

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

- (BOOL)twoPartTestName:(SEL)selector withTimeout:(NSTimeInterval)timeout {
    NSString *funcName = NSStringFromSelector(selector);
    return [self luaTestWithCheckAndTimeOut:timeout setupCode:[funcName stringByAppendingString:@"()"] checkCode:[funcName stringByAppendingString:@"Values()"]];
}

- (void)testTcpSocketInstanceCreation {
    RUN_LUA_TEST()
}

- (void)testTcpSocketInstanceCreationWithCallback {
    RUN_LUA_TEST()
}

- (void)testTcpListenerSocketCreation {
    RUN_LUA_TEST()
}

- (void)testTcpListenerSocketCreationWithCallback {
    RUN_LUA_TEST()
}

- (void)testTcpListenerSocketAttributes {
    RUN_LUA_TEST()
}

- (void)testTcpDisconnectAndReuse {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

- (void)testTcpConnected {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

- (void)testTcpAlreadyConnected {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

- (void)testTcpUserdataStrings {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

- (void)testTcpClientServerReadWriteDelimiter {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

- (void)testTcpClientServerReadWriteBytes {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

- (void)testTcpTagging {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(3)
}

- (void)testTcpClientServerTimeout {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(3)
}

- (void)testTls {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(3)
}

- (void)testNoTlsWhenRequiredByServer {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(3)
}

- (void)testTlsVerifyPeer {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(3)
}

- (void)testTlsVerifyBadPeerFails {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(3)
}

- (void)testTlsNoVerify {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(3)
}

- (void)testTcpNoCallbackRead {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

- (void)testParseAddress {
    RUN_LUA_TEST()
}

- (void)testParseBadAddress {
    RUN_LUA_TEST()
}

- (void)testUdpSocketCreation {
    RUN_LUA_TEST()
}

@end
