#import "helpers.h"



/************************************************************************************************/

typedef int CGSConnection;
typedef int CGSWindow;
typedef int CGSValue;
extern CGSConnection _CGSDefaultConnection(void);
extern OSStatus CGSGetWindowCount(const CGSConnection cid, CGSConnection targetCID, int* outCount);
extern OSStatus CGSGetWindowList(const CGSConnection cid, CGSConnection targetCID, int count, int* list, int* outCount);
extern OSStatus CGSGetOnScreenWindowCount(const CGSConnection cid, CGSConnection targetCID, int* outCount);
extern OSStatus CGSGetOnScreenWindowList(const CGSConnection cid, CGSConnection targetCID, int count, int* list, int* outCount);
extern OSStatus CGSGetWindowLevel(const CGSConnection cid, CGSWindow wid,  int *level);
extern OSStatus CGSGetScreenRectForWindow(const CGSConnection cid, CGSWindow wid, CGRect *outRect);
extern OSStatus CGSGetWindowOwner(const CGSConnection cid, const CGSWindow wid, CGSConnection *ownerCid);
extern OSStatus CGSConnectionGetPID(const CGSConnection cid, pid_t *pid, const CGSConnection ownerCid);
extern OSStatus CGSGetConnectionIDForPSN(const CGSConnection cid, ProcessSerialNumber *psn, CGSConnection *out);
typedef uint64_t CGSSpace;
typedef enum _CGSSpaceType {
    kCGSSpaceUser,
    kCGSSpaceFullscreen,
    kCGSSpaceSystem,
    kCGSSpaceUnknown
} CGSSpaceType;
typedef enum _CGSSpaceSelector {
    kCGSSpaceCurrent = 5,
    kCGSSpaceOther = 6,
    kCGSSpaceAll = 7
} CGSSpaceSelector;

extern CFArrayRef CGSCopySpaces(const CGSConnection cid, CGSSpaceSelector type);
extern CFArrayRef CGSCopySpacesForWindows(const CGSConnection cid, CGSSpaceSelector type, CFArrayRef windows);
extern CGSSpaceType CGSSpaceGetType(const CGSConnection cid, CGSSpace space);

extern CFNumberRef CGSWillSwitchSpaces(const CGSConnection cid, CFArrayRef a);
extern void CGSHideSpaces(const CGSConnection cid, NSArray* spaces);
extern void CGSShowSpaces(const CGSConnection cid, NSArray* spaces);

extern void CGSAddWindowsToSpaces(const CGSConnection cid, CFArrayRef windows, CFArrayRef spaces);
extern void CGSRemoveWindowsFromSpaces(const CGSConnection cid, CFArrayRef windows, CFArrayRef spaces);
extern OSStatus CGSMoveWorkspaceWindowList(const CGSConnection connection, CGSWindow *wids, int count, int toWorkspace);

typedef uint64_t CGSManagedDisplay;
extern CGSManagedDisplay kCGSPackagesMainDisplayIdentifier;
extern void CGSManagedDisplaySetCurrentSpace(const CGSConnection cid, CGSManagedDisplay display, CGSSpace space);
/************************************************************************************************/







/// === spaces ===
///
/// Experimental API for Spaces support.


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

/// spaces.count() -> number
/// The number of spaces you currently have.
static int spaces_count(lua_State* L) {
    lua_pushnumber(L, [getspaces() count]);
    return 1;
}

/// spaces.currentspace() -> number
/// The index of the space you're currently on, 1-indexed (as usual).
static int spaces_currentspace(lua_State* L) {
    NSUInteger idx = [getspaces() indexOfObject:getcurrentspace()];
    
    if (idx == NSNotFound)
        lua_pushnil(L);
    else
        lua_pushnumber(L, idx + 1);
    
    return 1;
}

/// spaces.movetospace(number)
/// Switches to the space at the given index, 1-indexed (as usual).
/// CAUTION: this behaves very strangely on 10.9, for me at least. It probably works better on 10.8, and may not work at all on 10.10. Use at your own risk!
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
    {"count", spaces_count},
    {"currentspace", spaces_currentspace},
    {"movetospace", spaces_movetospace},
    {NULL, NULL},
};

int luaopen_spaces(lua_State* L) {
    luaL_newlib(L, spaceslib);
    return 1;
}
