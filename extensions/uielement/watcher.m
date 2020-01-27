//
//  HSuielementwatcher.m
//  Hammerspoon
//
//  Created by Chris Jones on 12/01/2018.
//  Copyright © 2018 Hammerspoon. All rights reserved.
//

@import LuaSkin;

#import "../application/application.h"
#import "../window/window.h"
#import "uielement.h"

static const char* USERDATA_TAG = "hs.uielement.watcher";
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Helper functions

static void watcher_observer_callback(AXObserverRef observer __unused, AXUIElementRef element,
                                      CFStringRef notificationName, void* contextData) {
    LuaSkin *skin = [LuaSkin shared];
    HSuielementWatcher *watcher = (__bridge HSuielementWatcher *)contextData;

    [skin pushLuaRef:refTable ref:watcher.handlerRef]; // Callback function

    HSuielement *elementObj = [[HSuielement alloc] initWithElementRef:element];
    id pushObj = elementObj;
    if (elementObj.isWindow) {
        pushObj = [[HSwindow alloc] initWithAXUIElementRef:element];
    } else if ([elementObj.role isEqualToString:(__bridge NSString *)kAXApplicationRole]) {
        pid_t pid;
        AXUIElementGetPid(element, &pid);
        pushObj = [[HSapplication alloc] initWithPid:pid];
    }
    [skin pushNSObject:pushObj]; // Parameter 1: element
    lua_pushstring(skin.L, CFStringGetCStringPtr(notificationName, kCFStringEncodingASCII)); // Parameter 2: event
    [skin pushLuaRef:refTable ref:watcher.watcherRef];
    [skin pushLuaRef:refTable ref:watcher.userDataRef];

    if (![skin protectedCallAndTraceback:4 nresults:0]) {
        const char *errorMsg = lua_tostring(skin.L, -1);
        [skin logError:[NSString stringWithUTF8String:errorMsg]];
        lua_pop(skin.L, 1); // remove error message
    }
    return;
}

#pragma mark - HSuielementWatcher implementation
@implementation HSuielementWatcher

#pragma mark - Instance initialiser
-(HSuielementWatcher *)initWithElement:(HSuielement *)element callbackRef:(int)callbackRef userdataRef:(int)userdataRef{
    self = [super init];
    if (self) {
        _elementRef = element.elementRef;
        _selfRefCount = 0;
        _handlerRef = callbackRef;
        _userDataRef = userdataRef;
        _watcherRef = LUA_NOREF;
        _running = NO;
        AXUIElementGetPid(_elementRef, &_pid);
    }
    return self;
}

#pragma mark - Instance destructor
-(void)dealloc {
    // FIXME: Implement this, if necessary
}

#pragma mark - Instance methods

-(void)start:(NSArray <NSString *>*)events {
    LuaSkin *skin = [LuaSkin shared];
    if (self.running) {
        return;
    }

    // Create our observer
    AXObserverRef observer = NULL;
    AXError err = AXObserverCreate(self.pid, watcher_observer_callback, &observer);
    if (err != kAXErrorSuccess) {
        [skin logBreadcrumb:[NSString stringWithFormat:@"AXObserverCreate error: %d", (int)err]];
        return;
    }

    // Add specified events to the observer
    for (NSString *event in events) {
        AXObserverAddNotification(observer, self.elementRef, (__bridge CFStringRef)event, (__bridge void *)self);
    }

    self.observer = observer;
    self.running = YES;

    // Begin observing events
    CFRunLoopAddSource([[NSRunLoop currentRunLoop] getCFRunLoop],
                       AXObserverGetRunLoopSource(observer),
                       kCFRunLoopDefaultMode);
}

-(void)stop {
    if (!self.running) {
        return;
    }
    CFRunLoopRemoveSource([[NSRunLoop currentRunLoop] getCFRunLoop], AXObserverGetRunLoopSource(self.observer), kCFRunLoopDefaultMode);
    CFRelease(self.observer);
    self.running = NO;
}
@end

/// hs.uielement.watcher.new(element, callback[, userdata]) -> hs.uielement.watcher object
/// Function
/// Creates a new hs.uielement.watcher object for a given hs.uielement object
///
/// Paramters:
///  * element - An hs.uielement object
///  * callback - A function that will be called when events happen on the hs.uielement object. The function should accept four arguments:
///   * element - The element the event occurred on (which may not be the element being watched)
///   * event - A string containing the name of the event
///   * watcher - The hs.uielement.watcher object
///   * userdata - Some data you want to send along to the callback. This can be of any type
///
/// Returns:
///  * An hs.uielement.watcher object
static int watcher_new(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, "hs.uielement", LS_TFUNCTION, LS_TANY|LS_TOPTIONAL, LS_TBREAK];
    HSuielement *element = [skin toNSObjectAtIndex:1];
    int callbackRef = [skin luaRef:refTable atIndex:2];
    int userdataRef = LUA_NOREF;
    if (lua_type(L, 3) != LUA_TNONE) {
        userdataRef = [skin luaRef:refTable atIndex:3];
    }
    [skin pushNSObject:[element newWatcher:callbackRef withUserdata:userdataRef]];
    return 1;
}

static int watcher_start(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE, LS_TBREAK];
    HSuielementWatcher *watcher = [skin toNSObjectAtIndex:1];
    [watcher start:[skin toNSObjectAtIndex:2]];
    lua_pushvalue(L, 1);
    return 1;
}

static int watcher_stop(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSuielementWatcher *watcher = [skin toNSObjectAtIndex:1];
    [watcher stop];
    lua_pushvalue(L, 1);
    return 1;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSuielementWatcher(lua_State *L, id obj) {
    HSuielementWatcher *value = obj;
    value.selfRefCount++;
    void** valuePtr = lua_newuserdata(L, sizeof(HSuielementWatcher *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSuielementWatcherFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin shared];
    HSuielementWatcher *value;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSuielementWatcher, L, idx, USERDATA_TAG);
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                        lua_typename(L, lua_type(L, idx))]];
    }
    return value;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    lua_pushstring(L, [NSString stringWithFormat:@"%s: %p", USERDATA_TAG, lua_topointer(L, 1)].UTF8String);
    return 1 ;
}

static int userdata_eq(lua_State *L) {
    BOOL isEqual = NO;
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared];
        HSuielementWatcher *watcher1 = [skin toNSObjectAtIndex:1];
        HSuielementWatcher *watcher2 = [skin toNSObjectAtIndex:2];
        isEqual = [watcher1 isEqual:watcher2];
    }
    lua_pushboolean(L, isEqual);
    return 1;
}

// Perform cleanup if the watcher is not required anymore.
static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSuielementWatcher *watcher = get_objectFromUserdata(__bridge_transfer HSuielementWatcher, L, 1, USERDATA_TAG);
    if (watcher) {
        watcher.selfRefCount--;
        if (watcher.selfRefCount == 0) {
            [watcher stop];
            watcher.handlerRef = [skin luaUnref:refTable ref:watcher.handlerRef];
            watcher.userDataRef = [skin luaUnref:refTable ref:watcher.userDataRef];
            watcher = nil;
        }
    }
    return 0;
}

static const luaL_Reg moduleLib[] = {
    {"newWatcher", watcher_new},

    {NULL, NULL}
};

static const luaL_Reg module_metaLib[] = {
    {NULL, NULL}
};

static const luaL_Reg userdata_metaLib[] = {
    {"_start", watcher_start},
    {"_stop", watcher_stop},

    {"__tostring", userdata_tostring},
    {"__eq", userdata_eq},
    {"__gc", userdata_gc},

    {NULL, NULL}
};

int luaopen_hs_uielement_watcher(lua_State *L __unused) {
    LuaSkin *skin = [LuaSkin shared];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:moduleLib metaFunctions:module_metaLib objectFunctions:userdata_metaLib];
    [skin registerPushNSHelper:pushHSuielementWatcher forClass:USERDATA_TAG];
    [skin registerLuaObjectHelper:toHSuielementWatcherFromLua forClass:USERDATA_TAG withUserdataMapping:USERDATA_TAG];
    return 1;
}
