#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <LuaSkin/LuaSkin.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>

#define USERDATA_TAG "hs.milight"

typedef struct _bridge_t {
    const char *ip;
    int port;
    int socket;
    struct sockaddr_in sockaddr;
} bridge_t;

// Option value for SO_BROADCAST
int broadcastOption = 1;

#define cmd_suffix 0x55

static void pushCommand(lua_State *L, const char *cmd, int value) {
    // t[cmd] = value
    lua_pushinteger(L, value);
    lua_setfield(L, -2, cmd);
}

int milight_cacheCommands(lua_State *L) {
    lua_newtable(L);

    pushCommand(L, "rgbw", 0x40);
    pushCommand(L, "all_off", 0x41);
    pushCommand(L, "all_on", 0x42);
    pushCommand(L, "disco_slower", 0x43);
    pushCommand(L, "disco_faster", 0x44);
    pushCommand(L, "zone1_on", 0x45);
    pushCommand(L, "zone1_off", 0x46);
    pushCommand(L, "zone2_on", 0x47);
    pushCommand(L, "zone2_off", 0x48);
    pushCommand(L, "zone3_on", 0x49);
    pushCommand(L, "zone3_off", 0x4A);
    pushCommand(L, "zone4_on", 0x4B);
    pushCommand(L, "zone4_off", 0x4C);
    pushCommand(L, "disco", 0x4D);
    pushCommand(L, "brightness", 0x4E);
    pushCommand(L, "all_white", 0xC2);
    pushCommand(L, "zone1_white", 0xC5);
    pushCommand(L, "zone2_white", 0xC7);
    pushCommand(L, "zone3_white", 0xC9);
    pushCommand(L, "zone4_white", 0xCB);

    // Convenience colors
    pushCommand(L, "violet", 0x00);
    pushCommand(L, "royalblue", 0x10);
    pushCommand(L, "babyblue", 0x20);
    pushCommand(L, "aqua", 0x30);
    pushCommand(L, "mint", 0x40);
    pushCommand(L, "seafoam", 0x50);
    pushCommand(L, "green", 0x60);
    pushCommand(L, "lime", 0x70);
    pushCommand(L, "yellow", 0x80);
    pushCommand(L, "yelloworange", 0x90);
    pushCommand(L, "orange", 0xA0);
    pushCommand(L, "red", 0xB0);
    pushCommand(L, "pink", 0xC0);
    pushCommand(L, "fuscia", 0xD0);
    pushCommand(L, "lilac", 0xE0);
    pushCommand(L, "lavendar", 0xF0);

    return 1;
}

/// hs.milight.new(ip[, port]) -> bridge
/// Constructor
/// Creates a new bridge object, which will be connected to the supplied IP address and port
///
/// Parameters:
///  * ip - A string containing the IP address of the MiLight WiFi bridge device. For convenience this can be the broadcast address of your network (e.g. 192.168.0.255)
///  * port - An optional number containing the UDP port to talk to the bridge on. Defaults to 8899
///
/// Returns:
///  * An `hs.milight` object
///
/// Notes:
///  * You can not use 255.255.255.255 as the IP address, to do so requires elevated privileges for the Hammerspoon process
static int milight_new(lua_State *L) {
    const char *ip = luaL_checkstring(L, 1);
    int port;

    if (lua_isnone(L, 2)) {
        port = 8899;
    } else {
        port = (int)luaL_checkinteger(L, 2);
    }

    bridge_t *bridge = lua_newuserdata(L, sizeof(bridge_t));
    memset(bridge, 0, sizeof(bridge_t));

    bridge->ip = ip;
    bridge->port = port;

    bridge->socket = socket(AF_INET, SOCK_DGRAM, 0);
    if (strlen(bridge->ip) > 3) {
        const char *last_three = &bridge->ip[strlen(bridge->ip)-3];
        if (!strncmp(last_three, "255", 3)) {
            setsockopt(bridge->socket, SOL_SOCKET, SO_BROADCAST, &broadcastOption, sizeof(broadcastOption));
        }
    }

    bzero(&bridge->sockaddr, sizeof(bridge->sockaddr));
    bridge->sockaddr.sin_family = AF_INET;
    bridge->sockaddr.sin_addr.s_addr = inet_addr(bridge->ip);
    bridge->sockaddr.sin_port = htons(bridge->port);

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);

    return 1;
}

/// hs.milight:delete()
/// Method
/// Deletes an `hs.milight` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int milight_del(lua_State *L) {
    bridge_t *bridge = luaL_checkudata(L, 1, USERDATA_TAG);

    close(bridge->socket);

    bridge = nil;

    return 0;
}

/// hs.milight:send(cmd[, value]) -> bool
/// Method
/// Sends a command to the bridge
///
/// Parameters:
///  * cmd - A command from the `hs.milight.cmd` table
///  * value - An optional value, if appropriate for the command (defaults to 0x00)
///
/// Returns:
///  * True if the command was sent, otherwise false
///
/// Notes:
///  * This is a low level command, you typically should use a specific method for the operation you want to perform
static int milight_send(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    bridge_t *bridge = luaL_checkudata(L, 1, USERDATA_TAG);

    int cmd_key = (int)luaL_checkinteger(L, 2);
    int value;
    if (lua_isnone(L, 3)) {
        value = 0x0;
    } else {
        value = (int)luaL_checkinteger(L, 3);
    }

    unsigned char cmd[3] = {cmd_key, value, cmd_suffix};

//    NSLog(@"milight: sending '%x %x %x'(%i %i %i) to %s:%i", cmd[0], cmd[1], cmd[2], cmd[0], cmd[1], cmd[2], bridge->ip, bridge->port);

    ssize_t result = sendto(bridge->socket, cmd, 3, 0, (struct sockaddr *)&bridge->sockaddr, sizeof(bridge->sockaddr));

    if (result == 3) {
//        NSLog(@"milight: sent.");
        lua_pushboolean(L, true);
        usleep(100000); // The bridge requires we sleep for 100ms after each command
    } else if (result == -1) {
        [skin logBreadcrumb:[NSString stringWithFormat:@"milight: Error sending command: %s", strerror(errno)]];
        lua_pushboolean(L, false);
    } else {
        [skin logBreadcrumb:[NSString stringWithFormat:@"milight: Error, incorrect amount of data written (%lu bytes)", result]];
        lua_pushboolean(L, false);
    }

    return 1;
}

// Lua/HS glue
static int milight_metagc(lua_State *L) {
    milight_del(L);

    return 0;
}

static int userdata_tostring(lua_State* L) {
    bridge_t *bridge = luaL_checkudata(L, 1, USERDATA_TAG);

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %s:%d (%p)", USERDATA_TAG, bridge->ip, bridge->port, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static const luaL_Reg milightlib[] = {
    {"_cacheCommands", milight_cacheCommands},
    {"new", milight_new},

    {NULL, NULL},
};

static const luaL_Reg milight_objectlib[] = {
    {"delete", milight_del},
    {"send", milight_send},
    {"__tostring", userdata_tostring},
    {"__gc", milight_metagc},

    {NULL, NULL}
};

/* NOTE: The substring "hs_milight_internal" in the following function's name
         must match the require-path of this file, i.e. "hs.milight.internal". */

int luaopen_hs_milight_internal(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibraryWithObject:USERDATA_TAG functions:milightlib metaFunctions:nil objectFunctions:milight_objectlib];

    return 1;
}
