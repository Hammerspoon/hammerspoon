//
//  hs.websocket Tests
//

#import "HSTestCase.h"

@interface HSwebsocket : HSTestCase

@end

@implementation HSwebsocket

- (void)setUp {
    [super setUpWithRequire:@"test_websocket"];
    [self runLua:@"startEchoServer()"];
}

- (void)tearDown {
    [self runLua:@"stopEchoServer()"];
    [super tearDown];
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
