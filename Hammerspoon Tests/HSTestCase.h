//
//  HSTestCase.h
//  Hammerspoon
//
//  Created by Chris Jones on 01/02/2016.
//  Copyright © 2016 Hammerspoon. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "MJLua.h"

#define RUN_LUA_TEST() XCTAssertTrue([self luaTestFromSelector:_cmd], @"Test failed: %@", NSStringFromSelector(_cmd));
#define SKIP_IN_TRAVIS() if(self.isTravis) { NSLog(@"Skipping %@ due to Travis", NSStringFromSelector(_cmd)) ; return; }

@interface HSTestCase : XCTestCase
@property (nonatomic) BOOL isTravis;

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
@end
