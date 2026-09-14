#import "HSTestCase.h"

@interface HSspaces : HSTestCase

@end

@implementation HSspaces

- (void)setUp {
    [super setUpWithRequire:@"test_spaces"];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testLoadWithoutDockProcess {
    RUN_LUA_TEST()
}

@end
