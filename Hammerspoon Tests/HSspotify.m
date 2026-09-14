#import "HSTestCase.h"

@interface HSspotify : HSTestCase

@end

@implementation HSspotify

- (void)setUp {
    [super setUpWithRequire:@"test_spotify"];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testIsRunningIgnoresWindowTitles {
    RUN_LUA_TEST()
}

@end
