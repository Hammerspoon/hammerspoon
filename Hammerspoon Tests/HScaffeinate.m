#import "HSTestCase.h"
#import <Carbon/Carbon.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

static IOReturn assertionResult;
static NSDictionary *assertionDictionary;

static IOReturn copyTestAssertions(CFDictionaryRef *assertions) {
    *assertions = CFBridgingRetain(assertionDictionary);
    return assertionResult;
}

// Compile the production callback with controlled IOKit results. Keep this copy's
// exported symbols separate from the extension loaded by the application.
#define IOPMCopyAssertionsByProcess copyTestAssertions
#define stringFromError caffeinateTestStringFromError
#define loginFramework caffeinateTestLoginFramework
#define luaopen_hs_libcaffeinate caffeinateTestLuaOpen
#import "../extensions/caffeinate/libcaffeinate.m"
#undef IOPMCopyAssertionsByProcess
#undef stringFromError
#undef loginFramework
#undef luaopen_hs_libcaffeinate

@interface HScaffeinate : HSTestCase
@end

@implementation HScaffeinate

- (void)setUp {
    [super setUp];
    assertionResult = kIOReturnSuccess;
    assertionDictionary = nil;
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    lua_State *L = skin.L;
    lua_pushcfunction(L, caffeinate_currentAssertions);
    lua_setglobal(L, "caffeinateTestCurrentAssertions");
}

- (void)tearDown {
    assertionDictionary = nil;
    [super tearDown];
}

- (void)testCurrentAssertionsWithNullResult {
    XCTAssertTrue([self luaTest:@"local a = caffeinateTestCurrentAssertions(); "
                               "assert(type(a) == 'table' and next(a) == nil); "
                               "return 'Success'"]);
}

- (void)testCurrentAssertionsWithError {
    assertionResult = kIOReturnError;
    XCTAssertTrue([self luaTest:@"local a = caffeinateTestCurrentAssertions(); "
                               "assert(type(a) == 'table' and next(a) == nil); "
                               "return 'Success'"]);
}

- (void)testCurrentAssertionsWithEmptyDictionary {
    assertionDictionary = @{};
    XCTAssertTrue([self luaTest:@"local a = caffeinateTestCurrentAssertions(); "
                               "assert(type(a) == 'table' and next(a) == nil); "
                               "return 'Success'"]);
}

- (void)testCurrentAssertionsWithPopulatedDictionary {
    assertionDictionary = @{@123: @[@{@"AssertType": @"PreventUserIdleDisplaySleep",
                                      @"AssertLevel": @1}]};
    XCTAssertTrue([self luaTest:@"local a = caffeinateTestCurrentAssertions(); "
                               "assert(type(a) == 'table'); "
                               "assert(a[123][1].AssertType == 'PreventUserIdleDisplaySleep'); "
                               "assert(a[123][1].AssertLevel == 1); "
                               "return 'Success'"]);
}

@end
