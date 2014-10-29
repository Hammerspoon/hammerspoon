#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>
#import "spaces.h"

static NSNumber* getcurrentspace(void) {
    NSArray* spaces = (__bridge_transfer NSArray*)CGSCopySpaces(_CGSDefaultConnection(), kCGSSpaceCurrent);
    return [spaces objectAtIndex:0];
}

static NSArray* getspaces(void) {
    NSArray* spaces = (__bridge_transfer NSArray*)CGSCopySpaces(_CGSDefaultConnection(), kCGSSpaceAll);
    NSMutableArray* userSpaces = [NSMutableArray array];

    for (NSNumber* space in [spaces reverseObjectEnumerator]) {
        if (CGSSpaceGetType(_CGSDefaultConnection(), [space unsignedLongLongValue]) != kCGSSpaceSystem)
            [userSpaces addObject:space];
    }

    return userSpaces;
}

/// hs.spaces.count() -> number
/// Function
/// The number of spaces you currently have.
static int spaces_count(lua_State* L) {
    lua_pushnumber(L, [getspaces() count]);
    return 1;
}

/// hs.spaces.currentspace() -> number
/// Function
/// The index of the space you're currently on, 1-indexed (as usual).
static int spaces_currentspace(lua_State* L) {
    NSUInteger idx = [getspaces() indexOfObject:getcurrentspace()];

    if (idx == NSNotFound)
        lua_pushnil(L);
    else
        lua_pushnumber(L, idx + 1);

    return 1;
}

/// hs.spaces.movetospace(number)
/// Function
/// Switches to the space at the given index, 1-indexed (as usual).
static int spaces_movetospace(lua_State* L) {
    NSArray* spaces = getspaces();

    NSInteger toidx = luaL_checknumber(L, 1) - 1;
    NSInteger fromidx = [spaces indexOfObject:getcurrentspace()];

    BOOL worked = NO;

    if (toidx < 0 || fromidx == NSNotFound || toidx == fromidx || toidx >= [spaces count])
        goto finish;

    NSUInteger from = [[spaces objectAtIndex:fromidx] unsignedLongLongValue];
    NSUInteger to = [[spaces objectAtIndex:toidx] unsignedLongLongValue];

    CGSHideSpaces(_CGSDefaultConnection(), @[@(from)]);
    CGSShowSpaces(_CGSDefaultConnection(), @[@(to)]);
    CGSManagedDisplaySetCurrentSpace(_CGSDefaultConnection(), kCGSPackagesMainDisplayIdentifier, to);

    worked = YES;

finish:

    lua_pushboolean(L, worked);
    return 1;
}

static luaL_Reg spaceslib[] = {
    {"count",        spaces_count},
    {"currentspace", spaces_currentspace},
    {"movetospace",  spaces_movetospace},
    {NULL, NULL},
};

int luaopen_hs_spaces_internal(lua_State* L) {
    luaL_newlib(L, spaceslib);
    return 1;
}
