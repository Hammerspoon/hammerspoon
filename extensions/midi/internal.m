@import Cocoa ;
@import LuaSkin ;

#import "MIKMIDI/MIKMIDI.h"

static const char * const USERDATA_TAG = "hs.midi" ;
static int refTable = LUA_NOREF;

#pragma mark - Support Functions and Classes

@interface HSMIKMIDIDevice : NSObject
@property int callbackRef;
@property MIKMIDIDevice *device;
@end

@implementation HSMIKMIDIDevice
@end

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
        HSMIKMIDIDevice* midiDevice = [[HSMIKMIDIDevice alloc] init];
        
        midiDevice.device = selectedDevice;
        
        void** ud = lua_newuserdata(L, sizeof(id*)) ;
        *ud = (__bridge_retained void*)midiDevice ;
        
        luaL_getmetatable(L, USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
    }
    return 1;
}

#pragma mark - Module Methods

/// hs.midi:callback(callbackFn | nil)
/// Method
/// Sets or removes a callback function for the `hs.midi` object.
///
/// Parameters:
///  * `callbackFn` - a function to set as the callback for this `hs.midi` object.  If the value provided is `nil`, any currently existing callback function is removed.
///
/// Returns:
///  * The `hs.midi` object
///
/// Notes:
///  * The callback function should expect 8 arguments and should not return anything:
///    * `object` - The `hs.midi` object.
///    * `deviceName` - The device name as a string.
///    * `description` - Description of the event as a string. This is useful for debugging.
///    * `timestamp` - The MIDITimestamp for the command.
///    * `commandType` - Type of MIDI message. These values correspond directly to the MIDI command type values found in MIDI message data.
///    * `channel` - The channel for the command, between 0 and 15.
///    * `note/controllerNumber` - The note number for the command, between 0 and 127.
///    * `value/velocity/controllerValue` - The velocity for the command, between 0 and 127.
///  * Example:
///      ```test = hs.midi.new("USB O2")
///      test:callback(function(object, deviceName, description, timestamp, commandType, channel, note, value)
///                    print("object: " .. tostring(object))
///                    print("deviceName: " .. tostring(deviceName))
///                    print("description: " .. tostring(description))
///                    print("timestamp: " .. tostring(timestamp))
///                    print("commandType: " .. tostring(commandType))
///                    print("channel: " .. tostring(channel))
///                    print("note/controllerNumber: " .. tostring(note))
///                    print("value/velocity/controllerValue: " .. tostring(value))
///                    end)```
static int midi_callback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];
    
    HSMIKMIDIDevice* midiDevice = (__bridge HSMIKMIDIDevice*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    
    //
    // In either case, we need to remove an existing callback, so...
    //
    midiDevice.callbackRef = [skin luaUnref:refTable ref:midiDevice.callbackRef];
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        midiDevice.callbackRef = [skin luaRef:refTable];
        
        //
        // Setup MIDI Device:
        //
        MIKMIDIDevice *device = midiDevice.device;
        NSArray *source = [device.entities valueForKeyPath:@"@unionOfArrays.sources"];
        MIKMIDISourceEndpoint *endpoint = [source objectAtIndex:0];
        
        //
        // Setup MIDI Device Manager:
        //
        MIKMIDIDeviceManager *manager = [MIKMIDIDeviceManager sharedDeviceManager];
        NSError *error = nil;
        
        //
        // Setup Event:
        //
        [manager connectInput:endpoint error:&error eventHandler:^(MIKMIDISourceEndpoint *source, NSArray<MIKMIDICommand *> *commands) {
            for (MIKMIDICommand *command in commands) {
                LuaSkin *skin = [LuaSkin shared] ;
                if (midiDevice.callbackRef != LUA_NOREF) {
                    lua_State *_L = [skin L];
                    [skin pushLuaRef:refTable ref:midiDevice.callbackRef];
                    
                    //
                    // Default Values:
                    //
                    NSString *unknown = @"Unknown";
                    NSString *deviceName = unknown;
                    NSString *description = unknown;
                    NSString *timestamp = unknown;
                    NSString *commandTypeString = unknown;
                    NSString *channel = unknown;
                    NSString *note = unknown;
                    NSString *velocity = unknown;
                    
                    //
                    // Device Name:
                    //
                    deviceName = [device name];
                    
                    //
                    // Description:
                    //
                    description = [command description];
                    
                    //
                    // Time Stamp:
                    //
                    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                    dateFormatter.dateFormat = @"HH:mm:ss.SSS";
                    timestamp =[dateFormatter stringFromDate:[command timestamp]];
                    
                    //
                    // Command Type:
                    //
                    MIKMIDICommandType commandType = [command commandType];
                    switch (commandType)
                    {
                        case MIKMIDICommandTypeNoteOff:
                            commandTypeString = @"NoteOff";
                            break;
                        case MIKMIDICommandTypeNoteOn:
                            commandTypeString = @"NoteOn";
                            break;
                        case MIKMIDICommandTypePolyphonicKeyPressure:
                            commandTypeString = @"PolyphonicKeyPressure";
                            break;
                        case MIKMIDICommandTypeControlChange:
                            commandTypeString = @"ControlChange";
                            break;
                        case MIKMIDICommandTypeProgramChange:
                            commandTypeString = @"ProgramChange";
                            break;
                        case MIKMIDICommandTypeChannelPressure:
                            commandTypeString = @"ChannelPressure";
                            break;
                        case MIKMIDICommandTypePitchWheelChange:
                            commandTypeString = @"PitchWheelChange";
                            break;
                        case MIKMIDICommandTypeSystemMessage:
                            commandTypeString = @"SystemMessage";
                            break;
                        case MIKMIDICommandTypeSystemExclusive:
                            commandTypeString = @"SystemExclusive";
                            break;
                        case MIKMIDICommandTypeSystemTimecodeQuarterFrame:
                            commandTypeString = @"SystemTimecodeQuarterFrame";
                            break;
                        case MIKMIDICommandTypeSystemSongPositionPointer:
                            commandTypeString = @"SystemSongPositionPointer";
                            break;
                        case MIKMIDICommandTypeSystemSongSelect:
                            commandTypeString = @"SystemSongSelect";
                            break;
                        case MIKMIDICommandTypeSystemTuneRequest:
                            commandTypeString = @"SystemTuneRequest";
                            break;
                        case MIKMIDICommandTypeSystemTimingClock:
                            commandTypeString = @"SystemTimingClock";
                            break;
                        case MIKMIDICommandTypeSystemStartSequence:
                            commandTypeString = @"SystemStartSequence";
                            break;
                        case MIKMIDICommandTypeSystemContinueSequence:
                            commandTypeString = @"SystemContinueSequence";
                            break;
                        case MIKMIDICommandTypeSystemStopSequence:
                            commandTypeString = @"SystemStopSequence";
                            break;
                        case MIKMIDICommandTypeSystemKeepAlive:
                            commandTypeString = @"SystemKeepAlive";
                            break;
                    };
                    
                    //
                    // Note On:
                    //
                    if (command.commandType == MIKMIDICommandTypeNoteOn) {
                        MIKMIDINoteOnCommand *noteCommand = (MIKMIDINoteOnCommand *)command;
                        channel = [NSString stringWithFormat:@"%lu", (unsigned long)noteCommand.channel];
                        note = [NSString stringWithFormat:@"%lu", (unsigned long)noteCommand.note];
                        velocity = [NSString stringWithFormat:@"%lu", (unsigned long)noteCommand.velocity];
                    }
                    
                    //
                    // Note Off:
                    //
                    if (command.commandType == MIKMIDICommandTypeNoteOff) {
                        MIKMIDINoteOffCommand *noteCommand = (MIKMIDINoteOffCommand *)command;
                        channel = [NSString stringWithFormat:@"%lu", (unsigned long)noteCommand.channel];
                        note = [NSString stringWithFormat:@"%lu", (unsigned long)noteCommand.note];
                        velocity = [NSString stringWithFormat:@"%lu", (unsigned long)noteCommand.velocity];
                    }
                    
                    //
                    // Control Change:
                    //
                    if (command.commandType == MIKMIDICommandTypeControlChange) {
                        MIKMIDIControlChangeCommand *controlChange = (MIKMIDIControlChangeCommand *)command;
                        channel = [NSString stringWithFormat:@"%lu", (unsigned long)controlChange.channel];
                        note = [NSString stringWithFormat:@"%lu", (unsigned long)controlChange.controllerNumber];
                        velocity = [NSString stringWithFormat:@"%lu", (unsigned long)controlChange.controllerValue];
                    }

                    //
                    // Pitch Bend Change Command:
                    //
                    if (command.commandType == MIKMIDICommandTypePitchWheelChange) {
                        MIKMIDIPitchBendChangeCommand *controlChange = (MIKMIDIPitchBendChangeCommand *)command;
                        channel = [NSString stringWithFormat:@"%lu", (unsigned long)controlChange.channel];
                        note = [NSString stringWithFormat:@"%lu", (unsigned long)controlChange.pitchChange];
                        velocity = [NSString stringWithFormat:@"%lu", (unsigned long)controlChange.value];
                    }
                    
                    //
                    // Push Values:
                    //
                    lua_pushvalue(L, 1);
                    [skin pushNSObject:deviceName];
                    [skin pushNSObject:description];
                    [skin pushNSObject:timestamp];
                    [skin pushNSObject:commandTypeString];
                    [skin pushNSObject:channel];
                    [skin pushNSObject:note];
                    [skin pushNSObject:velocity];
                    
                    if (![skin protectedCallAndTraceback:8 nresults:0]) {
                        const char *errorMsg = lua_tostring(_L, -1);
                        [skin logError:[NSString stringWithFormat:@"%s: %s", USERDATA_TAG, errorMsg]];
                        lua_pop(_L, 1) ; // Remove error message from stack
                    }
                }
            }
        }];
    }
   
    lua_pushvalue(L, 1);
    return 1;
}

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
    HSMIKMIDIDevice* midiDevice = (__bridge HSMIKMIDIDevice*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    MIKMIDIDevice *device = midiDevice.device;
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
    HSMIKMIDIDevice* midiDevice = (__bridge HSMIKMIDIDevice*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    MIKMIDIDevice *device = midiDevice.device;
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
    HSMIKMIDIDevice* midiDevice = (__bridge HSMIKMIDIDevice*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    MIKMIDIDevice *device = midiDevice.device;
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
    HSMIKMIDIDevice* midiDevice = (__bridge HSMIKMIDIDevice*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    MIKMIDIDevice *device = midiDevice.device;
    NSString *manufacturer = [device manufacturer];
    [skin pushNSObject:manufacturer];
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
    HSMIKMIDIDevice* midiDevice = (__bridge HSMIKMIDIDevice*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    MIKMIDIDevice *device = midiDevice.device;
    lua_pushboolean(L, [device isOnline]);
    return 1;
}

#pragma mark - Module Constants

#pragma mark - Lua<->NSObject Conversion Functions

static int userdata_tostring(lua_State* L) {
    lua_pushstring(L, [[NSString stringWithFormat:@"%s: (%p)", USERDATA_TAG, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_gc(lua_State* L) {
    HSMIKMIDIDevice* midiDevice = (__bridge_transfer HSMIKMIDIDevice*)(*(void**)luaL_checkudata(L, 1, USERDATA_TAG));
    midiDevice.callbackRef = [[LuaSkin shared] luaUnref:refTable ref:midiDevice.callbackRef];
    midiDevice.device = nil;
    midiDevice = nil ;
    return 0 ;
}

// Functions for returned object when module loads:
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
    {"__tostring", userdata_tostring},
    {"__gc",       userdata_gc},
    {NULL,   NULL}
};

int luaopen_hs_midi_internal(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared] ;
     refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                      functions:moduleLib
                                  metaFunctions:nil
                                objectFunctions:userdata_metaLib];
    return 1;
}
