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
        // Put the Lua environment back so teatDown doesn't explode
        [skin createLuaState];
    }
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
    
    // Recreate the Lua environment so teatDown doesn't explode
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

@end
