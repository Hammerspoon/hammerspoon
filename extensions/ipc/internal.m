#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

static CFMessagePortRef   messagePort ;
static CFRunLoopSourceRef runloopSource ;

CFDataRef ipc_callback(CFMessagePortRef __unused local, SInt32 __unused msgid, CFDataRef data, void __unused *info) {
    LuaSkin *skin = [LuaSkin shared];
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

    lua_getglobal(skin.L, "require") ;
    lua_pushstring(skin.L, "hs.ipc") ;
    if (![skin protectedCallAndTraceback:1 nresults:1]) {
        const char *errorMsg = lua_tostring(skin.L, -1);

        [skin logError:[NSString stringWithFormat:@"hs.ipc: Unable to require('hs.ipc'): %s", errorMsg]];

        if (shouldFree) {
            free((char *)cmd);
        }
        CFRelease(instr);
        return nil;
    }
    lua_getfield(skin.L, -1, "__handler") ;
    lua_remove(skin.L, -2) ;
    // now we know the function hs.ipc.__handler is on the stack...

    BOOL israw = (cmd[0] == 'r');
    const char* commandstr = cmd+1;

    lua_pushboolean(skin.L, israw);
    lua_pushstring(skin.L, commandstr);

    // we return 1 string whether its an error or not, so...
    [skin protectedCallAndTraceback:2 nresults:1] ;

    size_t length ;

    const char* coutstr = luaL_tolstring(skin.L, -1, &length);

//     CFStringRef outstr = CFStringCreateWithCharacters(NULL, coutstr, length );
// //     CFStringRef outstr = CFStringCreateWithCString(NULL, coutstr, kCFStringEncodingUTF8);
//
//     CFDataRef outdata = CFStringCreateExternalRepresentation(NULL, outstr, kCFStringEncodingUTF8, 0);

    CFDataRef outdata = CFDataCreate(NULL, (const UInt8 *)coutstr, (CFIndex)length );

//     lua_pop([[LuaSkin shared] L], 1);
    lua_pop(skin.L, 2); // luaL_tolstring pushes its result onto the stack without modifying the original
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
    LuaSkin *skin = [LuaSkin shared];
    [skin registerLibrary:moduleLib metaFunctions:module_metaLib];

    messagePort = setup_ipc() ;
    if (messagePort) {
        lua_pushboolean(skin.L, YES) ;
    } else {
        [skin logError:@"Unable to create IPC message port: Hammerspoon may already be running"];
        lua_pushboolean(skin.L, NO) ;
    }
    lua_setfield(skin.L, -2, "messagePortDefined") ;

    return 1;
}
