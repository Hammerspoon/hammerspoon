#import "helpers.h"

CFDataRef ipc_callback(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info) {
    lua_State* L = info;
    
    CFStringRef instr = CFStringCreateFromExternalRepresentation(NULL, data, kCFStringEncodingUTF8);
    const char* cmd = CFStringGetCStringPtr(instr, kCFStringEncodingUTF8);
    
    BOOL israw = (cmd[0] == 'r');
    const char* commandstr = cmd+1;
    
    // result = ipc._handler(israw, cmdstring)
    lua_getglobal(L, "ipc");
    lua_getfield(L, -1, "_handler");
    lua_pushboolean(L, israw);
    lua_pushstring(L, commandstr);
    lua_pcall(L, 2, 1, 0);
    const char* coutstr = luaL_tolstring(L, -1, NULL);
    CFStringRef outstr = CFStringCreateWithCString(NULL, coutstr, kCFStringEncodingUTF8);
    lua_pop(L, 1); // ipc
    
    // this stays down here so commandstr can stay alive through the call
    CFRelease(instr);
    
    CFDataRef outdata = CFStringCreateExternalRepresentation(NULL, outstr, kCFStringEncodingUTF8, 0);
    CFRelease(outstr);
    
    return outdata;
}

// assumes the ipc table is pushed
// leaves lua stack intact
static void setup_ipc(lua_State* L) {
    CFMessagePortContext ctx = {0};
    ctx.info = L;
    CFMessagePortRef messagePort = CFMessagePortCreateLocal(NULL, CFSTR("hydra"), ipc_callback, &ctx, false);
    CFRunLoopSourceRef runloopSource = CFMessagePortCreateRunLoopSource(NULL, messagePort, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), runloopSource, kCFRunLoopCommonModes);
}

int luaopen_ipc(lua_State* L) {
    lua_newtable(L);
    setup_ipc(L);
    return 1;
}
