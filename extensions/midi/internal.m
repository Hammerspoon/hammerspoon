@import Cocoa ;
@import LuaSkin ;

#import "MIKMIDI/MIKMIDI.h"
#import <mach/mach.h>
#import <mach/mach_time.h>

static const char * const USERDATA_TAG = "hs.midi" ;
static int refTable = LUA_NOREF;

#pragma mark - Support Functions and Classes

#pragma mark - Module Functions

/// hs.midi.getDevices() -> table
/// Function
/// Returns a table of currently connected MIDI devices.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the names of any connected MIDI devices.
static int getDevices(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    NSArray *availableMIDIDevices = [[MIKMIDIDeviceManager sharedDeviceManager] availableDevices];
    NSMutableArray *deviceNames = [NSMutableArray array];
    for (MIKMIDIDevice * device in availableMIDIDevices)
    {
        [deviceNames addObject:[device name]];
    }
    [skin pushNSObject:deviceNames];
    return 1 ;
}

/// hs.midi.new(deviceName) -> object
/// Constructor
/// Creates a new mididevice object.
///
/// Parameters:
///  * deviceName - A string containing the device name of the MIDI device. A valid device name can be found by checking `hs.midi.getDevices()`.
///
/// Returns:
///  * An `hs.midi` object
static int midi_new(lua_State *L) {
    
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];
    
    const char *deviceName = luaL_checkstring(L, 1);
    
    NSNumber *foundMatch = @NO;
    
    NSArray *availableMIDIDevices = [[MIKMIDIDeviceManager sharedDeviceManager] availableDevices];
    
    MIKMIDIDevice *selectedDevice;
    
    for (MIKMIDIDevice * device in availableMIDIDevices)
    {
        NSString *newDevice = [NSString stringWithUTF8String:deviceName];
        NSString *currentDevice = [device name];
         if ([newDevice isEqualToString:currentDevice]) {
             foundMatch = @YES;
             selectedDevice = device;
         }
    }
    
    if ([foundMatch isEqual: @NO]) {
        [LuaSkin logError:@"hs.midi.new() - Device does not exist."];
        lua_pushnil(L) ;
    }
    else
    {
        void** ud = lua_newuserdata(L, sizeof(id*)) ;
        *ud = (__bridge_retained void*)selectedDevice ;
        
        luaL_getmetatable(L, USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    }
    return 1;
}

#pragma mark - Module Methods

/// hs.midi:name() -> string
/// Method
/// Returns the name of a `hs.midi` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The name as a string.
static int midi_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    MIKMIDIDevice *device = (__bridge MIKMIDIDevice*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    NSString *deviceName = [device name];
    [skin pushNSObject:deviceName];
    return 1;
}

/// hs.midi:displayName() -> string
/// Method
/// Returns the display name of a `hs.midi` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The name as a string.
static int midi_displayName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    MIKMIDIDevice *device = (__bridge MIKMIDIDevice*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    NSString *displayName = [device displayName];
    [skin pushNSObject:displayName];
    return 1;
}

/// hs.midi:model() -> string
/// Method
/// Returns the model name of a `hs.midi` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The model name as a string.
static int midi_model(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    MIKMIDIDevice *device = (__bridge MIKMIDIDevice*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    NSString *model = [device model];
    [skin pushNSObject:model];
    return 1;
}

/// hs.midi:manufacturer() -> string
/// Method
/// Returns the manufacturer name of a `hs.midi` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The manufacturer name as a string.
static int midi_manufacturer(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    MIKMIDIDevice *device = (__bridge MIKMIDIDevice*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    NSString *manufacturer = [device manufacturer];
    [skin pushNSObject:manufacturer];
    return 1;
}

/// hs.midi:entities() -> table
/// Method
/// Returns the entities of a `hs.midi` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The entities of a `hs.midi` object in a table.
static int midi_entities(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    MIKMIDIDevice *device = (__bridge MIKMIDIDevice*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    NSArray *entities = [device entities];
    [skin pushNSObject:entities];
    return 1;
}

/// hs.midi:isOnline() -> boolean
/// Method
/// Returns the online status of a `hs.midi` object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * `true` if online, otherwise `false
static int midi_isOnline(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    MIKMIDIDevice *device = (__bridge MIKMIDIDevice*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    lua_pushboolean(L, [device isOnline]);
    return 1;
}

/// hs.midi:callback(fn | nil)
/// Method
/// Sets or removes a callback function for the `hs.midi` object.
///
/// Parameters:
///  * fn - a function to set as the callback for this `hs.midi` object.  If the value provided is `nil`, any currently existing callback function is removed.
///
/// Returns:
///  * The `hs.midi` object
static int midi_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];        
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        // FIXME: Get the callback working properly...
        //callbackRef = [skin luaRef:refTable];
    }
    
    MIKMIDIDevice *device = (__bridge MIKMIDIDevice*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));

    NSArray *source = [device.entities valueForKeyPath:@"@unionOfArrays.sources"];
    MIKMIDISourceEndpoint *endpoint = [source objectAtIndex:0];

    MIKMIDIDeviceManager *manager = [MIKMIDIDeviceManager sharedDeviceManager];
    NSError *error = nil;
    [manager connectInput:endpoint error:&error eventHandler:^(MIKMIDISourceEndpoint *source, NSArray *commands) {
            for (MIKMIDICommand *command in commands) {
                // Handle each command:
                
                //[skin pushLuaRef:refTable ref:callbackRef];
                //[skin pushNSObject:command];
                
                // FIXME: Impliment the below properly:
                
                [LuaSkin logInfo:@"Callback Triggered"];
                NSLog(@"%@", command);
            }
        }];
    
    lua_pushvalue(L, 1);
    
    return 1;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions

#pragma mark - Hammerspoon/Lua Infrastructure

// static int userdata_tostring(lua_State* L) {
//     LuaSkin *skin = [LuaSkin shared] ;
//     <moduleType> *obj = [skin luaObjectAtIndex:1 toClass:"<moduleType>"] ;
//     NSString *title = ... ;
//     [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
//     return 1 ;
// }

// static int userdata_eq(lua_State* L) {
// // can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// // so use luaL_testudata before the macro causes a lua error
//     if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
//         LuaSkin *skin = [LuaSkin shared] ;
//         <moduleType> *obj1 = [skin luaObjectAtIndex:1 toClass:"<moduleType>"] ;
//         <moduleType> *obj2 = [skin luaObjectAtIndex:2 toClass:"<moduleType>"] ;
//         lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
//     } else {
//         lua_pushboolean(L, NO) ;
//     }
//     return 1 ;
// }

// static int userdata_gc(lua_State* L) {
//     <moduleType> *obj = get_objectFromUserdata(__bridge_transfer <moduleType>, L, 1, USERDATA_TAG) ;
//     if (obj) {
//         obj.selfRefCount-- ;
//         if (obj.selfRefCount == 0) {
//             obj = nil ;
//         }
//     }
//     // Remove the Metatable so future use of the variable in Lua won't think its valid
//     lua_pushnil(L) ;
//     lua_setmetatable(L, 1) ;
//     return 0 ;
// }

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// // Metatable for userdata objects
// static const luaL_Reg userdata_metaLib[] = {
//     {"__tostring", userdata_tostring},
//     {"__eq",       userdata_eq},
//     {"__gc",       userdata_gc},
//     {NULL,         NULL}
// };

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", midi_new},
    {"devices", getDevices},
    {NULL, NULL},
};

static const luaL_Reg userdata_metaLib[] = {
    {"name", midi_name},
    {"displayName", midi_displayName},
    {"isOnline", midi_isOnline},
    {"callback", midi_callback},
    {"manufacturer", midi_manufacturer},
    {"model", midi_model},
    {"entities", midi_entities},
     //{"__gc", meta_gc},
     {NULL,   NULL}
};

int luaopen_hs_midi_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
     refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                      functions:moduleLib
                                  metaFunctions:nil    // or module_metaLib
                                objectFunctions:userdata_metaLib];

//     [skin registerPushNSHelper:push<moduleType>         forClass:"<moduleType>"];

// // one, but not both, of...
//     [skin registerLuaObjectHelper:to<moduleType>FromLua forClass:"<moduleType>"
//                                              withUserdataMapping:USERDATA_TAG];
//     [skin registerLuaObjectHelper:to<moduleType>FromLua forClass:"<moduleType>"];

    return 1;
}
