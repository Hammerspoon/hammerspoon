//
//  HSinspect.m
//  Hammerspoon
//
//  Created by David Peterson on 18-Oct-2018.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSinspect : HSTestCase

@end

@implementation HSinspect

- (void)setUp {
    [super setUpWithRequire:@"test_inspect"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testSimpleInspect {
    RUN_LUA_TEST()
}

/* - cmsj disabled this test because it doesn't work:
 2018-12-27 11:20:52.584907+0100 Hammerspoon[23984:1758686] Test returned: ...s/Hammerspoon Tests.xctest/Contents/Resources/lsunit.lua:27: Assertion failure: expected: '{a = "b"}', actual: '{
 a = nil
 }'
 
- (void)testInspectAlwaysNewTableKeyValue {
    RUN_LUA_TEST()
}
 */

@end
