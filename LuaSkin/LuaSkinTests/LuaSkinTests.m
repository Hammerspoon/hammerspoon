//
//  LuaSkinTests.m
//  LuaSkinTests
//
//  Created by Chris Jones on 11/06/2015.
//  Copyright (c) 2015 Hammerspoon Product Authors. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <XCTest/XCTest.h>
#import "Skin.h"

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

static int libraryTestObjectGC(lua_State *L) {
    libraryObjectGCCalled = YES;
    return 0;
}

static const luaL_Reg functions[] = {
    {"new", libraryTestNew},
    {"doThing", libraryTestDoThing},
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

#pragma mark - Test case harness definition

@interface LuaSkinTests : XCTestCase {
    LuaSkin *skin;
}

@end

#pragma mark - Test case harness implementation

@implementation LuaSkinTests

- (void)setUp {
    [super setUp];
    skin = [[LuaSkin alloc] init];
    libraryGCCalled = NO;
    libraryObjectGCCalled = NO;

    // Find where our bundle is on disk
    NSDictionary *environment = [NSProcessInfo processInfo].environment;
    NSString *xcTestConfigurationFilePath = environment[@"XCTestConfigurationFilePath"];
    NSRange chopPoint = [xcTestConfigurationFilePath rangeOfString:@"LuaSkinTests.xctest/Contents/Resources/"];
    NSString *bundlePath = [xcTestConfigurationFilePath substringWithRange:NSMakeRange(0, chopPoint.location + chopPoint.length - 1)];

    // Now find lsunit.lua within the bundle. It will end by require()ing our init.lua
    NSString *lsUnitPath = [NSString stringWithFormat:@"%@/lsunit.lua", bundlePath];

    // Load init.lua from our bundle
    NSLog(@"Loading LuaSkinTests lsunit.lua from %@", lsUnitPath);
    int loadresult = luaL_loadfile(skin.L, [lsUnitPath UTF8String]);
    if (loadresult != 0) {
        NSLog(@"ERROR: Unable to load lsunit.lua from LuaSkinTests.xctest");
        NSException *loadException = [NSException exceptionWithName:@"LuaSkinTestsLSInitLoadfileFailed" reason:@"Unable to load lsunit.lua from LuaSkinTests.xctest" userInfo:nil];
        @throw loadException;
    }

    [skin pushNSObject:bundlePath];
    BOOL result = [skin protectedCallAndTraceback:1 nresults:0];
    if (!result) {
        NSLog(@"ERROR: lsunit.lua instantiation failed: %@", @(lua_tostring(skin.L, -1)));
        NSException *pcallException = [NSException exceptionWithName:@"LuaSkinTestsLSUnitPCallFailed" reason:@"An error occurred when executing LuaSkinTests lsunit.lua" userInfo:nil];
        @throw pcallException;
    }
}

- (void)tearDown {
    [skin destroyLuaState];
    [super tearDown];
}

- (void)testSkinInit {
    XCTAssertNotNil(skin);
}

- (void)testSingletonality {
    XCTAssertEqual([LuaSkin shared], [LuaSkin shared]);
}

- (void)testBackgroundThreadCatcher {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Blocked background thread execution"];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(void){
        @try {
            LuaSkin *bg_skin = [LuaSkin shared];
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
    XCTAssert((skin.L != NULL));
}

- (void)testLuaStateDoubleCreation {
    XCTAssertThrowsSpecificNamed([skin createLuaState], NSException, NSInternalInconsistencyException);
}

- (void)testLuaStateDestruction {
    [skin destroyLuaState];
    XCTAssert((skin.L == NULL));
    // Put the Lua environment back so tearDown doesn't explode
    [skin createLuaState];
}

- (void)testLuaStateDoubleDestruction {
    [skin destroyLuaState];
    
    @try {
        // This should throw an NSInternalInconsistencyException
        [skin destroyLuaState];
    }
    @catch (NSException *exception) {
        if (exception.name != NSInternalInconsistencyException) {
            XCTFail(@"Double Destruction raised the wrong kind of exception: %@", exception.name);
        }
    }
    @finally {
        // Put the Lua environment back so tearDown doesn't explode
        [skin createLuaState];
    }
}

- (void)testLuaStateRecreation {
    lua_State *oldState = skin.L;
    [skin resetLuaState];
    XCTAssertNotEqual(oldState, skin.L, @"lua_State was not replaced by resetLuaState");
}

- (void)testLuaCanExecute {
    int result = luaL_dostring(skin.L, "print('Lua executes')");
    XCTAssertFalse(result);
}

- (void)testLuaCanFailToExecute {
    int result = luaL_dostring(skin.L, "invalid mumbojumbo");
    XCTAssertTrue(result);
}

- (void)testProtectedCall {
    int loadResult = luaL_loadstring(skin.L, "print('Lua protected execution works')");
    XCTAssertFalse(loadResult);
    BOOL pcallResult = [skin protectedCallAndTraceback:0 nresults:0];
    XCTAssertTrue(pcallResult);
}

- (void)testProtectedCallWithFailure {
    int loadResult = luaL_loadstring(skin.L, "require('impossible_module')");
    XCTAssertFalse(loadResult);
    BOOL pcallResult = [skin protectedCallAndTraceback:0 nresults:0];
    XCTAssertFalse(pcallResult);
}

- (void)testLibrary {
    [skin registerLibrary:functions metaFunctions:metaFunctions];
    
    // Normally we'd be returning to a luaopen_ function after registerLibrary, and thus the library would be inserted into the right namespace. Since we're not doing that here, we'll just go ahead and register it as a global, using the library name
    lua_setglobal(skin.L, libraryTestName);
    
    // Call a function from the test library and test its return value
    luaL_loadstring(skin.L, "return testLibrary.doThing(4)");
    [skin protectedCallAndTraceback:0 nresults:1];
    XCTAssertEqual(lua_tonumber(skin.L, -1), 5);

    // Now test that the library's __gc function gets called
    [skin destroyLuaState];
    XCTAssertTrue(libraryGCCalled);
    
    // Recreate the Lua environment so tearDown doesn't explode
    [skin createLuaState];
}

- (void)testLibraryWithObjects {
    [skin registerLibraryWithObject:libraryTestName functions:functions metaFunctions:metaFunctions objectFunctions:objectFunctions];
    // Normally we'd be returning to a luaopen_ function after registerLibrary, and thus the library would be inserted into the right namespace. Since we're not doing that here, we'll just go ahead and register it as a global, using the library name
    lua_setglobal(skin.L, libraryTestName);
    
    // Create a library object, call a method on it and test its return value
    luaL_loadstring(skin.L, "return testLibrary.new(12):doObjectThing()");
    [skin protectedCallAndTraceback:0 nresults:1];
    stackDump(skin.L);
    XCTAssertEqual(lua_tonumber(skin.L, -1), 13);

    // Now test that the library's __gc function gets called
    [skin destroyLuaState];
    XCTAssertTrue(libraryGCCalled);

    // Now test that the library object's __gc function gets called
    XCTAssertTrue(libraryObjectGCCalled);

    // Recreate the Lua environment so teatDown doesn't explode
    [skin createLuaState];
}

- (void)testPerformanceLuaStateLifecycle {
    [self measureBlock:^{
        [skin destroyLuaState];
        [skin createLuaState];
    }];
}

- (void)testLuaRefs {
    NSString *testString = @"LUAREF_TEST";

    // Set up a table for the refs
    lua_newtable(skin.L);
    int tableRef = luaL_ref(skin.L, LUA_REGISTRYINDEX);

    XCTAssertNotEqual(LUA_REFNIL, tableRef, @"tableRef creation returned LUA_REFNIL");
    XCTAssertNotEqual(LUA_NOREF, tableRef, @"tableRef creation returned LUA_NOREF");

    // Test that reffing a nil fails with LUA_REFNIL
    lua_pushnil(skin.L);
    XCTAssertEqual(LUA_REFNIL, [skin luaRef:tableRef], @"reffing a nil did not return LUA_REFNIL");

    lua_pushstring(skin.L, [testString UTF8String]);
    int ref = [skin luaRef:tableRef atIndex:-1];

    XCTAssertNotEqual(LUA_NOREF, ref, @"luaRef returned LUA_NOREF");
    XCTAssertNotEqual(LUA_NOREF, ref, @"luaRef returned LUA_REFNIL");
    XCTAssertGreaterThanOrEqual(ref, 0, @"luaRef returned negative ref");

    [skin pushLuaRef:tableRef ref:ref];

    NSString *resultString = @(lua_tostring(skin.L, -1));

    XCTAssertEqualObjects(testString, resultString, @"Reffed string did not come back the same");

    ref = [skin luaUnref:tableRef ref:ref];

    XCTAssertEqual(LUA_NOREF, ref, @"luaUnref did not return LUA_NOREF");

    @try {
        // This should throw an NSInternalInconsistencyException
        [skin pushLuaRef:tableRef ref:ref];
    }
    @catch (NSException *exception) {
        if (exception.name != NSInternalInconsistencyException) {
            XCTFail(@"Double Destruction raised the wrong kind of exception: %@", exception.name);
        }
    }

    int refType = [skin pushLuaRef:tableRef ref:99999];
    XCTAssertEqual(LUA_TNIL, refType);

}

- (void)testCheckArgs {
    XCTestExpectation *expectation = [self expectationWithDescription:@"checkArgsTypes"];

    const char *userDataType = "LuaSkinUserdataTestType";
    const luaL_Reg userDataMetaTable[] = {
        {NULL, NULL},
    };
    [skin registerObject:userDataType objectFunctions:userDataMetaTable];

    lua_settop(skin.L, 0);
    lua_pushnil(skin.L);
    lua_pushboolean(skin.L, true);
    lua_pushinteger(skin.L, 5);
    lua_pushstring(skin.L, "This is a string");
    lua_newtable(skin.L);
    luaL_loadstring(skin.L, "function foo() end");
    lua_newuserdata(skin.L, sizeof(void *));
    luaL_getmetatable(skin.L, userDataType);
    lua_setmetatable(skin.L, -2);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [skin checkArgs:LS_TNIL, LS_TBOOLEAN, LS_TNUMBER, LS_TSTRING, LS_TTABLE, LS_TFUNCTION, LS_TUSERDATA, userDataType, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK];
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

- (void)testPushNSObject {
    // Test pushing an NSString (note that in this case we test the return value. There are only two return points in pushNSObject, so subsequent tests only re-test the return value if they are expecting something other than 1
    NSString *pushString = @"Test push string";
    XCTAssertEqual(1, [skin pushNSObject:pushString]);
    XCTAssertEqualObjects(pushString, @(lua_tostring(skin.L, -1)));

    // Test pushing an NSNull
    [skin pushNSObject:[NSNull null]];
    XCTAssertEqual(LUA_TNIL, lua_type(skin.L, -1));

    // Test pushing an NSArray
    [skin pushNSObject:@[@"1", @"2"]];
    XCTAssertEqual(LUA_TTABLE, lua_type(skin.L, -1));

    // Test pushing an NSNumber
    [skin pushNSObject:[NSNumber numberWithInt:42]];
    XCTAssertEqual(42, lua_tointeger(skin.L, -1));

    // Test pushing an NSDictionary
    [skin pushNSObject:@{@"1" : @"foo", @"2" : @"bar"}];
    XCTAssertEqual(LUA_TTABLE, lua_type(skin.L, -1));

    // Test pushing an NSURL
    [skin pushNSObject:[NSURL URLWithString:@"http://www.hammerspoon.org"]];
    XCTAssertEqualObjects(@"http://www.hammerspoon.org", @(lua_tostring(skin.L, -1)));

    // Test pushing an unrecognised type
    [skin pushNSObject:[[NSObject alloc] init]];
    XCTAssertEqual(LUA_TNIL, lua_type(skin.L, -1));

    // Test pushing an unrecognised type, with an option to convert unknown types to string descriptions
    [skin pushNSObject:[[NSObject alloc] init] withOptions:LS_NSDescribeUnknownTypes];
    XCTAssertEqual(LUA_TSTRING, lua_type(skin.L, -1));

    // Test pushing an unrecognised type, with an option to ignore unknown types
    XCTAssertEqual(0, [skin pushNSObject:[[NSObject alloc] init] withOptions:LS_NSIgnoreUnknownTypes]);

    // Test pushing nil
    [skin pushNSObject:nil];
    XCTAssertEqual(LUA_TNIL, lua_type(skin.L, -1));

    // Test pushing an NSDate
    NSDate *now = [NSDate date];
    [skin pushNSObject:now];
    XCTAssertEqual(lround([now timeIntervalSince1970]), lua_tointeger(skin.L, -1));

    // Test pushing an NSData
    [skin pushNSObject:[@("NSData test") dataUsingEncoding:NSUTF8StringEncoding]];
    XCTAssertEqualObjects(@("NSData test"), @(lua_tostring(skin.L, -1)));

    // Test pushing an NSSet
    [skin pushNSObject:[NSSet set]];
    XCTAssertEqual(LUA_TTABLE, lua_type(skin.L, -1));

    // Test pushing an object which contains itself
    NSMutableDictionary *selfRefDict = [NSMutableDictionary dictionary];
    selfRefDict[@"self"] = selfRefDict;
    [skin pushNSObject:selfRefDict];
    XCTAssertEqual(LUA_TTABLE, lua_type(skin.L, -1));

    // FIXME: This does not yet test a push helper, all permutations of NSNumber
}

- (void)testLogging {
    // FIXME: This doesn't really test anything other than making sure we don't explode

    [skin logBreadcrumb:@"breadcrumb"];
    [skin logVerbose:@"verbose"];
    [skin logInfo:@"info"];
    [skin logDebug:@"debug"];
    [skin logWarn:@"warn"];
    [skin logError:@"error"];

    [LuaSkin logBreadcrumb:@"breadcrumb"];
    [LuaSkin logVerbose:@"verbose"];
    [LuaSkin logInfo:@"info"];
    [LuaSkin logDebug:@"debug"];
    [LuaSkin logWarn:@"warn"];
    [LuaSkin logError:@"error"];
}

- (void)testRequire {
    XCTAssertTrue([skin requireModule:"lsunit"]);
}
@end
