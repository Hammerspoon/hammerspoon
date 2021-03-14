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
    RUN_LUA_TEST()
}

- (void)testAttributes {
    RUN_LUA_TEST()
}

@end
