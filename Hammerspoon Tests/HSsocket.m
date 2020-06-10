//
//  HSsocket.m
//  Hammerspoon
//
//  Created by Michael Bujol on 02/12/2016.

#import "HSTestCase.h"

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

// TCP socket tests
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

- (void)testTcpUnixListenerSocketAttributes {
    RUN_LUA_TEST()
}

- (void)testUdpConnect {
    SKIP_IN_TRAVIS()
    RUN_LUA_TEST()
}

- (void)testUdpNoCallbacks {
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

- (void)testTcpUnixClientServerReadWriteBytes {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

- (void)testTcpTagging {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(10)
}

- (void)testTcpClientServerTimeout {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(3)
}

- (void)testTcpTls {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(10)
}

- (void)testTcpTlsRequiredByServer {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(10)
}

- (void)testTcpTlsVerifyPeer {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(10)
}

- (void)testTcpTlsVerifyBadPeerFails {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(10)
}

- (void)testTcpTlsNoVerify {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(10)
}

- (void)testTcpNoCallbackRead {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

- (void)testTcpParseAddress {
    RUN_LUA_TEST()
}

- (void)testTcpParseBadAddress {
    RUN_LUA_TEST()
}

// UDP socket tests
- (void)testUdpSocketInstanceCreation {
    RUN_LUA_TEST()
}

- (void)testUdpSocketInstanceCreationWithCallback {
    RUN_LUA_TEST()
}

- (void)testUdpListenerSocketCreation {
    RUN_LUA_TEST()
}

- (void)testUdpListenerSocketCreationWithCallback {
    RUN_LUA_TEST()
}

- (void)testUdpListenerSocketAttributes {
    RUN_LUA_TEST()
}

- (void)testUdpDisconnectAndReuse {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

- (void)testUdpAlreadyConnected {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

- (void)testUdpUserdataStrings {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

- (void)testUdpClientServerReceiveOnce {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

- (void)testUdpClientServerReceiveMany {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

- (void)testUdpBroadcast {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

- (void)testUdpReusePort {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

- (void)testUdpEnabledIpVersion {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

- (void)testUdpPreferredIpVersion {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

- (void)testUdpBufferSize {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(2)
}

@end
