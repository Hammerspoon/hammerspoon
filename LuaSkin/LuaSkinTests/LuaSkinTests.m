//
//  LuaSkinTests.m
//  LuaSkinTests
//
//  Created by Chris Jones on 11/06/2015.
//  Copyright (c) 2015 Hammerspoon Product Authors. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
@import LuaSkin;
//#import "Skin.h"

#pragma mark - Defines

#define RUN_LUA_TEST() XCTAssertTrue([self luaTestFromSelector:_cmd], @"Test failed: %@", NSStringFromSelector(_cmd));
#define SKIP_IN_TRAVIS() if(self.isTravis) { NSLog(@"Skipping %@ due to Travis", NSStringFromSelector(_cmd)) ; return; }

#pragma mark - Utility C functions

static void stackDump (lua_State *L) {
    int i;
    int top = lua_gettop(L);
    for (i = 1; i <= top; i++) {  /* repeat for each level */
        int t = lua_type(L, i);
        switch (t) {

            case LUA_TSTRING:  /* strings */
                printf("`%s'", lua_tostring(L, i));
                break;

            case LUA_TBOOLEAN:  /* booleans */
                printf(lua_toboolean(L, i) ? "true" : "false");
                break;

            case LUA_TNUMBER:  /* numbers */
                printf("%g", lua_tonumber(L, i));
                break;

            default:  /* other values */
                printf("%s", lua_typename(L, t));
                break;

        }
        printf("  ");  /* put a separator */
    }
    printf("\n");  /* end the listing */
}

#pragma mark - Library test functions/data

char *libraryTestName = "testLibrary";
BOOL libraryGCCalled = NO;
BOOL libraryObjectGCCalled = NO;

static int libraryTestNew(lua_State *L) {
    lua_Number *testValue = lua_newuserdata(L, sizeof(lua_Number));
    luaL_getmetatable(L, libraryTestName);
    lua_setmetatable(L, -2);

    *testValue = lua_tonumber(L, 1);

    NSLog(@"libraryTestNew:Set testValue to: %f", *testValue);
    return 1;
}

static int libraryTestDoThing(lua_State *L) {
    lua_pushnumber(L, lua_tonumber(L, 1) + 1);
    return 1;
}

static int libraryTestGC(lua_State *L) {
    libraryGCCalled = YES;
    return 0;
}

static int libraryTestObjectDoThing(lua_State *L) {
    lua_Number *testValue = luaL_checkudata(L, 1, libraryTestName);
    lua_pushnumber(L, *(testValue) + 1);
    NSLog(@"libraryTestObjectDoThing:Pushed: %f", *(testValue) + 1);
    return 1;
}

static int libraryTestCauseException(lua_State *L) {
    NSMutableDictionary *testDict = [[NSMutableDictionary alloc] initWithCapacity:1];
    NSString *key = @"testKey";
    NSString *value = nil;

    [testDict setObject:value forKey:key];
    lua_pushstring(L, "NEVERSEE");
    return 1;
}

static int libraryTestObjectGC(lua_State *L) {
    libraryObjectGCCalled = YES;
    return 0;
}

static const luaL_Reg functions[] = {
    {"new", libraryTestNew},
    {"doThing", libraryTestDoThing},
    {"causeException", libraryTestCauseException},
    {NULL, NULL}
};

static const luaL_Reg metaFunctions[] = {
    {"__gc", libraryTestGC},
    {NULL, NULL}
};

static const luaL_Reg objectFunctions[] = {
    {"doObjectThing", libraryTestObjectDoThing},
    {"__gc", libraryTestObjectGC},
    {NULL, NULL}
};

@interface LuaSkinUserdataTestType : NSObject
@end

@implementation LuaSkinUserdataTestType
@end

static int pushTestUserData(lua_State *L, id object) {
    lua_pushinteger(L, 682568);
    return 1;
}

@interface LSTestDelegate<LuaSkinDelegate> : NSObject
@property int lastLevel;
@property (nonatomic, copy) NSString *lastMessage;
@end

@implementation LSTestDelegate

- (void)logForLuaSkinAtLevel:(int)level withMessage:(NSString *)theMessage {
    self.lastLevel = level;
    self.lastMessage = theMessage;
}

@end

#pragma mark - Test case harness definition

@interface LuaSkinTests : XCTestCase
@property LuaSkin *skin;
@property LSRefTable refTable;
@property int evalfn;
@end

#pragma mark - Test case harness implementation

@implementation LuaSkinTests

- (void)setUp {
    [super setUp];
    self.skin = [LuaSkin sharedWithState:NULL];
    libraryGCCalled = NO;
    libraryObjectGCCalled = NO;

    // Find where our bundle is on disk
    NSDictionary *environment = [NSProcessInfo processInfo].environment;

    NSString *xcTestConfigurationFilePath = environment[@"XCTestConfigurationFilePath"];
    NSRange chopPoint = [xcTestConfigurationFilePath rangeOfString:@"LuaSkinTests.xctest/Contents/Resources/"];
    NSString *bundlePath = nil;

    if (chopPoint.location == NSNotFound) {
        // We're probably running under Xcode 8.1 (and later?) which doesn't export XCTestConfigurationFilePath anymore
        //bundlePath = [NSString stringWithFormat:@"%@/LuaSkinTests.xctest/Contents/Resources/", environment[@"PWD"]];
        bundlePath = [[NSBundle bundleForClass:[self class]] resourcePath];
    } else {
        // We're probably running under Xcode 8.0 or earlier
        bundlePath = [xcTestConfigurationFilePath substringWithRange:NSMakeRange(0, chopPoint.location + chopPoint.length - 1)];
    }

    // Now find lsunit.lua within the bundle. It will end by require()ing our init.lua
    NSString *lsUnitPath = [NSString stringWithFormat:@"%@/lsunit.lua", bundlePath];

    // Prepare a refTable
    lua_newtable(self.skin.L);
    self.refTable = luaL_ref(self.skin.L, LUA_REGISTRYINDEX);

    // Load init.lua from our bundle
    NSLog(@"Loading LuaSkinTests lsunit.lua from %@", lsUnitPath);
    int loadresult = luaL_loadfile(self.skin.L, [lsUnitPath UTF8String]);
    if (loadresult != 0) {
        NSLog(@"ERROR: Unable to load lsunit.lua from %@", lsUnitPath);
        NSException *loadException = [NSException exceptionWithName:@"LuaSkinTestsLSInitLoadfileFailed" reason:[NSString stringWithFormat:@"Unable to load lsunit.lua from %@", lsUnitPath] userInfo:nil];
        @throw loadException;
    }

    [self.skin pushNSObject:bundlePath];
    BOOL result = [self.skin protectedCallAndTraceback:1 nresults:1];
    if (!result) {
        NSLog(@"ERROR: lsunit.lua instantiation failed: %@", @(lua_tostring(self.skin.L, -1)));
        NSException *pcallException = [NSException exceptionWithName:@"LuaSkinTestsLSUnitPCallFailed" reason:@"An error occurred when executing LuaSkinTests lsunit.lua" userInfo:nil];
        @throw pcallException;
    }

    // Capture the evaluation function that lsunit.lua returned
    self.evalfn = [self.skin luaRef:self.refTable];
}

- (void)tearDown {
    [self.skin resetLuaState];
    [super tearDown];
}

- (BOOL)runLuaFunction:(NSString *)functionName {
    [self.skin pushLuaRef:self.refTable ref:self.evalfn];
    if (!lua_isfunction(self.skin.L, -1)) {
        NSLog(@"ERROR: evalfn is not a function");
        if (lua_isstring(self.skin.L, -1)) {
            NSLog(@"evalfn is a string: %s", lua_tostring(self.skin.L, -1));
        }
        return NO;
    }

    lua_pushstring(self.skin.L, [[NSString stringWithFormat:@"%@()", functionName] UTF8String]);
    return [self.skin protectedCallAndTraceback:1 nresults:1];
}

- (BOOL)runLuaFunctionFromSelector:(SEL)selector {
    NSString *functionName = NSStringFromSelector(selector);
    return [self runLuaFunction:functionName];
}

- (NSString *)runLua:(NSString *)luaCode {
    [self.skin pushLuaRef:self.refTable ref:self.evalfn];
    if (!lua_isfunction(self.skin.L, -1)) {
        NSLog(@"ERROR: evalfn is not a function");
        if (lua_isstring(self.skin.L, -1)) {
            NSLog(@"evalfn is a string: %s", lua_tostring(self.skin.L, -1));
        }
        return @"";
    }

    lua_pushstring(self.skin.L, [luaCode UTF8String]);
    [self.skin protectedCallAndTraceback:1 nresults:1];

    return @(lua_tostring(self.skin.L, -1));
}

- (BOOL)luaTest:(NSString *)luaCode {
    NSString *result = [self runLua:luaCode];
    NSLog(@"Test returned: %@ for: %@", result, luaCode);
    return [result isEqualToString:@"Success"];
}

- (BOOL)luaTestWithCheckAndTimeOut:(NSTimeInterval)timeOut setupCode:(NSString *)setupCode checkCode:(NSString *)checkCode {
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeOut];
    BOOL result = NO;

    [self runLua:setupCode];

    while (result == NO && ([timeoutDate timeIntervalSinceNow] > 0)) {
        CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0.5, NO);
        result = [self luaTest:checkCode];
    }

    return result;
}
- (BOOL)luaTestFromSelector:(SEL)selector {
    NSString *funcName = NSStringFromSelector(selector);
    NSLog(@"Calling Lua function from selector: %@()", funcName);
    return [self luaTest:[NSString stringWithFormat:@"%@()", funcName]];
}

- (BOOL)runningInTravis {
    return (getenv("TRAVIS") != NULL);
}

// Tests of the above methods

- (void)testrunLua {
    NSString *result = [self runLua:@"return 'hello world!'"];
    XCTAssertEqualObjects(@"hello world!", result, @"Lua code evaluation is not working");
}

- (void)testTestLuaSuccess {
    [self luaTest:@"return 'Success'"];
}

- (void)testSkinInit {
    XCTAssertNotNil(self.skin);
}

- (void)testSingletonality {
    XCTAssertEqual([LuaSkin sharedWithState:NULL], [LuaSkin sharedWithState:NULL]);
}

- (void)testBackgroundThreadCatcher {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Blocked background thread execution"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        @try {
            LuaSkin *bg_skin = [LuaSkin sharedWithState:NULL];
            NSLog(@"Created skin: %@", bg_skin); // This should never be executed
        }
        @catch (NSException *exception) {
            if ([exception.name isEqualToString:@"LuaOnNonMainThread"]) {
                [expectation fulfill];
            }
        }
    });

    [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
        if (error) {
            NSLog(@"Timeout Error: %@", error);
        }
    }];
}
- (void)testLuaStateCreation {
    XCTAssert((self.skin.L != NULL));
}

- (void)testLuaStateDoubleCreation {
    XCTAssertThrowsSpecificNamed([self.skin createLuaState], NSException, NSInternalInconsistencyException);
}

- (void)testLuaStateDestruction {
    [self.skin destroyLuaState];
    XCTAssert((self.skin.L == NULL));
    // Put the Lua environment back so tearDown doesn't explode
    [self.skin createLuaState];
}

- (void)testLuaStateDoubleDestruction {
    [self.skin destroyLuaState];

    @try {
        // This should throw an NSInternalInconsistencyException
        [self.skin destroyLuaState];
    }
    @catch (NSException *exception) {
        if (exception.name != NSInternalInconsistencyException) {
            XCTFail(@"Double Destruction raised the wrong kind of exception: %@", exception.name);
        }
    }
    @finally {
        // Put the Lua environment back so tearDown doesn't explode
        [self.skin createLuaState];
    }
}

- (void)testLuaStateRecreation {
    lua_State *oldState = self.skin.L;
    [self.skin resetLuaState];
    XCTAssertNotEqual(oldState, self.skin.L, @"lua_State was not replaced by resetLuaState");
}

- (void)testLuaCanExecute {
    int result = luaL_dostring(self.skin.L, "print('Lua executes')");
    XCTAssertFalse(result);
}

- (void)testLuaCanFailToExecute {
    int result = luaL_dostring(self.skin.L, "invalid mumbojumbo");
    XCTAssertTrue(result);
}

- (void)testProtectedCall {
    int loadResult = luaL_loadstring(self.skin.L, "print('Lua protected execution works')");
    XCTAssertFalse(loadResult);
    BOOL pcallResult = [self.skin protectedCallAndError:@"testProtectedCall" nargs:0 nresults:0];
    XCTAssertTrue(pcallResult);
}

- (void)testProtectedCallWithFailure {
    int loadResult = luaL_loadstring(self.skin.L, "require('impossible_module')");
    XCTAssertFalse(loadResult);
    BOOL pcallResult = [self.skin protectedCallAndError:@"testProtectedCallWithFailure" nargs:0 nresults:0];
    XCTAssertFalse(pcallResult);
}

- (void)testLibrary {
    [self.skin registerLibrary:"testLibrary" functions:functions metaFunctions:metaFunctions];

    // Normally we'd be returning to a luaopen_ function after registerLibrary, and thus the library would be inserted into the right namespace. Since we're not doing that here, we'll just go ahead and register it as a global, using the library name
    lua_setglobal(self.skin.L, libraryTestName);

    // Call a function from the test library and test its return value
    luaL_loadstring(self.skin.L, "return testLibrary.doThing(4)");
    [self.skin protectedCallAndTraceback:0 nresults:1];
    XCTAssertEqual(lua_tonumber(self.skin.L, -1), 5);

    // Now test that the library's __gc function gets called
    [self.skin destroyLuaState];
    XCTAssertTrue(libraryGCCalled);

    // Recreate the Lua environment so tearDown doesn't explode
    [self.skin createLuaState];
}

- (void)testLibraryWithObjects {
    [self.skin registerLibraryWithObject:libraryTestName functions:functions metaFunctions:metaFunctions objectFunctions:objectFunctions];
    // Normally we'd be returning to a luaopen_ function after registerLibrary, and thus the library would be inserted into the right namespace. Since we're not doing that here, we'll just go ahead and register it as a global, using the library name
    lua_setglobal(self.skin.L, libraryTestName);

    // Create a library object, call a method on it and test its return value
    luaL_loadstring(self.skin.L, "return testLibrary.new(12):doObjectThing()");
    [self.skin protectedCallAndTraceback:0 nresults:1];
    stackDump(self.skin.L);
    XCTAssertEqual(lua_tonumber(self.skin.L, -1), 13);

    // Now test that the library's __gc function gets called
    [self.skin destroyLuaState];
    XCTAssertTrue(libraryGCCalled);

    // Now test that the library object's __gc function gets called
    XCTAssertTrue(libraryObjectGCCalled);

    // Recreate the Lua environment so teatDown doesn't explode
    [self.skin createLuaState];
}

- (void)testPerformanceLuaStateLifecycle {
    [self measureBlock:^{
        [self.skin destroyLuaState];
        [self.skin createLuaState];
    }];
}

- (void)testLuaRefs {
    NSString *testString = @"LUAREF_TEST";

    // Set up a table for the refs
    lua_newtable(self.skin.L);
    int tableRef = luaL_ref(self.skin.L, LUA_REGISTRYINDEX);

    XCTAssertNotEqual(LUA_REFNIL, tableRef, @"tableRef creation returned LUA_REFNIL");
    XCTAssertNotEqual(LUA_NOREF, tableRef, @"tableRef creation returned LUA_NOREF");

    // Test that reffing a nil fails with LUA_REFNIL
    lua_pushnil(self.skin.L);
    XCTAssertEqual(LUA_REFNIL, [self.skin luaRef:tableRef], @"reffing a nil did not return LUA_REFNIL");

    lua_pushstring(self.skin.L, [testString UTF8String]);
    int ref = [self.skin luaRef:tableRef atIndex:-1];

    XCTAssertNotEqual(LUA_NOREF, ref, @"luaRef returned LUA_NOREF");
    XCTAssertNotEqual(LUA_NOREF, ref, @"luaRef returned LUA_REFNIL");
    XCTAssertGreaterThanOrEqual(ref, 0, @"luaRef returned negative ref");

    [self.skin pushLuaRef:tableRef ref:ref];

    NSString *resultString = @(lua_tostring(self.skin.L, -1));

    XCTAssertEqualObjects(testString, resultString, @"Reffed string did not come back the same");

    ref = [self.skin luaUnref:tableRef ref:ref];

    XCTAssertEqual(LUA_NOREF, ref, @"luaUnref did not return LUA_NOREF");

    @try {
        // This should throw an NSInternalInconsistencyException
        [self.skin pushLuaRef:tableRef ref:ref];
    }
    @catch (NSException *exception) {
        if (exception.name != NSInternalInconsistencyException) {
            XCTFail(@"Double Destruction raised the wrong kind of exception: %@", exception.name);
        }
    }

    int refType = [self.skin pushLuaRef:tableRef ref:99999];
    XCTAssertEqual(LUA_TNIL, refType);

}

- (void)testCheckArgs {
    XCTestExpectation *expectation = [self expectationWithDescription:@"checkArgsTypes"];

    const char *userDataType = "LuaSkinUserdataTestType";
    const luaL_Reg userDataMetaTable[] = {
        {NULL, NULL},
    };
    [self.skin registerObject:userDataType objectFunctions:userDataMetaTable];

    lua_settop(self.skin.L, 0);

    lua_pushnil(self.skin.L);
    lua_pushboolean(self.skin.L, true);
    lua_pushnumber(self.skin.L, 5.2);
    lua_pushinteger(self.skin.L, 12);
    lua_pushstring(self.skin.L, "This is a string");
    lua_newtable(self.skin.L);
    luaL_loadstring(self.skin.L, "function foo() end");
    lua_newuserdata(self.skin.L, sizeof(void *));
    luaL_getmetatable(self.skin.L, userDataType);
    lua_setmetatable(self.skin.L, -2);
    lua_pushnil(self.skin.L);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.skin checkArgs:LS_TNIL, LS_TBOOLEAN, LS_TNUMBER, LS_TNUMBER | LS_TINTEGER, LS_TSTRING, LS_TTABLE, LS_TFUNCTION, LS_TUSERDATA, userDataType, LS_TANY, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK];
        [expectation fulfill];
    });

    [self waitForExpectationsWithTimeout:1.0 handler:^(NSError *error) {
        if (error) {
            NSLog(@"testCheckArgs error: %@", error);
        } else {
            NSLog(@"testCheckArgs no error");
        }
    }];

    // FIXME: This test does nothing to test failure conditions. It's hard because luaL_error() is involved, and it calls abort().
    // It seems like we need to set a lua_atpanic() function and have that long jump to safety to prevent the abort(), but what can we jump to?
}

- (void)testCheckRefs {
    int valid = 4;
    int also_valid = 28;
    int not_valid = LUA_REFNIL;
    int also_not_valid = LUA_NOREF;

    XCTAssertTrue(LS_RBREAK < LUA_REFNIL);
    XCTAssertTrue(LS_RBREAK < LUA_NOREF);

    BOOL result;

    result = [self.skin checkRefs:valid, LS_RBREAK];
    XCTAssertTrue(result);
    result = [self.skin checkRefs:valid, also_valid, LS_RBREAK];
    XCTAssertTrue(result);

    result = [self.skin checkRefs:not_valid, LS_RBREAK];
    XCTAssertFalse(result);
    result = [self.skin checkRefs:not_valid, also_not_valid, LS_RBREAK];
    XCTAssertFalse(result);
    result = [self.skin checkRefs:valid, not_valid, LS_RBREAK];
    XCTAssertFalse(result);
}

- (void)testLuaTypeAtIndex {
    lua_State *L = self.skin.L ;

    lua_newtable(L) ;
    lua_newtable(L) ;
    luaL_loadstring(L, "function foo() end") ;
    lua_setfield(L, -2, "__call") ;
    lua_setmetatable(L, -2) ;
    XCTAssertEqual(LUA_TFUNCTION, [self.skin luaTypeAtIndex:-1]) ;
    lua_pop(L, 1) ;

    lua_newtable(L) ;
    lua_newtable(L) ;
    luaL_loadstring(L, "function foo() end") ;
    lua_setfield(L, -2, "__notcall") ;
    lua_setmetatable(L, -2) ;
    XCTAssertEqual(LUA_TTABLE, [self.skin luaTypeAtIndex:-1]) ;
    lua_pop(L, 1) ;
}

- (void)testPushNSObject {
    LSTestDelegate *testDelegate = [[LSTestDelegate alloc] init];
    self.skin.delegate = testDelegate;

    // Test pushing an NSString (note that in this case we test the return value. There are only two return points in pushNSObject, so subsequent tests only re-test the return value if they are expecting something other than 1
    NSString *pushString = @"Test push string";
    XCTAssertEqual(1, [self.skin pushNSObject:pushString]);
    XCTAssertEqualObjects(pushString, @(lua_tostring(self.skin.L, -1)));

    // Test pushing an NSNull
    [self.skin pushNSObject:[NSNull null]];
    XCTAssertEqual(LUA_TNIL, lua_type(self.skin.L, -1));

    // Test pushing boolean objects
    [self.skin pushNSObject:@YES];
    XCTAssertEqual(YES, lua_toboolean(self.skin.L, -1));
    [self.skin pushNSObject:@NO];
    XCTAssertEqual(NO, lua_toboolean(self.skin.L, -1));

    // Test pushing an NSArray
    [self.skin pushNSObject:@[@"1", @"2"]];
    XCTAssertEqual(LUA_TTABLE, lua_type(self.skin.L, -1));

    // Test pushing NSNumber variants
    [self.skin pushNSObject:[NSNumber numberWithInt:42]];
    XCTAssertEqual(42, lua_tointeger(self.skin.L, -1));

    [self.skin pushNSObject:[NSNumber numberWithChar:'f']];
    XCTAssertEqual('f', lua_tointeger(self.skin.L, -1));

    [self.skin pushNSObject:[NSNumber numberWithUnsignedChar:'g']];
    XCTAssertEqual('g', lua_tointeger(self.skin.L, -1));

    [self.skin pushNSObject:[NSNumber numberWithFloat:28.37]];
    XCTAssertEqualWithAccuracy(28.37, lua_tonumber(self.skin.L, -1), 0.01);

    // Test pushing an NSDictionary
    [self.skin pushNSObject:@{@"1" : @"foo", @"2" : @"bar"}];
    XCTAssertEqual(LUA_TTABLE, lua_type(self.skin.L, -1));

    // Test pushing an NSURL
    [self.skin pushNSObject:[NSURL URLWithString:@"http://www.hammerspoon.org"]];
    XCTAssertEqualObjects(@"http://www.hammerspoon.org", @(lua_tostring(self.skin.L, -1)));

    // Test pushing an unrecognised type
    [self.skin pushNSObject:[[NSObject alloc] init]];
    XCTAssertEqual(LUA_TNIL, lua_type(self.skin.L, -1));

    // Test pushing an unrecognised type, with an option to convert unknown types to string descriptions
    [self.skin pushNSObject:[[NSObject alloc] init] withOptions:LS_NSDescribeUnknownTypes];
    XCTAssertEqual(LUA_TSTRING, lua_type(self.skin.L, -1));

    // Test pushing an unrecognised type, with an option to ignore unknown types
    XCTAssertEqual(0, [self.skin pushNSObject:[[NSObject alloc] init] withOptions:LS_NSIgnoreUnknownTypes]);

    // Test pushing nil
    [self.skin pushNSObject:nil];
    XCTAssertEqual(LUA_TNIL, lua_type(self.skin.L, -1));

    // Test pushing an NSDate
    NSDate *now = [NSDate date];
    [self.skin pushNSObject:now];
    XCTAssertEqual(lround([now timeIntervalSince1970]), lua_tointeger(self.skin.L, -1));

    // Test pushing an NSData
    [self.skin pushNSObject:[@("NSData test") dataUsingEncoding:NSUTF8StringEncoding]];
    XCTAssertEqualObjects(@("NSData test"), @(lua_tostring(self.skin.L, -1)));

    // Test pushing an NSSet
    [self.skin pushNSObject:[NSSet set]];
    XCTAssertEqual(LUA_TTABLE, lua_type(self.skin.L, -1));

    // Test pushing an object which contains itself
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-circular-container"
    NSMutableDictionary *selfRefDict = [NSMutableDictionary dictionary];
    selfRefDict[@"self"] = selfRefDict;
#pragma clang diagnostic pop
    [self.skin pushNSObject:selfRefDict];
    XCTAssertEqual(LUA_TTABLE, lua_type(self.skin.L, -1));

    const char *userDataType = "LuaSkinUserdataTestType";
    const luaL_Reg userDataMetaTable[] = {
        {NULL, NULL},
    };
    [self.skin registerObject:userDataType objectFunctions:userDataMetaTable];
    [self.skin registerPushNSHelper:pushTestUserData forClass:"LuaSkinUserdataTestType"];
    LuaSkinUserdataTestType *testObject = [[LuaSkinUserdataTestType alloc] init];
    [self.skin pushNSObject:testObject];
    XCTAssertEqual(682568, lua_tointeger(self.skin.L, -1));

    // Push the helper again, since that should not explode
    [self.skin registerPushNSHelper:pushTestUserData forClass:"LuaSkinUserdataTestType"];
    XCTAssertTrue([testDelegate.lastMessage containsString:@"LuaSkinUserdataTestType already defined"]);

    // Push nonsense
    [self.skin registerPushNSHelper:nil forClass:NULL];
    XCTAssertTrue([testDelegate.lastMessage containsString:@"requires both helperFN and className"]);

}

- (void)testPushStructInNSValue {

    // Push NSRect in NSValue
    [self.skin pushNSObject:[NSValue valueWithRect:NSMakeRect(5, 6, 7, 8)]];
    XCTAssertEqual(LUA_TSTRING, lua_getfield(self.skin.L, -1, "__luaSkinType"));
    XCTAssertEqualObjects(@"NSRect", @(lua_tostring(self.skin.L, -1))) ;
    lua_pop(self.skin.L, 1);
    XCTAssertEqual(LUA_TNUMBER, lua_getfield(self.skin.L, -1, "x"));
    XCTAssertEqual(5, lua_tointeger(self.skin.L, -1));
    lua_pop(self.skin.L, 1);
    XCTAssertEqual(LUA_TNUMBER, lua_getfield(self.skin.L, -1, "y"));
    XCTAssertEqual(6, lua_tointeger(self.skin.L, -1));
    lua_pop(self.skin.L, 1);
    XCTAssertEqual(LUA_TNUMBER, lua_getfield(self.skin.L, -1, "w"));
    XCTAssertEqual(7, lua_tointeger(self.skin.L, -1));
    lua_pop(self.skin.L, 1);
    XCTAssertEqual(LUA_TNUMBER, lua_getfield(self.skin.L, -1, "h"));
    XCTAssertEqual(8, lua_tointeger(self.skin.L, -1));
    lua_pop(self.skin.L, 1);

    // Push NSPoint in NSValue
    [self.skin pushNSObject:[NSValue valueWithPoint:NSMakePoint(12, 13)]];
    XCTAssertEqual(LUA_TSTRING, lua_getfield(self.skin.L, -1, "__luaSkinType"));
    XCTAssertEqualObjects(@"NSPoint", @(lua_tostring(self.skin.L, -1))) ;
    lua_pop(self.skin.L, 1);
    XCTAssertEqual(LUA_TNUMBER, lua_getfield(self.skin.L, -1, "x"));
    XCTAssertEqual(12, lua_tointeger(self.skin.L, -1));
    lua_pop(self.skin.L, 1);
    XCTAssertEqual(LUA_TNUMBER, lua_getfield(self.skin.L, -1, "y"));
    XCTAssertEqual(13, lua_tointeger(self.skin.L, -1));
    lua_pop(self.skin.L, 1);

    // Push NSSize in NSValue
    [self.skin pushNSObject:[NSValue valueWithSize:NSMakeSize(88, 89)]];
    XCTAssertEqual(LUA_TSTRING, lua_getfield(self.skin.L, -1, "__luaSkinType"));
    XCTAssertEqualObjects(@"NSSize", @(lua_tostring(self.skin.L, -1))) ;
    lua_pop(self.skin.L, 1);
    XCTAssertEqual(LUA_TNUMBER, lua_getfield(self.skin.L, -1, "w"));
    XCTAssertEqual(88, lua_tointeger(self.skin.L, -1));
    lua_pop(self.skin.L, 1);
    XCTAssertEqual(LUA_TNUMBER, lua_getfield(self.skin.L, -1, "h"));
    XCTAssertEqual(89, lua_tointeger(self.skin.L, -1));
    lua_pop(self.skin.L, 1);

    // Push NSRange in NSValue
    [self.skin pushNSObject:[NSValue valueWithRange:NSMakeRange(42, 10)]];
    XCTAssertEqual(LUA_TSTRING, lua_getfield(self.skin.L, -1, "__luaSkinType"));
    XCTAssertEqualObjects(@"NSRange", @(lua_tostring(self.skin.L, -1))) ;
    lua_pop(self.skin.L, 1);
    XCTAssertEqual(LUA_TNUMBER, lua_getfield(self.skin.L, -1, "location"));
    XCTAssertEqual(42, lua_tointeger(self.skin.L, -1));
    lua_pop(self.skin.L, 1);
    XCTAssertEqual(LUA_TNUMBER, lua_getfield(self.skin.L, -1, "length"));
    XCTAssertEqual(10, lua_tointeger(self.skin.L, -1));
    lua_pop(self.skin.L, 1);

    // Push arbitrary struct in NSValue
    typedef struct { double d; int i; unsigned int ui; } otherStruct ;
    otherStruct holder ;
    holder.d = 95.7 ;
    holder.i = -101 ;
    // original test only had the double and the int... in practice that meant that 12 of the 16 bytes were in use; usually the filler is \x00, but not always, thus the data comparison was sometimes failing because of the filler bytes... This makes all 16 bytes in use, thus specific and valid for comparison.
    holder.ui = 101 ;
    [self.skin pushNSObject:[NSValue valueWithBytes:&holder objCType:@encode(otherStruct)]] ;
    XCTAssertEqual(LUA_TSTRING, lua_getfield(self.skin.L, -1, "__luaSkinType"));
    XCTAssertEqualObjects(@"NSValue", @(lua_tostring(self.skin.L, -1))) ;
    lua_pop(self.skin.L, 1);
    XCTAssertEqual(LUA_TSTRING, lua_getfield(self.skin.L, -1, "objCType"));
    XCTAssertEqualObjects(@(@encode(otherStruct)), @(lua_tostring(self.skin.L, -1))) ;
    lua_pop(self.skin.L, 1);
    // FIXME: alignedSize may go away in the future... is there a way to say "if it's here, it should be X, but if it's not, we don't really care?"
    XCTAssertEqual(LUA_TNUMBER, lua_getfield(self.skin.L, -1, "alignedSize"));
    XCTAssertEqual(8, lua_tointeger(self.skin.L, -1)) ;
    lua_pop(self.skin.L, 1);
    const char bytes[] = "\xCD\xCC\xCC\xCC\xCC\xEC\x57\x40\x9B\xFF\xFF\xFF\x65\x00\x00\x00" ;
    size_t     length  = (sizeof bytes) - 1 ; // remove trailing implicit \x00 all C-strings get
    XCTAssertEqual(LUA_TNUMBER, lua_getfield(self.skin.L, -1, "actualSize"));
    XCTAssertEqual(length, lua_tointeger(self.skin.L, -1)) ;
    lua_pop(self.skin.L, 1);
    XCTAssertEqual(LUA_TSTRING, lua_getfield(self.skin.L, -1, "data"));
    XCTAssertEqualObjects([NSData dataWithBytes:bytes length:length],
                          [self.skin toNSObjectAtIndex:-1 withOptions:LS_NSLuaStringAsDataOnly]);
    // lua_pop(self.skin.L, 1); // skip - we'll need the data in the next subtest

    lua_getglobal(self.skin.L, "string");
    lua_getfield(self.skin.L, -1, "unpack");
    lua_remove(self.skin.L, -2);
    // @encode includes some wrapper stuff that confuses string.pack.  Eventually, there will be a
    // function/method to convert field objCType to what string.pack/unpack can use; for now, hard code it.
    lua_pushstring(self.skin.L, "diI");
    lua_pushvalue(self.skin.L, -3); // data from previous subtest
    lua_pcall(self.skin.L, 2, 4, 0);
    XCTAssertEqual(LUA_TNUMBER, lua_type(self.skin.L, -4));
    XCTAssertEqual(95.7, lua_tonumber(self.skin.L, -4)) ;
    XCTAssertEqual(LUA_TNUMBER, lua_type(self.skin.L, -3));
    XCTAssertEqual(-101, lua_tointeger(self.skin.L, -3)) ;
    XCTAssertEqual(LUA_TNUMBER, lua_type(self.skin.L, -2));
    XCTAssertEqual(101, lua_tointeger(self.skin.L, -2)) ;
    XCTAssertEqual(LUA_TNUMBER, lua_type(self.skin.L, -1));
    XCTAssertEqual(17, lua_tointeger(self.skin.L, -1)) ;    // first unused position in packed data
    lua_pop(self.skin.L, 4); // string.unpack results and the data from the previous subtest
}

- (void)testToNSObject {
    lua_pushnumber(self.skin.L, 4.2);
    XCTAssertEqualObjects(@(4.2), [self.skin toNSObjectAtIndex:-1]);

    lua_pushinteger(self.skin.L, 88);
    XCTAssertEqualObjects(@(88), [self.skin toNSObjectAtIndex:-1]);

    lua_pushstring(self.skin.L, "Testing toNSObject");
    XCTAssertEqualObjects(@"Testing toNSObject", [self.skin toNSObjectAtIndex:-1]);

    lua_pushnil(self.skin.L);
    XCTAssertEqualObjects(nil, [self.skin toNSObjectAtIndex:-1]);

    lua_pushboolean(self.skin.L, YES);
    XCTAssertEqualObjects(@YES, [self.skin toNSObjectAtIndex:-1]);

    lua_pushboolean(self.skin.L, NO);
    XCTAssertEqualObjects(@NO, [self.skin toNSObjectAtIndex:-1]);

    lua_newtable(self.skin.L);
    lua_pushnumber(self.skin.L, 1);
    lua_pushstring(self.skin.L, "First item");
    lua_settable(self.skin.L, -3);
    lua_pushnumber(self.skin.L, 2);
    lua_pushstring(self.skin.L, "Second item");
    lua_settable(self.skin.L, -3);

    NSArray *expectedArray = @[@"First item", @"Second item"];
    XCTAssertEqualObjects(expectedArray, [self.skin toNSObjectAtIndex:-1]);

    lua_newtable(self.skin.L);
    lua_pushstring(self.skin.L, "First");
    lua_pushstring(self.skin.L, "Item one");
    lua_settable(self.skin.L, -3);
    lua_pushstring(self.skin.L, "Second");
    lua_pushstring(self.skin.L, "Item two");
    lua_settable(self.skin.L, -3);

    NSDictionary *expectedDict = @{@"First" : @"Item one", @"Second" : @"Item two"};
    XCTAssertEqualObjects(expectedDict, [self.skin toNSObjectAtIndex:-1]);

    // FIXME: This doesn't test userdata conversion
}

- (void)testTableToNSRect {
    NSRect expected = NSMakeRect(10, 20, 30, 40);

    lua_newtable(self.skin.L);
    lua_pushnumber(self.skin.L, expected.origin.x); lua_setfield(self.skin.L, -2, "x");
    lua_pushnumber(self.skin.L, expected.origin.y); lua_setfield(self.skin.L, -2, "y");
    lua_pushnumber(self.skin.L, expected.size.width); lua_setfield(self.skin.L, -2, "w");
    lua_pushnumber(self.skin.L, expected.size.height); lua_setfield(self.skin.L, -2, "h");

    NSRect actual = [self.skin tableToRectAtIndex:lua_absindex(self.skin.L, -1)];

    XCTAssertEqual(expected.origin.x, actual.origin.x);
    XCTAssertEqual(expected.origin.y, actual.origin.y);
    XCTAssertEqual(expected.size.width, actual.size.width);
    XCTAssertEqual(expected.size.height, actual.size.height);

    lua_pushnil(self.skin.L);
    actual = [self.skin tableToRectAtIndex:lua_absindex(self.skin.L, -1)];

    XCTAssertEqual(0, actual.origin.x);
    XCTAssertEqual(0, actual.origin.y);
    XCTAssertEqual(0, actual.size.width);
    XCTAssertEqual(0, actual.size.height);

    // Test the degenerate case where the Lua table is empty
    lua_newtable(self.skin.L);
    expected = NSZeroRect;
    actual = [self.skin tableToRectAtIndex:lua_absindex(self.skin.L, -1)];
    XCTAssertEqual(expected.origin.x, actual.origin.x);
    XCTAssertEqual(expected.origin.y, actual.origin.y);
    XCTAssertEqual(expected.size.width, actual.size.width);
    XCTAssertEqual(expected.size.height, actual.size.height);
}

- (void)testTableToNSPoint {
    NSPoint expected = NSMakePoint(10, 20);

    lua_newtable(self.skin.L);
    lua_pushnumber(self.skin.L, expected.x); lua_setfield(self.skin.L, -2, "x");
    lua_pushnumber(self.skin.L, expected.y); lua_setfield(self.skin.L, -2, "y");

    NSPoint actual = [self.skin tableToPointAtIndex:lua_absindex(self.skin.L, -1)];

    XCTAssertEqual(expected.x, actual.x);
    XCTAssertEqual(expected.y, actual.y);

    lua_pushnil(self.skin.L);
    actual = [self.skin tableToPointAtIndex:lua_absindex(self.skin.L, -1)];

    XCTAssertEqual(0, actual.x);
    XCTAssertEqual(0, actual.y);

    // Test the degenerate case where the Lua table is empty
    lua_newtable(self.skin.L);
    expected = NSZeroPoint;
    actual = [self.skin tableToPointAtIndex:lua_absindex(self.skin.L, -1)];
    XCTAssertEqual(expected.x, actual.x);
    XCTAssertEqual(expected.y, actual.y);
}

- (void)testTableToNSSize {
    NSSize expected = NSMakeSize(30, 40);

    lua_newtable(self.skin.L);
    lua_pushnumber(self.skin.L, expected.width); lua_setfield(self.skin.L, -2, "w");
    lua_pushnumber(self.skin.L, expected.height); lua_setfield(self.skin.L, -2, "h");

    NSSize actual = [self.skin tableToSizeAtIndex:lua_absindex(self.skin.L, -1)];

    XCTAssertEqual(expected.width, actual.width);
    XCTAssertEqual(expected.height, actual.height);

    lua_pushnil(self.skin.L);
    actual = [self.skin tableToSizeAtIndex:lua_absindex(self.skin.L, -1)];

    XCTAssertEqual(0, actual.width);
    XCTAssertEqual(0, actual.height);

    // Test the degenerate case where the Lua table is empty
    lua_newtable(self.skin.L);
    expected = NSZeroSize;
    actual = [self.skin tableToSizeAtIndex:lua_absindex(self.skin.L, -1)];
    XCTAssertEqual(expected.width, actual.width);
    XCTAssertEqual(expected.height, actual.height);
}

// TODO: add testTableWithLabel to check on registered functions that can create an object from a table, like NSColor from hs.drawing.color and NSAttributedString from hs.styledtext's table form

- (void)testTableWithLabelToNSValue {
    // test __luaSkinType == "NSRect"
    NSRect expectedRect = NSMakeRect(10, 20, 30, 40);
    lua_newtable(self.skin.L);
    lua_pushstring(self.skin.L, "NSRect"); lua_setfield(self.skin.L, -2, "__luaSkinType");
    lua_pushnumber(self.skin.L, expectedRect.origin.x); lua_setfield(self.skin.L, -2, "x");
    lua_pushnumber(self.skin.L, expectedRect.origin.y); lua_setfield(self.skin.L, -2, "y");
    lua_pushnumber(self.skin.L, expectedRect.size.width); lua_setfield(self.skin.L, -2, "w");
    lua_pushnumber(self.skin.L, expectedRect.size.height); lua_setfield(self.skin.L, -2, "h");
    NSValue *actualValue = [self.skin toNSObjectAtIndex:-1] ;
    NSRect actualRect = [actualValue rectValue] ;
    XCTAssertEqual(expectedRect.origin.x, actualRect.origin.x);
    XCTAssertEqual(expectedRect.origin.y, actualRect.origin.y);
    XCTAssertEqual(expectedRect.size.width, actualRect.size.width);
    XCTAssertEqual(expectedRect.size.height, actualRect.size.height);

    // test __luaSkinType == "NSPoint"
    NSPoint expectedPoint = NSMakePoint(10, 20);
    lua_newtable(self.skin.L);
    lua_pushstring(self.skin.L, "NSPoint"); lua_setfield(self.skin.L, -2, "__luaSkinType");
    lua_pushnumber(self.skin.L, expectedPoint.x); lua_setfield(self.skin.L, -2, "x");
    lua_pushnumber(self.skin.L, expectedPoint.y); lua_setfield(self.skin.L, -2, "y");
    actualValue = [self.skin toNSObjectAtIndex:-1] ;
    NSPoint actualPoint = [actualValue pointValue];
    XCTAssertEqual(expectedPoint.x, actualPoint.x);
    XCTAssertEqual(expectedPoint.y, actualPoint.y);

    // test __luaSkinType == "NSSize"
    NSSize expectedSize = NSMakeSize(30, 40);
    lua_newtable(self.skin.L);
    lua_pushstring(self.skin.L, "NSSize"); lua_setfield(self.skin.L, -2, "__luaSkinType");
    lua_pushnumber(self.skin.L, expectedSize.width); lua_setfield(self.skin.L, -2, "w");
    lua_pushnumber(self.skin.L, expectedSize.height); lua_setfield(self.skin.L, -2, "h");
    actualValue = [self.skin toNSObjectAtIndex:-1] ;
    NSSize actualSize = [actualValue sizeValue];
    XCTAssertEqual(expectedSize.width, actualSize.width);
    XCTAssertEqual(expectedSize.height, actualSize.height);

    // test __luaSkinType == "NSRange"
    NSRange expectedRange = NSMakeRange(42, 10);
    lua_newtable(self.skin.L);
    lua_pushstring(self.skin.L, "NSRange"); lua_setfield(self.skin.L, -2, "__luaSkinType");
    lua_pushnumber(self.skin.L, expectedRange.location); lua_setfield(self.skin.L, -2, "location");
    lua_pushnumber(self.skin.L, expectedRange.length); lua_setfield(self.skin.L, -2, "length");
    actualValue = [self.skin toNSObjectAtIndex:-1] ;
    NSRange actualRange = [actualValue rangeValue];
    XCTAssertEqual(expectedRange.location, actualRange.location);
    XCTAssertEqual(expectedRange.length, actualRange.length);

    // test __luaSkinType == "NSValue"
    lua_newtable(self.skin.L) ;
    lua_pushstring(self.skin.L, "NSValue") ; lua_setfield(self.skin.L, -2, "__luaSkinType");
    lua_pushstring(self.skin.L, "{?=diI}") ; lua_setfield(self.skin.L, -2, "objCType") ;
    lua_getglobal(self.skin.L, "string");
    lua_getfield(self.skin.L, -1, "pack");
    lua_remove(self.skin.L, -2);
    lua_pushstring(self.skin.L, "diI") ;
    lua_pushnumber(self.skin.L, 95.7) ;
    lua_pushinteger(self.skin.L, -101) ;
    lua_pushinteger(self.skin.L, 101) ;
    lua_pcall(self.skin.L, 4, 1, 0) ;
    lua_setfield(self.skin.L, -2, "data") ;
    NSValue *value = [self.skin toNSObjectAtIndex:-1] ;
    typedef struct { double d; int i; unsigned int ui; } otherStruct ;
    otherStruct holder ;
    [value getValue:&holder] ;
    XCTAssertEqual(95.7, holder.d);
    XCTAssertEqual(-101, holder.i);
    XCTAssertEqual(101, holder.ui);

}

- (void)testIsValidUTF8AtIndex {
    lua_pushnil(self.skin.L);
    XCTAssertFalse([self.skin isValidUTF8AtIndex:-1]);

    lua_pushstring(self.skin.L, "٩(-̮̮̃-̃)۶ ٩(●̮̮̃•̃)۶ ٩(͡๏̯͡๏)۶ ٩(-̮̮̃•̃).");
    XCTAssertTrue([self.skin isValidUTF8AtIndex:-1]);

    // \x81 is invalid UTF8 if immediately preceded by a character with a hex value < \xC2
    lua_pushstring(self.skin.L, "hello\x81there");
    XCTAssertFalse([self.skin isValidUTF8AtIndex:-1]);

    // FIXME: Thie should have lots more tests, including some that contain invalid UTF8
}

- (void) testMaxNatIndexAndCountNatIndex {
    lua_newtable(self.skin.L);
    lua_pushstring(self.skin.L, "a"); lua_rawseti(self.skin.L, -2, luaL_len(self.skin.L, -2) + 1) ;
    lua_pushstring(self.skin.L, "b"); lua_rawseti(self.skin.L, -2, luaL_len(self.skin.L, -2) + 1) ;
    lua_pushstring(self.skin.L, "c"); lua_rawseti(self.skin.L, -2, luaL_len(self.skin.L, -2) + 1) ;
    XCTAssertTrue([self.skin maxNatIndex:-1] == [self.skin countNatIndex:-1]);
    XCTAssertEqual(3, [self.skin maxNatIndex:-1]);
    XCTAssertEqual(3, [self.skin countNatIndex:-1]);
    lua_pushstring(self.skin.L, "d"); lua_setfield(self.skin.L, -2, "four");
    XCTAssertFalse([self.skin maxNatIndex:-1] == [self.skin countNatIndex:-1]);
    XCTAssertEqual(3, [self.skin maxNatIndex:-1]);
    XCTAssertEqual(4, [self.skin countNatIndex:-1]);

}
- (void)testLogging {
    XCTestExpectation *expectation = nil;

    dispatch_block_t logBlock = ^{
        self.skin = [LuaSkin sharedWithState:NULL];
        LSTestDelegate *testDelegate = [[LSTestDelegate alloc] init];
        self.skin.delegate = testDelegate;

        [self.skin logBreadcrumb:@"breadcrumb"];
        XCTAssertEqualObjects(@"breadcrumb", testDelegate.lastMessage);

        [self.skin logVerbose:@"verbose"];
        XCTAssertEqualObjects(@"verbose", testDelegate.lastMessage);

        [self.skin logInfo:@"info"];
        XCTAssertEqualObjects(@"info", testDelegate.lastMessage);

        [self.skin logDebug:@"debug"];
        XCTAssertEqualObjects(@"debug", testDelegate.lastMessage);

        [self.skin logWarn:@"warn"];
        XCTAssertEqualObjects(@"warn", testDelegate.lastMessage);

        [self.skin logError:@"error"];
        XCTAssertEqualObjects(@"error", testDelegate.lastMessage);


        [LuaSkin logBreadcrumb:@"breadcrumb"];
        XCTAssertEqualObjects(@"breadcrumb", testDelegate.lastMessage);

        [LuaSkin logVerbose:@"verbose"];
        XCTAssertEqualObjects(@"verbose", testDelegate.lastMessage);

        [LuaSkin logInfo:@"info"];
        XCTAssertEqualObjects(@"info", testDelegate.lastMessage);

        [LuaSkin logDebug:@"debug"];
        XCTAssertEqualObjects(@"debug", testDelegate.lastMessage);

        [LuaSkin logWarn:@"warn"];
        XCTAssertEqualObjects(@"warn", testDelegate.lastMessage);

        [LuaSkin logError:@"error"];
        XCTAssertEqualObjects(@"error", testDelegate.lastMessage);

        [expectation fulfill];
    };


    if ([NSThread isMainThread]) {
        NSLog(@"Running testLogging on main thread");
        logBlock();
    } else {
        NSLog(@"Running testLogging from non-main thread");
        expectation = [self expectationWithDescription:@"testLogging"];

        dispatch_sync(dispatch_get_main_queue(), logBlock);

        [self waitForExpectationsWithTimeout:2.0 handler:^(NSError *error) {
            if (error) {
                NSLog(@"testLogging error: %@", error);
            } else {
                NSLog(@"testLogging no error");
            }
        }];
    }

    // FIXME: The async version of this seems to not be getting called. We should invoke twice, one time explicitly async
}

- (void)testRequire {
    XCTAssertTrue([self.skin requireModule:"lsunit"]);
}

- (void)testNatIndexFailure {
    // countNatIndex is effectively covered by other tests, but not its failure path
    lua_pushnil(self.skin.L);
    XCTAssertEqual(0, [self.skin countNatIndex:-1]);

    // maxNatIndex too
    lua_pushnil(self.skin.L);
    XCTAssertEqual(0, [self.skin maxNatIndex:-1]);
}

- (void)testTracebackWithTag {
    NSString *result = [self.skin tracebackWithTag:@"testTag" fromStackPos:-1];
    XCTAssertTrue([result containsString:@"testTag"]);
    XCTAssertTrue([result containsString:@"stack traceback:"]);
}

id luaObjectHelperTestFunction(lua_State *L, int idx) {
    return @(lua_tonumber(L, idx));
}

- (void)testLuaObjectHelper {
    XCTAssertTrue([self.skin registerLuaObjectHelper:luaObjectHelperTestFunction forClass:"luaObjectHelperTestObject"]);
    lua_pushnumber(self.skin.L, 429);
    XCTAssertEqualObjects(@(429), [self.skin luaObjectAtIndex:-1 toClass:"luaObjectHelperTestObject"]);

    // Attempt a double-registration of the helper function, so we see it fail
    XCTAssertFalse([self.skin registerLuaObjectHelper:luaObjectHelperTestFunction forClass:"luaObjectHelperTestObject"]);

    // Attempt a mangled registration, so we see it fail
    XCTAssertFalse([self.skin registerLuaObjectHelper:nil forClass:nil]);

    // Attempt to convert a Lua value with an unregistered helper name, so we see it fail
    XCTAssertNil([self.skin luaObjectAtIndex:-1 toClass:"someFunctionThatDoesNotExist"]);

    // Test the userdata mapped variants
    XCTAssertTrue([self.skin registerLuaObjectHelper:luaObjectHelperTestFunction forClass:"luaObjectHelperTestUserdata" withUserdataMapping:"luaskin.testObjectHelper"]);
    XCTAssertFalse([self.skin registerLuaObjectHelper:luaObjectHelperTestFunction forClass:"luaObjectHelperTestUserdata" withUserdataMapping:"luaskin.testObjectHelper"]);
}

- (void)testObjCExceptionHandler {
    [self.skin registerLibrary:"LuaSkinTests" functions:functions metaFunctions:metaFunctions];

    // Normally we'd be returning to a luaopen_ function after registerLibrary, and thus the library would be inserted into the right namespace. Since we're not doing that here, we'll just go ahead and register it as a global, using the library name
    lua_setglobal(self.skin.L, libraryTestName);

    // Call a function from the test library and test its return value
    luaL_loadstring(self.skin.L, "return testLibrary.causeException()");
    BOOL pCallResult = [self.skin protectedCallAndTraceback:0 nresults:1];
    XCTAssertFalse(pCallResult);

    NSString *result = @(lua_tostring(self.skin.L, -1));

    XCTAssertNotEqualObjects(@"NEVERSEE", result);
    XCTAssertTrue([result containsString:@"NSInvalidArgumentException"]);
}

@end
