@import Cocoa ;
@import LuaSkin ;

#import "MIKMIDI/MIKMIDI.h"

//
// Establish a unique context for identifying our observers:
//
static const char * const USERDATA_TAG = "hs.midi";
static void *midiKVOContext = &midiKVOContext ;                 // See: http://nshipster.com/key-value-observing/
static int refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

//
// Device Callback Function:
//
static int deviceCallbackFn;

//
// MIDI Device:
//
@interface HSMidiDevice : NSObject
@property MIKMIDIDeviceManager      *midiDeviceManager ;
@property MIKMIDIDevice             *midiDevice ;
@property int                       callbackRef ;
@property int                       selfRefCount ;
@end

@implementation HSMidiDevice

- (instancetype)initWithDeviceName:(NSString *)deviceName {
    self = [super init] ;
    if (self) {
        _midiDeviceManager = [MIKMIDIDeviceManager sharedDeviceManager];
        NSArray *availableMIDIDevices = [_midiDeviceManager availableDevices];
        for (MIKMIDIDevice * device in availableMIDIDevices)
        {
            NSString *currentDevice = [device name];
            if ([deviceName isEqualToString:currentDevice]) {                
                _midiDevice = device;
            }
        }
        if (_midiDevice) {
            _callbackRef             = LUA_NOREF ;
            _selfRefCount            = 0 ;
        }
    }
    return self ;
}

@end

//
// MIDI Device Watcher:
//
@interface HSMidiDeviceWatcher : NSObject
@property MIKMIDIDeviceManager      *midiDeviceManager ;
@end

@implementation HSMidiDeviceWatcher

- (void)dealloc
{
    NSLog(@"HSMidiDeviceWatcher dealloc triggered");
    self.midiDeviceManager = nil; // Break KVO
}

- (instancetype)initWithCallbackFn:(int *)callbackFn {
    self = [super init] ;
    if (self) {
        //
        // Setup Device Manager:
        //
        _midiDeviceManager = [MIKMIDIDeviceManager sharedDeviceManager];
        
        //
        // Add Observer:
        //
        NSLog(@"Adding Observer");
        [_midiDeviceManager addObserver:self forKeyPath:@"availableDevices" options:NSKeyValueObservingOptionInitial context:midiKVOContext];
    }
    return self ;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == midiKVOContext) {
        
        NSLog(@"DEVICE STUFF HAPPENING:");
        NSLog(@"keyPath: %@", keyPath);
        NSLog(@"object: %@", object);
        NSLog(@"change: %@", change);
        NSLog(@"------------");
        
        //if ([keyPath isEqualToString:@"availableDevices"]) {
        //}
    }
    else {
        NSLog(@"Outside of context?");
    }
}

@end

#pragma mark - Module Functions

/// hs.midi.devices() -> table
/// Function
/// Returns a table of currently connected MIDI devices.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the names of any connected MIDI devices as strings.
static int devices(lua_State *L) {
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

    //
    // Check Arguments:
    //
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TFUNCTION, LS_TBREAK];
    
    //
    // Setup or Remove Callback Function:
    //
    deviceCallbackFn = [skin luaUnref:refTable ref:deviceCallbackFn];
    if (lua_type(skin.L, 1) == LUA_TFUNCTION) {
        deviceCallbackFn = [skin luaRef:refTable atIndex:1];
        HSMidiDeviceWatcher *watcher = [[HSMidiDeviceWatcher alloc] initWithCallbackFn:&deviceCallbackFn];
        NSLog(@"Watcher: %@", watcher);
    }
    
    lua_pushnil(L) ;
    return 1;
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
    LuaSkin *skin = [LuaSkin shared] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    HSMidiDevice *wrapper = [[HSMidiDevice alloc] initWithDeviceName:[skin toNSObjectAtIndex:1]] ;
    if (wrapper && wrapper.midiDevice) {
        [skin pushNSObject:wrapper] ;
    } else {
        wrapper = nil ;
        lua_pushnil(L) ;
    }
    return 1 ;
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
///  * Example Usage:
///    ```midiDevice = hs.midi.new(hs.midi.devices()[3])
///    midiDevice:callback(function(object, deviceName, commandType, description, metadata)
///               print("object: " .. tostring(object))
///               print("deviceName: " .. deviceName)
///               print("commandType: " .. commandType)
///               print("description: " .. description)
///               print("metadata: " .. hs.inspect(metadata))
///               end)```
///
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
///      * manufacturerID      - The manufacturer ID for the command. This is used by devices to determine if the message is one they support.
///      * sysexChannel        - The channel of the message. Only valid for universal exclusive messages, will always be 0 for non-universal messages.
///      * sysexData           - The system exclusive data for the message. For universal messages subID's are included in sysexData, for non-universal messages, any device specific information (such as modelID, versionID or whatever manufactures decide to include) will be included in sysexData.
///      * timestamp           - The timestamp for the command as a string.
///
///    * `systemTimecodeQuarterFrame` - System exclusive (SysEx) command:
///      * dataByte1           - Data
///      * dataByte2           - Data
///      * timestamp           - The timestamp for the command as a string.
///
///    * `systemSongPositionPointer` - System song position pointer command:
///      * dataByte1           - Data
///      * dataByte2           - Data
///      * timestamp           - The timestamp for the command as a string.
///
///    * `systemSongSelect` - System song select command:
///      * dataByte1           - Data
///      * dataByte2           - Data
///      * timestamp           - The timestamp for the command as a string.
///
///    * `systemTuneRequest` - System tune request command:
///      * dataByte1           - Data
///      * dataByte2           - Data
///      * timestamp           - The timestamp for the command as a string.
///
///    * `systemTimingClock` - System timing clock command:
///      * dataByte1           - Data
///      * dataByte2           - Data
///      * timestamp           - The timestamp for the command as a string.
///
///    * `systemStartSequence` - System timing clock command:
///      * dataByte1           - Data
///      * dataByte2           - Data
///      * timestamp           - The timestamp for the command as a string.
///
///    * `systemContinueSequence` - System start sequence command:
///      * dataByte1           - Data
///      * dataByte2           - Data
///      * timestamp           - The timestamp for the command as a string.
///
///    * `systemStopSequence` -  System continue sequence command:
///      * dataByte1           - Data
///      * dataByte2           - Data
///      * timestamp           - The timestamp for the command as a string.
///
///    * `systemKeepAlive` - System keep alive message:
///      * dataByte1           - Data
///      * dataByte2           - Data
///      * timestamp           - The timestamp for the command as a string.
///
static int midi_callback(lua_State *L) {
    
    //
    // Check Arguments:
    //
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];
    
    //
    // Get Midi Device:
    //
    HSMidiDevice            *wrapper   = [skin toNSObjectAtIndex:1] ;
    MIKMIDIDevice           *device    = wrapper.midiDevice;
    MIKMIDIDeviceManager    *manager   = wrapper.midiDeviceManager;
    
    //
    // Remove the existing callback:
    //
    wrapper.callbackRef = [skin luaUnref:refTable ref:wrapper.callbackRef];
    
    //
    // Setup the new callback:
    //
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        wrapper.callbackRef = [skin luaRef:refTable];
        
        //
        // Setup MIDI Device End Point:
        //
        NSArray *source = [device.entities valueForKeyPath:@"@unionOfArrays.sources"];
        MIKMIDISourceEndpoint *endpoint = [source objectAtIndex:0];
        
        //
        // Setup Event:
        //
        NSError *error = nil;
        [manager connectInput:endpoint error:&error eventHandler:^(MIKMIDISourceEndpoint *source, NSArray<MIKMIDICommand *> *commands) {
            for (MIKMIDICommand *command in commands) {
                LuaSkin *skin = [LuaSkin shared] ;
                if (wrapper.callbackRef != LUA_NOREF) {
                    
                    //
                    // Update Callback Function:
                    //
                    lua_State *_L = [skin L];
                    [skin pushLuaRef:refTable ref:wrapper.callbackRef];
                    
                    //
                    // Get Device Name:
                    //
                    NSString *deviceName;
                    deviceName = [device name];
                    
                    //
                    // Get Description:
                    //
                    NSString *description;
                    description = [command description];
                    
                    //
                    // Get Command Type:
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
                    // Get Time Stamp:
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
                            lua_pushinteger(L, result.dataByte1);                  lua_setfield(L, -2, "dataByte1");
                            lua_pushinteger(L, result.dataByte2);                  lua_setfield(L, -2, "dataByte2");
                            lua_pushstring(L, [timestamp UTF8String]);              lua_setfield(L, -2, "timestamp");
                            break;
                        }
                        case MIKMIDICommandTypeSystemExclusive: {
                            ///      * manufacturerID      - The manufacturer ID for the command. This is used by devices to determine if the message is one they support.
                            ///      * sysexChannel        - The channel of the message. Only valid for universal exclusive messages, will always be 0 for non-universal messages.
                            ///      * sysexData           - The system exclusive data for the message. For universal messages subID's are included in sysexData, for non-universal messages, any device specific information (such as modelID, versionID or whatever manufactures decide to include) will be included in sysexData.
                            ///      * timestamp           - The timestamp for the command as a string.
                            MIKMIDISystemExclusiveCommand *result = (MIKMIDISystemExclusiveCommand *)command;
                            lua_newtable(L) ;
                            lua_pushinteger(L, result.manufacturerID);             lua_setfield(L, -2, "manufacturerID");
                            lua_pushinteger(L, result.sysexChannel);               lua_setfield(L, -2, "sysexChannel");
                            NSString *sysexData = [[NSString alloc] initWithData:result.sysexData encoding:NSUTF8StringEncoding];
                            lua_pushstring(L, [sysexData UTF8String]);             lua_setfield(L, -2, "sysexData");
                            lua_pushstring(L, [timestamp UTF8String]);             lua_setfield(L, -2, "timestamp");
                            break;
                        }
                        case MIKMIDICommandTypeSystemTimecodeQuarterFrame:
                        case MIKMIDICommandTypeSystemSongPositionPointer:
                        case MIKMIDICommandTypeSystemSongSelect:
                        case MIKMIDICommandTypeSystemTuneRequest:
                        case MIKMIDICommandTypeSystemTimingClock:
                        case MIKMIDICommandTypeSystemStartSequence:
                        case MIKMIDICommandTypeSystemContinueSequence:
                        case MIKMIDICommandTypeSystemStopSequence:
                        case MIKMIDICommandTypeSystemKeepAlive: {
                            ///      * dataByte1           - Data
                            ///      * dataByte2           - Data
                            ///      * timestamp           - The timestamp for the command as a string.
                            MIKMIDICommand *result = (MIKMIDICommand *)command;
                            lua_newtable(L) ;
                            lua_pushinteger(L, result.dataByte1);                  lua_setfield(L, -2, "dataByte1");
                            lua_pushinteger(L, result.dataByte2);                  lua_setfield(L, -2, "dataByte2");
                            lua_pushstring(L, [timestamp UTF8String]);              lua_setfield(L, -2, "timestamp");
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
/// Returns the name of a `hs.midi` object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The name as a string.
static int midi_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSMidiDevice *wrapper = [skin toNSObjectAtIndex:1] ;
    NSString *deviceName = [wrapper.midiDevice name];
    [skin pushNSObject:deviceName];
    return 1;
}

/// hs.midi:displayName() -> string
/// Method
/// Returns the display name of a `hs.midi` object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The name as a string.
static int midi_displayName(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSMidiDevice *wrapper = [skin toNSObjectAtIndex:1] ;
    NSString *displayName = [wrapper.midiDevice displayName];
    [skin pushNSObject:displayName];
    return 1;
}

/// hs.midi:model() -> string
/// Method
/// Returns the model name of a `hs.midi` object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The model name as a string.
static int midi_model(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSMidiDevice *wrapper = [skin toNSObjectAtIndex:1] ;
    NSString *model = [wrapper.midiDevice model];
    [skin pushNSObject:model];
    return 1;
}

/// hs.midi:manufacturer() -> string
/// Method
/// Returns the manufacturer name of a `hs.midi` object.
///
/// Parameters:
///  * None
///
/// Returns:
///  * The manufacturer name as a string.
static int midi_manufacturer(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSMidiDevice *wrapper = [skin toNSObjectAtIndex:1] ;
    NSString *manufacturer = [wrapper.midiDevice manufacturer];
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
    HSMidiDevice *wrapper = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, [wrapper.midiDevice isOnline]);
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

//
// NOTE: These must not throw a Lua error to ensure LuaSkin can safely be used from Objective-C delegates and blocks:
//

//
// Setup MIDI Device:
//
static int pushHSMidiDevice(lua_State *L, id obj) {
     HSMidiDevice *value = obj;
     value.selfRefCount++ ;
     void** valuePtr = lua_newuserdata(L, sizeof(HSMidiDevice *));
     *valuePtr = (__bridge_retained void *)value;
     luaL_getmetatable(L, USERDATA_TAG);
     lua_setmetatable(L, -2);
     return 1;
}

id toHSMidiDeviceFromLua(lua_State *L, int idx) {
     LuaSkin *skin = [LuaSkin shared] ;
     HSMidiDevice *value ;
     if (luaL_testudata(L, idx, USERDATA_TAG)) {
         value = get_objectFromUserdata(__bridge HSMidiDevice, L, idx, USERDATA_TAG) ;
     } else {
         [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                    lua_typename(L, lua_type(L, idx))]] ;
     }
     return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
     LuaSkin *skin = [LuaSkin shared] ;
     HSMidiDevice *obj = [skin luaObjectAtIndex:1 toClass:"HSMidiDevice"] ;
     NSString *title = obj.midiDevice.displayName ;
     [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
     return 1 ;
}

static int userdata_eq(lua_State* L) {
    //
    // Can't get here if at least one of us isn't a userdata type, and we only care if both types are ours, so use luaL_testudata before the macro causes a Lua error:
    //
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin shared] ;
        HSMidiDevice *obj1 = [skin luaObjectAtIndex:1 toClass:"HSMidiDevice"] ;
        HSMidiDevice *obj2 = [skin luaObjectAtIndex:2 toClass:"HSMidiDevice"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

//
// User Data Garbage Collection:
//
static int userdata_gc(lua_State* L) {
    HSMidiDevice *obj = get_objectFromUserdata(__bridge_transfer HSMidiDevice, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            obj = nil ;
        }
    }
    //
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    //
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

//
// Metatable Garbage Collection:
//
static int meta_gc(lua_State* __unused L) {
    return 0 ;
}

//
// Metatable for userdata objects:
//
static const luaL_Reg userdata_metaLib[] = {
    {"name", midi_name},
    {"displayName", midi_displayName},
    {"isOnline", midi_isOnline},
    {"callback", midi_callback},
    {"manufacturer", midi_manufacturer},
    {"model", midi_model},
    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,   NULL}
};

//
// Functions for returned object when module loads:
//
static luaL_Reg moduleLib[] = {
    {"new", midi_new},
    {"devices", devices},
    {"deviceCallback", deviceCallback},
    {NULL, NULL},
};

//
// Metatable for module:
//
static const luaL_Reg module_metaLib[] = {
    {"__gc", meta_gc},
    {NULL,   NULL}
};

//
// Initalise Module:
//
int luaopen_hs_midi_internal(lua_State* __unused L) {
    
    //
    // Register Module:
    //
    LuaSkin *skin = [LuaSkin shared] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];
    
    //
    // Register MIDI Device:
    //
    [skin registerPushNSHelper:pushHSMidiDevice         forClass:"HSMidiDevice"];
    [skin registerLuaObjectHelper:toHSMidiDeviceFromLua forClass:"HSMidiDevice"
              withUserdataMapping:USERDATA_TAG];
    
    // Push Constants:
    pushCommandTypes(L) ; lua_setfield(L, -2, "commandTypes") ;
    return 1;
}
