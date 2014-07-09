#import "helpers.h"

static const char* (^ipc_closure)(const char* str);

CFDataRef ipc_callback(CFMessagePortRef local, SInt32 msgid, CFDataRef data, void *info) {
    CFStringRef instr = CFStringCreateFromExternalRepresentation(NULL, data, kCFStringEncodingUTF8);
    const char* cinstr = CFStringGetCStringPtr(instr, kCFStringEncodingUTF8);
    const char* coutstr = ipc_closure(cinstr);
    CFRelease(instr);
    
    CFStringRef outstr = CFStringCreateWithCString(NULL, coutstr, kCFStringEncodingUTF8);
    CFDataRef outdata = CFStringCreateExternalRepresentation(NULL, outstr, kCFStringEncodingUTF8, 0);
    CFRelease(outstr);
    
    return outdata;
}

// assumes the ipc table is pushed
// leaves lua stack intact
static void setup_ipc(lua_State* L) {
    lua_pushvalue(L, -1);
    int ipcmod = luaL_ref(L, LUA_REGISTRYINDEX);
    ipc_closure = [^const char*(const char* cmd) {
        lua_rawgeti(L, LUA_REGISTRYINDEX, ipcmod);
        lua_getfield(L, -1, "_handler");
        lua_pushboolean(L, cmd[0] == 'r');
        lua_pushstring(L, cmd+1);
        const char* result = "";
        if (lua_pcall(L, 2, 1, 0)) {
            hydra_handle_error(L);
            lua_pop(L, 1); // ipcmod
        }
        else {
            result = luaL_tolstring(L, -1, NULL);
            lua_pop(L, 2); // return value and ipcmod
        }
        return result;
    } copy];
    
    CFMessagePortRef messagePort = CFMessagePortCreateLocal(NULL, CFSTR("hydra"), ipc_callback, NULL, false);
    CFRunLoopSourceRef runloopSource = CFMessagePortCreateRunLoopSource(NULL, messagePort, 0);
    CFRunLoopAddSource(CFRunLoopGetMain(), runloopSource, kCFRunLoopCommonModes);
}

int luaopen_ipc(lua_State* L) {
    lua_newtable(L);
    setup_ipc(L);
    return 1;
}
