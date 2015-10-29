#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

static CFMessagePortRef   messagePort ;
static CFRunLoopSourceRef runloopSource ;

CFDataRef ipc_callback(CFMessagePortRef __unused local, SInt32 __unused msgid, CFDataRef data, void __unused *info) {
    CFStringRef instr = CFStringCreateFromExternalRepresentation(NULL, data, kCFStringEncodingUTF8);
    const char* cmd = CFStringGetCStringPtr(instr, kCFStringEncodingUTF8);
    bool shouldFree = NO;

    if (cmd == NULL) {
        CFIndex inputLength = CFStringGetLength(instr);
        CFIndex maxSize = CFStringGetMaximumSizeForEncoding(inputLength, kCFStringEncodingUTF8);

        cmd = malloc((unsigned long)maxSize + 1);
        // We will cast down from const here, since we jsut allocated cmd, and are sure it's safe at this
        // point to touch it's contents.
        CFStringGetCString(instr, (char*)cmd, maxSize, kCFStringEncodingUTF8);
        shouldFree = YES;
    }

    lua_getglobal([[LuaSkin shared] L], "require") ;
    lua_pushstring([[LuaSkin shared] L], "hs.ipc") ;
    if (![[LuaSkin shared] protectedCallAndTraceback:1 nresults:1]) {
        const char *errorMsg = lua_tostring([[LuaSkin shared] L], -1);
        CLS_NSLOG(@"hs.ipc: unable to load module to invoke callback handler: %s", errorMsg) ;
        showError([[LuaSkin shared] L], (char *)errorMsg);
        if (shouldFree) {
            free((char *)cmd);
        }
        CFRelease(instr);
        return nil;
    }
    lua_getfield([[LuaSkin shared] L], -1, "__handler") ;
    lua_remove([[LuaSkin shared] L], -2) ;
    // now we know the function hs.ipc.__handler is on the stack...

    BOOL israw = (cmd[0] == 'r');
    const char* commandstr = cmd+1;

    lua_pushboolean([[LuaSkin shared] L], israw);
    lua_pushstring([[LuaSkin shared] L], commandstr);

    // we return 1 string whether its an error or not, so...
    [[LuaSkin shared] protectedCallAndTraceback:2 nresults:1] ;

    size_t length ;

    const char* coutstr = luaL_tolstring([[LuaSkin shared] L], -1, &length);

//     CFStringRef outstr = CFStringCreateWithCharacters(NULL, coutstr, length );
// //     CFStringRef outstr = CFStringCreateWithCString(NULL, coutstr, kCFStringEncodingUTF8);
//
//     CFDataRef outdata = CFStringCreateExternalRepresentation(NULL, outstr, kCFStringEncodingUTF8, 0);

    CFDataRef outdata = CFDataCreate(NULL, (const UInt8 *)coutstr, (CFIndex)length );

    lua_pop([[LuaSkin shared] L], 1);
    CFRelease(instr);
    if (shouldFree) free((char*) cmd);
//     CFRelease(outstr);

    return outdata;
}

CFMessagePortRef setup_ipc() {
    CFMessagePortContext ctx = {0, NULL, NULL, NULL, NULL};
    CFMessagePortRef messagePort = CFMessagePortCreateLocal(NULL, CFSTR("Hammerspoon"), ipc_callback, &ctx, false);
    if (messagePort) {
        runloopSource = CFMessagePortCreateRunLoopSource(NULL, messagePort, 0);
        CFRunLoopAddSource(CFRunLoopGetMain(), runloopSource, kCFRunLoopCommonModes);
    }

    return messagePort ;
}

static int invalidate_ipc(__unused lua_State* L) {
    if (messagePort) {
        CFMessagePortInvalidate(messagePort);
        CFRelease(messagePort);
        CFRelease(runloopSource);
        runloopSource = nil;
        messagePort = nil;
    }
    return 0;
}

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {NULL,  NULL}
};

// Metatable for module, if needed
static const luaL_Reg module_metaLib[] = {
    {"__gc", invalidate_ipc},
    {NULL,   NULL}
};

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs_ipc_internal(lua_State* __unused L) {
    [[LuaSkin shared] registerLibrary:moduleLib metaFunctions:module_metaLib];

    messagePort = setup_ipc() ;
    if (messagePort) {
        lua_pushboolean([[LuaSkin shared] L], YES) ;
    } else {
        printToConsole([[LuaSkin shared] L], "-- Unable to create IPC message port: Is Hammerspoon already running?") ;
        lua_pushboolean([[LuaSkin shared] L], NO) ;
    }
    lua_setfield([[LuaSkin shared] L], -2, "messagePortDefined") ;

    return 1;
}
