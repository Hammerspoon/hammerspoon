#import "HSTestCase.h"

@interface HSimage : HSTestCase

@end

@implementation HSimage

- (void)setUp {
  [super setUpWithRequire:@"test_image"];
  // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the class.
  [super tearDown];
}

- (void)testGetExifFromPath {
  RUN_LUA_TEST()
}

@end
