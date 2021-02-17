//
//  socket.h
//  Hammerspoon
//
//  Copyright (c) 2016 Michael Bujol
//

@import Cocoa;
#import <LuaSkin/LuaSkin.h>

#pragma clang diagnostic ignored "-Wgnu-conditional-omitted-operand"
#define mainThreadDispatch(...) dispatch_async(dispatch_get_main_queue(), ^{ @autoreleasepool {__VA_ARGS__;} })

// Helper for Lua callbacks
static LSRefTable refTable = LUA_NOREF;

// Userdata struct
typedef struct _asyncSocketUserData {
    int selfRef;
    void *asyncSocket;
} asyncSocketUserData;

// These constants are used to set CocoaAsyncSocket's built-in userData to distinguish socket types.
// Foreign client sockets (from netcat for example) connecting to our listening sockets are of type
// GCDAsyncSocket/GCDAsyncUdpSocket and attempting to place our subclass's new properties on them will fail
static const NSString *DEFAULT = @"DEFAULT";
static const NSString *SERVER = @"SERVER";
static const NSString *CLIENT = @"CLIENT";

// No-op GC for when module loads
static int meta_gc(lua_State* __unused L) {
    return 0;
}

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",            meta_gc},
    {NULL,              NULL} // This must end with an empty struct
};
