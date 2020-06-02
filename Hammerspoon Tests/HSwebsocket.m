//
//  hs.websocket Tests
//

#import "HSTestCase.h"

#define RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(timeout) [self twoPartTestName:_cmd withTimeout:timeout];

@interface HSwebsocket : HSTestCase

@end

@implementation HSwebsocket

- (void)setUp {
    [super setUpWithRequire:@"test_websocket"];
}

- (void)tearDown {
    [super tearDown];
}

- (void)twoPartTestName:(SEL)selector withTimeout:(NSTimeInterval)timeout {
    NSString *funcName = NSStringFromSelector(selector);
    [self luaTestWithCheckAndTimeOut:timeout setupCode:[funcName stringByAppendingString:@"()"] checkCode:[funcName stringByAppendingString:@"Values()"]];
}

- (void)testNew {
    RUN_LUA_TEST()
}

- (void)testEcho {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(8)
}

- (void)testOpenStatus {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(5)
}

- (void)testClosedStatus {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(5)
}

- (void)testClosingStatus {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(5)
}

- (void)testLegacy {
    RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(8)
}
@end
