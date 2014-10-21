#import <Cocoa/Cocoa.h>
#import <lauxlib.h>

CFDataRef ipc_callback(CFMessagePortRef __unused local, SInt32 __unused msgid, CFDataRef data, void *info) {
    lua_State* L = info;

//    NSLog(@"ipc-callback: local:%@ msgid:%d", local, msgid);
    CFStringRef instr = CFStringCreateFromExternalRepresentation(NULL, data, kCFStringEncodingUTF8);

    const char* cmd = CFStringGetCStringPtr(instr, kCFStringEncodingUTF8);
    bool shouldFree = NO;

    if (cmd == NULL) {
        CFIndex inputLength = CFStringGetLength(instr);
        CFIndex maxSize = CFStringGetMaximumSizeForEncoding(inputLength, kCFStringEncodingUTF8);

        cmd = malloc(maxSize + 1);
        // We will cast down from const here, since we jsut allocated cmd, and are sure it's safe at this
        // point to touch it's contents.
        CFStringGetCString(instr, (char*)cmd, maxSize, kCFStringEncodingUTF8);
        shouldFree = YES;
    }

    BOOL israw = (cmd[0] == 'r');
    const char* commandstr = cmd+1;

    // result = {PATH}.ipc._handler(israw, cmdstring)

    char *path_to_ipc_handler = strdup("{PATH}");
    char *token;

    lua_getglobal(L, strsep(&path_to_ipc_handler, "."));
    while ((token = strsep(&path_to_ipc_handler, ".")) != NULL)
        lua_getfield(L, -1, token);

    lua_getfield(L, -1, "ipc");
    lua_getfield(L, -1, "__handler");
    lua_pushboolean(L, israw);
    lua_pushstring(L, commandstr);
    lua_pcall(L, 2, 1, 0);
    const char* coutstr = luaL_tolstring(L, -1, NULL);
    CFStringRef outstr = CFStringCreateWithCString(NULL, coutstr, kCFStringEncodingUTF8);
    lua_pop(L, 4);

    // this stays down here so commandstr can stay alive through the call
    CFRelease(instr);
    if (shouldFree) free((char*) cmd);

    CFDataRef outdata = CFStringCreateExternalRepresentation(NULL, outstr, kCFStringEncodingUTF8, 0);
    CFRelease(outstr);

    return outdata;
}

static int setup_ipc(lua_State* L) {
    CFMessagePortRef    *userdata ;

    CFMessagePortContext ctx = {0, L, NULL, NULL, NULL};
//    ctx.info = L;
    CFMessagePortRef messagePort = CFMessagePortCreateLocal(NULL, CFSTR("{TARGET}"), ipc_callback, &ctx, false);
    CFRunLoopSourceRef runloopSource = CFMessagePortCreateRunLoopSource(NULL, messagePort, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), runloopSource, kCFRunLoopCommonModes);

    userdata = (CFMessagePortRef *) lua_newuserdata(L, sizeof(CFMessagePortRef)) ;
    *userdata = messagePort ;
    return 1 ;
}

static int invalidate_ipc(lua_State* L) {
    CFMessagePortRef    *messagePort = lua_touserdata(L,1);
    CFMessagePortInvalidate ( *messagePort );
    return 0;
}

static const luaL_Reg ipcLib[] = {
    {"__setup_ipc",       setup_ipc},
    {"__invalidate_ipc",  invalidate_ipc},
    {NULL,              NULL}
};

int luaopen_ipc(lua_State* L) {
    luaL_newlib(L, ipcLib);
    return 1;
}
