//
//  hs.serial Tests
//

#import "HSTestCase.h"

@interface HSserial : HSTestCase

@end

@implementation HSserial

- (void)setUp {
    [super setUpWithRequire:@"test_serial"];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testAvailablePortNames {
    RUN_LUA_TEST()
}

- (void)testAvailablePortPaths {
    RUN_LUA_TEST()
}

- (void)testNewFromName {
    RUN_LUA_TEST()
}

- (void)testNewFromPath {
    RUN_LUA_TEST()
}

- (void)testOpenAndClose {
    SKIP_IN_GITHUB_ACTIONS()
    RUN_LUA_TEST()
}

- (void)testAttributes {
    SKIP_IN_GITHUB_ACTIONS()
    RUN_LUA_TEST()
}

@end
