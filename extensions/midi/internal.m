@import Cocoa ;
@import LuaSkin ;

#import "MIKMIDI/MIKMIDI.h"

static const char * const USERDATA_TAG = "hs.midi";
static int refTable = LUA_NOREF;

static int deviceCallbackFn;

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

/// hs.midi.deviceCallback(callbackFn) -> none
/// Function
/// A callback that's triggered when a MIDI device is added or removed from the system.
///
/// Parameters:
///  * callbackFn - the callback function to trigger.
///
/// Returns:
///  * None
static int deviceCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared] ;
    
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK];
    
    deviceCallbackFn = [skin luaUnref:refTable ref:deviceCallbackFn];
    
    if (lua_type(skin.L, 1) == LUA_TFUNCTION) {
        deviceCallbackFn = [skin luaRef:refTable atIndex:1];
        
        //NSArray *availableMIDIDevices = [[MIKMIDIDeviceManager sharedDeviceManager] availableDevices];
        
        // TO-DO: Work out how KVO's work and finish off this callback function.
        
    }
    
    return 0;
}

/// hs.midi.new(deviceName) -> `hs.midi` object
/// Constructor
/// Creates a new `hs.midi` object.
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
///    * `object`       - The `hs.midi` object.
///    * `deviceName`   - The device name as a string.
///    * `commandType`  - Type of MIDI message as defined as a string. See `hs.midi.commandTypes[]` for a list of possibilities.
///    * `description`  - Description of the event as a string. This is only really useful for debugging.
///    * `metadata`     - A table of data for the MIDI command (see below).
///
///  * The `metadata` table will return the following, depending on the `commandType` for the callback:
///
///    * `noteOff` - Note off command:
///      * note                - The note number for the command. Must be between 0 and 127.
///      * velocity            - The velocity for the command. Must be between 0 and 127.
///      * channel             - The channel for the command. Must be between 0 and 15.
///      * timestamp           - The timestamp for the command as a string.
///
///    * `noteOn` - Note on command:
///      * note                - The note number for the command. Must be between 0 and 127.
///      * velocity            - The velocity for the command. Must be between 0 and 127.
///      * channel             - The channel for the command. Must be between 0 and 15.
///      * timestamp           - The timestamp for the command as a string.
///
///    * `polyphonicKeyPressure` - Polyphonic key pressure command:
///      * note                - The note number for the command. Must be between 0 and 127.
///      * pressure            - Key pressure of the polyphonic key pressure message. In the range 0-127.
///      * channel             - The channel for the command. Must be between 0 and 15.
///      * timestamp           - The timestamp for the command as a string.
///
///    * `controlChange` - Control change command. This is the most common command sent by MIDI controllers:
///      * controllerNumber    - The MIDI control number for the command.
///      * controlValue        - The controlValue of the command. Only the lower 7-bits of this are used.
///      * channel             - The channel for the command. Must be between 0 and 15.
///      * timestamp           - The timestamp for the command as a string.
///
///    * `programChange` - Program change command:
///      * programNumber       - The program (aka patch) number. From 0-127.
///      * channel             - The channel for the command. Must be between 0 and 15.
///      * timestamp           - The timestamp for the command as a string.
///
///    * `channelPressure` - Channel pressure command:
///      * pressure            - Key pressure of the channel pressure message. In the range 0-127.
///      * channel             - The channel for the command. Must be between 0 and 15.
///      * timestamp           - The timestamp for the command as a string.
///
///    * `pitchWheelChange` - Pitch wheel change command:
///      * pitchChange         -  A 14-bit value indicating the pitch bend. Center is 0x2000 (8192). Valid range is from 0-16383.
///      * channel             - The channel for the command. Must be between 0 and 15.
///      * timestamp           - The timestamp for the command as a string.
///
///    * `systemMessage` - System message command:
///      * dataByte1           - Data
///      * dataByte2           - Data
///      * timestamp           - The timestamp for the command as a string.
///
///    * `systemExclusive` - System message command:
///
///    * `systemTimecodeQuarterFrame` - System exclusive (SysEx) command:
///
///    * `systemSongPositionPointer` - System song position pointer command:
///
///    * `systemSongSelect` - System song select command:
///
///    * `systemTuneRequest` - System tune request command:
///
///    * `systemTimingClock` - System timing clock command:
///
///    * `systemStartSequence` - System timing clock command:
///
///    * `systemContinueSequence` - System start sequence command:
///
///    * `systemStopSequence` -  System continue sequence command:
///
///    * `systemKeepAlive` - System keep alive message:
///
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
                    // Device Name:
                    //
                    NSString *deviceName;
                    deviceName = [device name];
                    
                    //
                    // Description:
                    //
                    NSString *description;
                    description = [command description];
                    
                    //
                    // Command Type:
                    //
                    NSString *commandTypeString;
                    MIKMIDICommandType commandType = [command commandType];
                    switch (commandType)
                    {
                        case MIKMIDICommandTypeNoteOff:{
                            commandTypeString = @"NoteOff";
                            break;
                        }
                        case MIKMIDICommandTypeNoteOn:{
                            commandTypeString = @"NoteOn";
                            break;
                        }
                        case MIKMIDICommandTypePolyphonicKeyPressure:{
                            commandTypeString = @"PolyphonicKeyPressure";
                            break;
                        }
                        case MIKMIDICommandTypeControlChange:{
                            commandTypeString = @"ControlChange";
                            break;
                        }
                        case MIKMIDICommandTypeProgramChange:{
                            commandTypeString = @"ProgramChange";
                            break;
                        }
                        case MIKMIDICommandTypeChannelPressure:{
                            commandTypeString = @"ChannelPressure";
                            break;
                        }
                        case MIKMIDICommandTypePitchWheelChange:{
                            commandTypeString = @"PitchWheelChange";
                            break;
                        }
                        case MIKMIDICommandTypeSystemMessage:{
                            commandTypeString = @"SystemMessage";
                            break;
                        }
                        case MIKMIDICommandTypeSystemExclusive:{
                            commandTypeString = @"SystemExclusive";
                            break;
                        }
                        case MIKMIDICommandTypeSystemTimecodeQuarterFrame:{
                            commandTypeString = @"SystemTimecodeQuarterFrame";
                            break;
                        }
                        case MIKMIDICommandTypeSystemSongPositionPointer:{
                            commandTypeString = @"SystemSongPositionPointer";
                            break;
                        }
                        case MIKMIDICommandTypeSystemSongSelect:{
                            commandTypeString = @"SystemSongSelect";
                            break;
                        }
                        case MIKMIDICommandTypeSystemTuneRequest:{
                            commandTypeString = @"SystemTuneRequest";
                            break;
                        }
                        case MIKMIDICommandTypeSystemTimingClock:{
                            commandTypeString = @"SystemTimingClock";
                            break;
                        }
                        case MIKMIDICommandTypeSystemStartSequence:{
                            commandTypeString = @"SystemStartSequence";
                            break;
                        }
                        case MIKMIDICommandTypeSystemContinueSequence:{
                            commandTypeString = @"SystemContinueSequence";
                            break;
                        }
                        case MIKMIDICommandTypeSystemStopSequence:{
                            commandTypeString = @"SystemStopSequence";
                            break;
                        }
                        case MIKMIDICommandTypeSystemKeepAlive:{
                            commandTypeString = @"SystemKeepAlive";
                            break;
                        }
                    };
                   
                    //
                    // Push Values:
                    //
                    lua_pushvalue(L, 1);                        ///    * `object`       - The `hs.midi` object.
                    [skin pushNSObject:deviceName];             ///    * `deviceName`   - The device name as a string.
                    [skin pushNSObject:commandTypeString];      ///    * `commandType`  - Type of MIDI message as a string.
                    [skin pushNSObject:description];            ///    * `description`  - Description of the event as a string. This is useful for debugging.
                    
                    //
                    // Time Stamp:
                    //
                    NSString *timestamp;
                    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                    dateFormatter.dateFormat = @"HH:mm:ss.SSS";
                    timestamp = [dateFormatter stringFromDate:[command timestamp]];
                    
                    //
                    // Push Metadata:
                    //
                    switch (commandType)
                    {
                        case MIKMIDICommandTypeNoteOff: {
                            ///      * note                - The note number for the command. Must be between 0 and 127.
                            ///      * velocity            - The velocity for the command. Must be between 0 and 127.
                            ///      * channel             - The channel for the command. Must be between 0 and 15.
                            ///      * timestamp           - The timestamp for the command.
                            MIKMIDINoteOffCommand *noteCommand = (MIKMIDINoteOffCommand *)command;
                            lua_newtable(L) ;
                            lua_pushnumber(L, noteCommand.note);             lua_setfield(L, -2, "note");
                            lua_pushnumber(L, noteCommand.velocity);         lua_setfield(L, -2, "velocity");
                            lua_pushnumber(L, noteCommand.channel);          lua_setfield(L, -2, "channel");
                            lua_pushstring(L, [timestamp UTF8String]);       lua_setfield(L, -2, "timestamp");
                            break;
                        }
                        case MIKMIDICommandTypeNoteOn: {
                            ///      * note                - The note number for the command. Must be between 0 and 127.
                            ///      * velocity            - The velocity for the command. Must be between 0 and 127.
                            ///      * channel             - The channel for the command. Must be between 0 and 15.
                            ///      * timestamp           - The timestamp for the command.
                            MIKMIDINoteOnCommand *noteCommand = (MIKMIDINoteOnCommand *)command;
                            lua_newtable(L) ;
                            lua_pushnumber(L, noteCommand.note);             lua_setfield(L, -2, "note");
                            lua_pushnumber(L, noteCommand.velocity);         lua_setfield(L, -2, "velocity");
                            lua_pushnumber(L, noteCommand.channel);          lua_setfield(L, -2, "channel");
                            lua_pushstring(L, [timestamp UTF8String]);       lua_setfield(L, -2, "timestamp");
                            break;
                        }
                        case MIKMIDICommandTypePolyphonicKeyPressure: {
                            ///      * note                - The note number for the command. Must be between 0 and 127.
                            ///      * pressure            - Key pressure of the polyphonic key pressure message. In the range 0-127.
                            ///      * channel             - The channel for the command. Must be between 0 and 15.
                            ///      * timestamp           - The timestamp for the command.
                            MIKMIDIPolyphonicKeyPressureCommand *noteCommand = (MIKMIDIPolyphonicKeyPressureCommand *)command;
                            lua_newtable(L) ;
                            lua_pushnumber(L, noteCommand.note);             lua_setfield(L, -2, "note");
                            lua_pushnumber(L, noteCommand.pressure);         lua_setfield(L, -2, "pressure");
                            lua_pushnumber(L, noteCommand.channel);          lua_setfield(L, -2, "channel");
                            lua_pushstring(L, [timestamp UTF8String]);       lua_setfield(L, -2, "timestamp");
                            break;
                        }
                        case MIKMIDICommandTypeControlChange: {
                            ///      * controllerNumber    - The MIDI control number for the command.
                            ///      * controlValue        - The controlValue of the command. Only the lower 7-bits of this are used.
                            ///      * channel             - The channel for the command. Must be between 0 and 15.
                            ///      * timestamp           - The timestamp for the command.
                            MIKMIDIControlChangeCommand *result = (MIKMIDIControlChangeCommand *)command;
                            lua_newtable(L) ;
                            lua_pushnumber(L, result.controllerNumber);             lua_setfield(L, -2, "controllerNumber");
                            lua_pushnumber(L, result.value);                        lua_setfield(L, -2, "controlValue");
                            lua_pushnumber(L, result.channel);                      lua_setfield(L, -2, "channel");
                            lua_pushstring(L, [timestamp UTF8String]);              lua_setfield(L, -2, "timestamp");
                            break;
                        }
                        case MIKMIDICommandTypeProgramChange: {
                            ///      * programNumber       - The program (aka patch) number. From 0-127.
                            ///      * channel             - The channel for the command. Must be between 0 and 15.
                            ///      * timestamp           - The timestamp for the command as a string.
                            MIKMIDIProgramChangeCommand *result = (MIKMIDIProgramChangeCommand *)command;
                            lua_newtable(L) ;
                            lua_pushnumber(L, result.programNumber);                lua_setfield(L, -2, "programNumber");
                            lua_pushnumber(L, result.channel);                      lua_setfield(L, -2, "channel");
                            lua_pushstring(L, [timestamp UTF8String]);              lua_setfield(L, -2, "timestamp");
                            break;
                        }
                        case MIKMIDICommandTypeChannelPressure: {
                            ///      * pressure            - Key pressure of the channel pressure message. In the range 0-127.
                            ///      * channel             - The channel for the command. Must be between 0 and 15.
                            ///      * timestamp           - The timestamp for the command as a string.
                            MIKMIDIChannelPressureCommand *result = (MIKMIDIChannelPressureCommand *)command;
                            lua_newtable(L) ;
                            lua_pushnumber(L, result.pressure);                     lua_setfield(L, -2, "pressure");
                            lua_pushnumber(L, result.channel);                      lua_setfield(L, -2, "channel");
                            lua_pushstring(L, [timestamp UTF8String]);              lua_setfield(L, -2, "timestamp");
                            break;
                        }
                        case MIKMIDICommandTypePitchWheelChange: {
                            ///      * pitchChange         -  A 14-bit value indicating the pitch bend. Center is 0x2000 (8192). Valid range is from 0-16383.
                            ///      * channel             - The channel for the command. Must be between 0 and 15.
                            ///      * timestamp           - The timestamp for the command as a string.
                            MIKMIDIPitchBendChangeCommand *result = (MIKMIDIPitchBendChangeCommand *)command;
                            lua_newtable(L) ;
                            lua_pushnumber(L, result.pitchChange);                  lua_setfield(L, -2, "pitchChange");
                            lua_pushnumber(L, result.channel);                      lua_setfield(L, -2, "channel");
                            lua_pushstring(L, [timestamp UTF8String]);              lua_setfield(L, -2, "timestamp");
                            break;
                        }
                        case MIKMIDICommandTypeSystemMessage: {
                            ///      * dataByte1           - Data
                            ///      * dataByte2           - Data
                            ///      * timestamp           - The timestamp for the command as a string.
                            MIKMIDISystemMessageCommand *result = (MIKMIDISystemMessageCommand *)command;
                            lua_newtable(L) ;
                            lua_pushnumber(L, result.dataByte1);                  lua_setfield(L, -2, "dataByte1");
                            lua_pushnumber(L, result.dataByte2);                  lua_setfield(L, -2, "dataByte2");
                            lua_pushstring(L, [timestamp UTF8String]);              lua_setfield(L, -2, "timestamp");
                            break;
                        }
                        case MIKMIDICommandTypeSystemExclusive: {
                            break;
                        }
                        case MIKMIDICommandTypeSystemTimecodeQuarterFrame: {
                            break;
                        }
                        case MIKMIDICommandTypeSystemSongPositionPointer: {
                            break;
                        }
                        case MIKMIDICommandTypeSystemSongSelect: {
                            break;
                        }
                        case MIKMIDICommandTypeSystemTuneRequest: {
                            break;
                        }
                        case MIKMIDICommandTypeSystemTimingClock: {
                            break;
                        }
                        case MIKMIDICommandTypeSystemStartSequence: {
                            break;
                        }
                        case MIKMIDICommandTypeSystemContinueSequence: {
                            break;
                        }
                        case MIKMIDICommandTypeSystemStopSequence: {
                            break;
                        }
                        case MIKMIDICommandTypeSystemKeepAlive: {
                            break;
                        }
                    };
                
                    if (![skin protectedCallAndTraceback:5 nresults:0]) {
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

/// hs.midi.commandTypes[]
/// Constant
///
/// A table containing the numeric value for the possible flags returned by the `commandType` parameter of the callback function.
////
/// Defined keys are:
///   * noteOff                       - Note off command.
///   * noteOn                        - Note on command.
///   * polyphonicKeyPressure         - Polyphonic key pressure command.
///   * controlChange                 - Control change command. This is the most common command sent by MIDI controllers.
///   * programChange                 - Program change command.
///   * channelPressure               - Channel pressure command.
///   * pitchWheelChange              - Pitch wheel change command.
///   * systemMessage                 - System message command.
///   * systemExclusive               - System message command.
///   * SystemTimecodeQuarterFrame    - System exclusive (SysEx) command.
///   * systemSongPositionPointer     - System song position pointer command.
///   * systemSongSelect              - System song select command.
///   * systemTuneRequest             - System tune request command.
///   * systemTimingClock             - System timing clock command.
///   * systemStartSequence           - System timing clock command.
///   * systemContinueSequence        - System start sequence command.
///   * systemStopSequence            - System continue sequence command.
///   * systemKeepAlive               - System keep alive message.
static int pushCommandTypes(lua_State *L) {
    lua_newtable(L) ;
    lua_pushinteger(L, MIKMIDICommandTypeNoteOff) ;                     lua_setfield(L, -2, "noteOff") ;
    lua_pushinteger(L, MIKMIDICommandTypeNoteOn) ;                      lua_setfield(L, -2, "noteOn") ;
    lua_pushinteger(L, MIKMIDICommandTypePolyphonicKeyPressure) ;       lua_setfield(L, -2, "polyphonicKeyPressure") ;
    lua_pushinteger(L, MIKMIDICommandTypeControlChange) ;               lua_setfield(L, -2, "controlChange") ;
    lua_pushinteger(L, MIKMIDICommandTypeProgramChange) ;               lua_setfield(L, -2, "programChange") ;
    lua_pushinteger(L, MIKMIDICommandTypeChannelPressure) ;             lua_setfield(L, -2, "channelPressure") ;
    lua_pushinteger(L, MIKMIDICommandTypePitchWheelChange) ;            lua_setfield(L, -2, "pitchWheelChange") ;
    lua_pushinteger(L, MIKMIDICommandTypeSystemMessage) ;               lua_setfield(L, -2, "systemMessage") ;
    lua_pushinteger(L, MIKMIDICommandTypeSystemExclusive) ;             lua_setfield(L, -2, "systemExclusive") ;
    lua_pushinteger(L, MIKMIDICommandTypeSystemTimecodeQuarterFrame) ;  lua_setfield(L, -2, "systemTimecodeQuarterFrame") ;
    lua_pushinteger(L, MIKMIDICommandTypeSystemSongPositionPointer) ;   lua_setfield(L, -2, "systemSongPositionPointer") ;
    lua_pushinteger(L, MIKMIDICommandTypeSystemSongSelect) ;            lua_setfield(L, -2, "systemSongSelect") ;
    lua_pushinteger(L, MIKMIDICommandTypeSystemTuneRequest) ;           lua_setfield(L, -2, "systemTuneRequest") ;
    lua_pushinteger(L, MIKMIDICommandTypeSystemTimingClock) ;           lua_setfield(L, -2, "systemTimingClock") ;
    lua_pushinteger(L, MIKMIDICommandTypeSystemStartSequence) ;         lua_setfield(L, -2, "systemStartSequence") ;
    lua_pushinteger(L, MIKMIDICommandTypeSystemContinueSequence) ;      lua_setfield(L, -2, "systemContinueSequence") ;
    lua_pushinteger(L, MIKMIDICommandTypeSystemStopSequence) ;          lua_setfield(L, -2, "systemStopSequence") ;
    lua_pushinteger(L, MIKMIDICommandTypeSystemKeepAlive) ;             lua_setfield(L, -2, "systemKeepAlive") ;
    return 1 ;
}

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
    {"deviceCallback", deviceCallback},
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
    // Constants:
    pushCommandTypes(L) ; lua_setfield(L, -2, "commandTypes") ;
    return 1;
}
