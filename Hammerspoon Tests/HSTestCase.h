//
//  HSTestCase.h
//  Hammerspoon
//
//  Created by Chris Jones on 01/02/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "LuaSkin/LuaSkin.h"
#import "MJLua.h"

#define RUN_LUA_TEST() XCTAssertTrue([self luaTestFromSelector:_cmd], @"Test failed: %@", NSStringFromSelector(_cmd));
#define RUN_TWO_PART_LUA_TEST_WITH_TIMEOUT(timeout) [self twoPartTestName:_cmd withTimeout:timeout];

#define SKIP_IN_TRAVIS() if(self.isTravis) { NSLog(@"Skipping %@ due to Travis", NSStringFromSelector(_cmd)) ; return; }
#define SKIP_IN_XCODE_SERVER() if(self.isXcodeServer) { NSLog(@"Skipping %@ due to Xcode Server", NSStringFromSelector(_cmd)) ; return; }
#define SKIP_IN_GITHUB_ACTIONS() if(self.isGitHubActions) { NSLog(@"Skipping %@ due to GitHub Actions", NSStringFromSelector(_cmd)) ; return; }

@interface HSTestCase : XCTestCase
@property (nonatomic) BOOL isTravis;
@property (nonatomic) BOOL isXcodeServer;
@property (nonatomic) BOOL isGitHubActions;

/**
 Sets up the testing environment and loads a Lua file with require()

 @param requireName The name of a Lua file to load (without the .lua suffix). This file should contain the Lua functions required to execute your tests
 */
- (void)setUpWithRequire:(NSString *)requireName;

/**
 Executes Lua code and returns its result

 @param luaCode An NSString containing some Lua code

 @return An NSString containing the result of the code
 */
- (NSString *)runLua:(NSString *)luaCode;

/**
 Executes Lua code and checks whether it returns the string "Success"

 @important This method does not assert anything, you should assert that it returns true

 @param luaCode An NSString containing some Lua code

 @return A boolean, true if the Lua code returned "Success" otherwise false
 */
- (BOOL)luaTest:(NSString *)luaCode;

/**
Executes a two-part Lua test with a timeout.

 This is similar to luaTestWithCheckAndTimeOut, but automatically finds the second function by appending `Values` to the first function.
 The second function will be called repeatedly until it either returns successfully, or timeout is reached.
 */
- (void)twoPartTestName:(SEL)selector withTimeout:(NSTimeInterval)timeout;

/**
 Executes a two-part Lua test with a timeout.

 The provided setup code is executed immediately, and then the supplied check code will be tested every 0.5 seconds until it either passes, or `timeout` is reached

 @param timeOut        The amount of time to allow the test to run unsuccessfully, before failing it
 @param setupCode      An NSString containing some Lua code to instantiate the test
 @param checkCode      An NSString containing some Lua code to check if the test has passed
 */
- (void)luaTestWithCheckAndTimeOut:(NSTimeInterval)timeOut setupCode:(NSString *)setupCode checkCode:(NSString *)checkCode;

/**
 Executes a Lua function with the same name as an Objective C selector. This reduces the amount of typing required in the Objective C portions of your tests - if you name your Lua test functions correctly, all you need to do is call [self luaTestFromSelector:_cmd] in each method. This is also neatly abstracted to a #define called RUN_LUA_TEST()

 @important This method does not assert anything, you should assert that it returns true

 @param selector A selector, which will be transformed into a string. A Lua function of the same name will be called

 @return A boolean, true if the test passed, otherwise false
 */
- (BOOL)luaTestFromSelector:(SEL)selector;

/**
 Determines if the test run is happening in the Travis CI build system, since we need to skip some tests in their environment

 @return A boolean, true if the test run is happening in Travis, false otherwise
 */
- (BOOL)runningInTravis;

/**
 Determines if the test run is happening in an Xcode Server  build system, since we need to skip some tests in that environment

 @return A boolean, true if the test run is happening in Xcode Server, false otherwise
 */
- (BOOL)runningInXcodeServer;

@end
