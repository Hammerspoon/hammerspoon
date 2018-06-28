//
//  HSdistributednotifications.m
//  Hammerspoon
//
//  Created by Chris Jones on 24/04/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import "HSTestCase.h"

@interface HSdistributednotifications : HSTestCase

@end

@implementation HSdistributednotifications

- (void)setUp {
    [super setUpWithRequire:@"test_distributednotifications"];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testdistributednotifications {
    [self luaTestWithCheckAndTimeOut:5 setupCode:@"testDistributedNotifications()" checkCode:@"testDistNotValueCheck()"];
}

@end
