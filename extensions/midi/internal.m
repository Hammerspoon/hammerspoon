@import Cocoa ;
@import LuaSkin ;

#import "MIKMIDI/MIKMIDI.h"

//
// Establish a unique context for identifying our observers:
//
static const char * const USERDATA_TAG = "hs.midi";
static void *midiKVOContext = &midiKVOContext ;                 // See: http://nshipster.com/key-value-observing/
static LSRefTable refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - String Conversion

@implementation NSData (NSData_Conversion)
- (NSString *)hexadecimalString
{
    /* Returns hexadecimal string of NSData. Empty string if data is empty.   */

    const unsigned char *dataBuffer = (const unsigned char *)[self bytes];

    if (!dataBuffer)
    {
        return [NSString string];
    }

    NSUInteger          dataLength  = [self length];
    NSMutableString     *hexString  = [NSMutableString stringWithCapacity:(dataLength * 2)];

    for (int i = 0; i < dataLength; ++i)
    {
        [hexString appendFormat:@"%02x", (unsigned int)dataBuffer[i]];
    }

    return [NSString stringWithString:hexString];
}
@end

#pragma mark - Support Functions and Classes

//
// MIDI Device:
//
@interface HSMIDIDeviceManager : NSObject
@property                           MIKMIDIDeviceManager *midiDeviceManager ;
@property                           MIKMIDIDevice *midiDevice ;
@property                           MIKMIDISynthesizer *synth ;
@property int                       callbackRef ;
@property int                       deviceCallbackRef ;
@property int                       selfRefCount ;
@property id                        callbackToken;
@end

@implementation HSMIDIDeviceManager

- (id)init
{
    @try {
        self = [super init] ;
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:new - %@", USERDATA_TAG, exception.reason]] ;
        self = nil ;
    }

    if (self) {
        _midiDeviceManager = [MIKMIDIDeviceManager sharedDeviceManager];
        if (_midiDeviceManager) {
            _callbackRef             = LUA_NOREF ;
            _deviceCallbackRef       = LUA_NOREF ;
            _callbackToken           = nil ;
            _selfRefCount            = 0 ;
        }
    }
    return self ;
}

//
// Availible Devices:
//
- (NSArray *)availableDevices { return self.midiDeviceManager.availableDevices; }

//
// Virtual Sources:
//
- (NSArray *)virtualSources { return self.midiDeviceManager.virtualSources; }

//
// Set Physical Device:
//
- (bool)setPhysicalDevice:(NSString *)deviceName
{
    //
    // Availible Devices:
    //
    NSArray *availableMIDIDevices = [_midiDeviceManager availableDevices];
    for (MIKMIDIDevice * device in availableMIDIDevices)
    {
        NSString *currentDevice = [device name];
        if ([deviceName isEqualToString:currentDevice]) {
            _midiDevice = device;
            return YES;
        }
    }
    return NO;
}

//
// Set Virtual Device:
//
- (bool)setVirtualDevice:(NSString *)deviceName
{
    //
    // Virtual Sources:
    //
    NSArray *virtualSources = [_midiDeviceManager virtualSources];
    for (MIKMIDISourceEndpoint * endpoint in virtualSources)
    {
        NSString *currentDevice = [endpoint name];
        if ([deviceName isEqualToString:currentDevice]) {
            _midiDevice = [MIKMIDIDevice deviceWithVirtualEndpoints:@[endpoint]];
            return YES;
        }
    }
    return NO;
}

#pragma mark - hs.midi.deviceCallback Functions

//
// Watch Devices:
//
- (void)watchDevices
{
    //
    // Availible Devices:
    //
    @try {
        [_midiDeviceManager addObserver:self forKeyPath:@"availableDevices" options:NSKeyValueObservingOptionInitial context:midiKVOContext];
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:deviceCallback - %@", USERDATA_TAG, exception.reason]] ;
    }
    //
    // Virtual Sources:
    //
    @try {
        [_midiDeviceManager addObserver:self forKeyPath:@"virtualSources" options:NSKeyValueObservingOptionInitial context:midiKVOContext];
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:deviceCallback - %@", USERDATA_TAG, exception.reason]] ;
    }
}

//
// Unwatch Devices:
//
- (void)unwatchDevices
{
    //
    // Availible Devices:
    //
    @try {
        [_midiDeviceManager removeObserver:self forKeyPath:@"availableDevices" context:midiKVOContext] ;
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:deviceCallback - %@", USERDATA_TAG, exception.reason]] ;
    }
    //
    // Virtual Sources:
    //
    @try {
        [_midiDeviceManager removeObserver:self forKeyPath:@"virtualSources" context:midiKVOContext] ;
    }
    @catch (NSException *exception) {
        [LuaSkin logError:[NSString stringWithFormat:@"%s:deviceCallback - %@", USERDATA_TAG, exception.reason]] ;
    }
}

#pragma mark - MIDI Synthesis

//
// Start Synthesize:
//
- (void)startSynthesize
{
    MIKMIDISourceEndpoint *endpoint = self.midiDevice.entities.firstObject.sources.firstObject;
    _synth = [[MIKMIDIEndpointSynthesizer alloc] initWithMIDISource:endpoint error:NULL];
}

//
// Stop Synthesize:
//
- (void)stopSynthesize
{
    _synth = nil;
}

#pragma mark - MIDI Functions

//
// Send Sysex:
//
- (void)sendSysex:(NSString *)commandString
{

    if (!commandString || commandString.length == 0) {
        return;
    }

    //
    // Remove Any Spaces in commandString:
    //
    commandString = [commandString stringByReplacingOccurrencesOfString:@" " withString:@""];

    struct MIDIPacket packet;
    packet.timeStamp = mach_absolute_time();
    packet.length = commandString.length / 2;

    char byte_chars[3] = {'\0','\0','\0'};
    for (int i = 0; i < packet.length; i++) {
        byte_chars[0] = [commandString characterAtIndex:i*2];
        byte_chars[1] = [commandString characterAtIndex:i*2+1];
        packet.data[i] = strtol(byte_chars, NULL, 16);;
    }

    MIKMIDICommand *command = [MIKMIDICommand commandWithMIDIPacket:&packet];

    NSArray *destinations = [self.midiDevice.entities valueForKeyPath:@"@unionOfArrays.destinations"];
    if (![destinations count]) return;
    for (MIKMIDIDestinationEndpoint *destination in destinations) {
        NSError *error = nil;
        if (![self.midiDeviceManager sendCommands:@[command] toEndpoint:destination error:&error]) {
            [LuaSkin logError:[NSString stringWithFormat:@"Unable to send command %@ to endpoint %@: %@", command, destination, error]] ;
        }
    }
}

#pragma mark - KVO

//
// Observer:
//
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == midiKVOContext) {
        if (([keyPath isEqualToString:@"availableDevices"]) || ([keyPath isEqualToString:@"virtualSources"])) {
            if (_deviceCallbackRef != LUA_NOREF) {
                LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
                _lua_stackguard_entry(skin.L);
                [skin pushLuaRef:refTable ref:_deviceCallbackRef] ;

                //
                // Availible Devices:
                //
                NSMutableArray *deviceNames = [[NSMutableArray alloc]init];
                for (MIKMIDIDevice * device in self.availableDevices)
                {
                    if ([device name]) {
                        [deviceNames addObject:[device name]];
                    }

                }

                //
                // Virtual Sources:
                //
                NSArray *virtualSources = [[MIKMIDIDeviceManager sharedDeviceManager] virtualSources];
                NSMutableArray *virtualDeviceNames = [[NSMutableArray alloc]init];
                for (MIKMIDIDevice * device in virtualSources)
                {
                    if ([device name]) {
                        [virtualDeviceNames addObject:[device name]];
                    }
                }

                [skin pushNSObject:deviceNames];
                [skin pushNSObject:virtualDeviceNames];
                [skin protectedCallAndError:@"hs.midi:deviceCallback" nargs:2 nresults:0];
                _lua_stackguard_exit(skin.L);
            }
        }
    }
}

@end

//
// hs.midi.deviceCallback Manager:
//
HSMIDIDeviceManager *watcherDeviceManager;

#pragma mark - Module Functions

/// hs.midi.devices() -> table
/// Function
/// Returns a table of currently connected physical MIDI devices.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the names of any physically connected MIDI devices as strings.
static int devices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSArray *availableMIDIDevices = [[MIKMIDIDeviceManager sharedDeviceManager] availableDevices];
    NSMutableArray *deviceNames = [NSMutableArray array];
    for (MIKMIDIDevice * device in availableMIDIDevices)
    {
        [deviceNames addObject:[device name]];
    }
    [skin pushNSObject:deviceNames];
    return 1 ;
}

/// hs.midi.virtualSources() -> table
/// Function
/// Returns a table of currently available Virtual MIDI sources. This includes devices, such as Native Instruments controllers which present as virtual endpoints rather than physical devices.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the names of any virtual MIDI sources as strings.
static int virtualSources(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    NSArray *virtualSources = [[MIKMIDIDeviceManager sharedDeviceManager] virtualSources];
    NSMutableArray *deviceNames = [NSMutableArray array];
    for (MIKMIDIDevice * device in virtualSources)
    {
        [deviceNames addObject:[device name]];
    }
    [skin pushNSObject:deviceNames];
    return 1 ;
}

/// hs.midi.deviceCallback(callbackFn) -> none
/// Function
/// A callback that's triggered when a physical or virtual MIDI device is added or removed from the system.
///
/// Parameters:
///  * callbackFn - the callback function to trigger.
///
/// Returns:
///  * None
///
/// Notes:
///  * The callback function should expect 2 argument and should not return anything:
///    * `devices` - A table containing the names of any physically connected MIDI devices as strings.
///    * `virtualDevices` - A table containing the names of any virtual MIDI devices as strings.
///  * Example Usage:
///    ```
///    hs.midi.deviceCallback(function(devices, virtualDevices)
///         print(hs.inspect(devices))
///         print(hs.inspect(virtualDevices))
///    end)
///    ```
static int deviceCallback(lua_State *L) {

    //
    // Check Arguments:
    //
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TFUNCTION | LS_TNIL, LS_TBREAK];

    //
    // Setup or Remove Callback Function:
    //
    if (!watcherDeviceManager) {
        watcherDeviceManager = [[HSMIDIDeviceManager alloc] init] ;
    } else {
        if (watcherDeviceManager.deviceCallbackRef != LUA_NOREF) [watcherDeviceManager unwatchDevices] ;
    }
    watcherDeviceManager.deviceCallbackRef = [skin luaUnref:refTable ref:watcherDeviceManager.deviceCallbackRef] ;
    if (lua_type(skin.L, 1) != LUA_TNIL) { // may be table with __call metamethod
        watcherDeviceManager.deviceCallbackRef = [skin luaRef:refTable atIndex:1];
        [watcherDeviceManager watchDevices];
    }
    else {
        //         [watcherDeviceManager unwatchDevices];
        watcherDeviceManager = nil ;
    }

    return 0;
}

/// hs.midi.new(deviceName) -> `hs.midi` object
/// Constructor
/// Creates a new `hs.midi` object.
///
/// Parameters:
///  * deviceName - A string containing the device name of the MIDI device. A valid device name can be found by checking `hs.midi.devices()` and/or `hs.midi.virtualSources()`.
///
/// Returns:
///  * An `hs.midi` object or `nil` if an error occured.
///
/// Notes:
///  * Example Usage:
///    `hs.midi.new(hs.midi.devices()[1])`
static int midi_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    HSMIDIDeviceManager *manager = [[HSMIDIDeviceManager alloc] init] ;
    bool result = [manager setPhysicalDevice:[skin toNSObjectAtIndex:1]];
    if (manager && result) {
        [skin pushNSObject:manager] ;
    } else {
        manager = nil ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.midi.newVirtualSource(virtualSource) -> `hs.midi` object
/// Constructor
/// Creates a new `hs.midi` object.
///
/// Parameters:
///  * virtualSource - A string containing the virtual source name of the MIDI device. A valid virtual source name can be found by checking `hs.midi.virtualSources()`.
///
/// Returns:
///  * An `hs.midi` object or `nil` if an error occured.
///
/// Notes:
///  * Example Usage:
///    `hs.midi.new(hs.midi.virtualSources()[1])`
static int midi_newVirtualSource(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;
    HSMIDIDeviceManager *manager = [[HSMIDIDeviceManager alloc] init] ;
    bool result = [manager setVirtualDevice:[skin toNSObjectAtIndex:1]];
    if (manager && result) {
        [skin pushNSObject:manager] ;
    } else {
        manager = nil ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Methods

/// hs.midi:callback(callbackFn)
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
///  * Most MIDI keyboards produce a `noteOn` when you press a key, then `noteOff` when you release. However, some MIDI keyboards will return a `noteOn` with 0 `velocity` instead of `noteOff`, so you will recieve two `noteOn` commands for every key press/release.
///  * The callback function should expect 5 arguments and should not return anything:
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
///      * channel             - The channel for the command. Must be a number between 15.
///      * timestamp           - The timestamp for the command as a string.
///      * data                - Raw MIDI Data as Hex String.
///      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
///
///    * `noteOn` - Note on command:
///      * note                - The note number for the command. Must be between 0 and 127.
///      * velocity            - The velocity for the command. Must be between 0 and 127.
///      * channel             - The channel for the command. Must be a number between 15.
///      * timestamp           - The timestamp for the command as a string.
///      * data                - Raw MIDI Data as Hex String.
///      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
///
///    * `polyphonicKeyPressure` - Polyphonic key pressure command:
///      * note                - The note number for the command. Must be between 0 and 127.
///      * pressure            - Key pressure of the polyphonic key pressure message. In the range 0-127.
///      * channel             - The channel for the command. Must be a number between 15.
///      * timestamp           - The timestamp for the command as a string.
///      * data                - Raw MIDI Data as Hex String.
///      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
///
///    * `controlChange` - Control change command. This is the most common command sent by MIDI controllers:
///      * controllerNumber    - The MIDI control number for the command.
///      * controllerValue     - The controllerValue of the command. Only the lower 7-bits of this are used.
///      * channel             - The channel for the command. Must be a number between 15.
///      * timestamp           - The timestamp for the command as a string.
///      * data                - Raw MIDI Data as Hex String.
///      * fourteenBitValue    - The 14-bit value of the command.
///      * fourteenBitCommand  - `true` if the command contains 14-bit value data otherwise, `false`.
///      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
///
///    * `programChange` - Program change command:
///      * programNumber       - The program (aka patch) number. From 0-127.
///      * channel             - The channel for the command. Must be a number between 15.
///      * timestamp           - The timestamp for the command as a string.
///      * data                - Raw MIDI Data as Hex String.
///      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
///
///    * `channelPressure` - Channel pressure command:
///      * pressure            - Key pressure of the channel pressure message. In the range 0-127.
///      * channel             - The channel for the command. Must be a number between 15.
///      * timestamp           - The timestamp for the command as a string.
///      * data                - Raw MIDI Data as Hex String.
///      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
///
///    * `pitchWheelChange` - Pitch wheel change command:
///      * pitchChange         -  A 14-bit value indicating the pitch bend. Center is 0x2000 (8192). Valid range is from 0-16383.
///      * channel             - The channel for the command. Must be a number between 15.
///      * timestamp           - The timestamp for the command as a string.
///      * data                - Raw MIDI Data as Hex String.
///      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
///
///    * `systemMessage` - System message command:
///      * dataByte1           - Data Byte 1 as integer.
///      * dataByte2           - Data Byte 2 as integer.
///      * timestamp           - The timestamp for the command as a string.
///      * data                - Raw MIDI Data as Hex String.
///      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
///
///    * `systemExclusive` - System message command:
///      * manufacturerID      - The manufacturer ID for the command. This is used by devices to determine if the message is one they support.
///      * sysexChannel        - The channel of the message. Only valid for universal exclusive messages, will always be 0 for non-universal messages.
///      * sysexData           - The system exclusive data for the message. For universal messages subID's are included in sysexData, for non-universal messages, any device specific information (such as modelID, versionID or whatever manufactures decide to include) will be included in sysexData.
///      * timestamp           - The timestamp for the command as a string.
///      * data                - Raw MIDI Data as Hex String.
///      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
///
///    * `systemTimecodeQuarterFrame` - System exclusive (SysEx) command:
///      * dataByte1           - Data Byte 1 as integer.
///      * dataByte2           - Data Byte 2 as integer.
///      * timestamp           - The timestamp for the command as a string.
///      * data                - Raw MIDI Data as Hex String.
///      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
///
///    * `systemSongPositionPointer` - System song position pointer command:
///      * dataByte1           - Data Byte 1 as integer.
///      * dataByte2           - Data Byte 2 as integer.
///      * timestamp           - The timestamp for the command as a string.
///      * data                - Raw MIDI Data as Hex String.
///      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
///
///    * `systemSongSelect` - System song select command:
///      * dataByte1           - Data Byte 1 as integer.
///      * dataByte2           - Data Byte 2 as integer.
///      * timestamp           - The timestamp for the command as a string.
///      * data                - Raw MIDI Data as Hex String.
///      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
///
///    * `systemTuneRequest` - System tune request command:
///      * dataByte1           - Data Byte 1 as integer.
///      * dataByte2           - Data Byte 2 as integer.
///      * timestamp           - The timestamp for the command as a string.
///      * data                - Raw MIDI Data as Hex String.
///      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
///
///    * `systemTimingClock` - System timing clock command:
///      * dataByte1           - Data Byte 1 as integer.
///      * dataByte2           - Data Byte 2 as integer.
///      * timestamp           - The timestamp for the command as a string.
///      * data                - Raw MIDI Data as Hex String.
///      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
///
///    * `systemStartSequence` - System timing clock command:
///      * dataByte1           - Data Byte 1 as integer.
///      * dataByte2           - Data Byte 2 as integer.
///      * timestamp           - The timestamp for the command as a string.
///      * data                - Raw MIDI Data as Hex String.
///      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
///
///    * `systemContinueSequence` - System start sequence command:
///      * dataByte1           - Data Byte 1 as integer.
///      * dataByte2           - Data Byte 2 as integer.
///      * timestamp           - The timestamp for the command as a string.
///      * data                - Raw MIDI Data as Hex String.
///      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
///
///    * `systemStopSequence` -  System continue sequence command:
///      * dataByte1           - Data Byte 1 as integer.
///      * dataByte2           - Data Byte 2 as integer.
///      * timestamp           - The timestamp for the command as a string.
///      * data                - Raw MIDI Data as Hex String.
///      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
///
///    * `systemKeepAlive` - System keep alive message:
///      * dataByte1           - Data Byte 1 as integer.
///      * dataByte2           - Data Byte 2 as integer.
///      * timestamp           - The timestamp for the command as a string.
///      * data                - Raw MIDI Data as Hex String.
///      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
///
///  * Example Usage:
///    ```
///    midiDevice = hs.midi.new(hs.midi.devices()[3])
///    midiDevice:callback(function(object, deviceName, commandType, description, metadata)
///               print("object: " .. tostring(object))
///               print("deviceName: " .. deviceName)
///               print("commandType: " .. commandType)
///               print("description: " .. description)
///               print("metadata: " .. hs.inspect(metadata))
///               end)
///    ```
static int midi_callback(lua_State *L) {

    //
    // Check Arguments:
    //
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];

    //
    // Get MIDI Device:
    //
    HSMIDIDeviceManager     *wrapper   = [skin toNSObjectAtIndex:1] ;
    MIKMIDIDevice           *device    = wrapper.midiDevice;
    MIKMIDIDeviceManager    *manager   = wrapper.midiDeviceManager;

    //
    // Remove the existing callback:
    //
    wrapper.callbackRef = [skin luaUnref:refTable ref:wrapper.callbackRef];
    if (wrapper.callbackToken != nil) {
        [manager disconnectConnectionForToken:wrapper.callbackToken];
        wrapper.callbackToken = nil;
    }

    //
    // Setup the new callback:
    //
    if (lua_type(L, 2) != LUA_TNIL) { // may be table with __call metamethod
        lua_pushvalue(L, 2);
        wrapper.callbackRef = [skin luaRef:refTable];

        //
        // Setup MIDI Device End Point:
        //
        NSArray *source = [device.entities valueForKeyPath:@"@unionOfArrays.sources"];
        if (source.count == 0) {
            //
            // This shouldn't happen, but if it does, catch the error:
            //
            [skin logError:[NSString stringWithFormat:@"%s:callback error:%@", USERDATA_TAG, @"No MIDI Device End Points detected."]] ;
            wrapper.callbackToken = nil;
            lua_pushvalue(L, 1);
            return 1;
        }
        MIKMIDISourceEndpoint *endpoint = [source objectAtIndex:0];

        //
        // Setup Event:
        //
        NSError *error = nil;
        id result;
        result = [manager connectInput:endpoint error:&error eventHandler:^(MIKMIDISourceEndpoint *source, NSArray<MIKMIDICommand *> *commands) {
            for (MIKMIDICommand *command in commands) {
                LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
                if (wrapper.callbackRef != LUA_NOREF) {

                    //
                    // Update Callback Function:
                    //
                    [skin pushLuaRef:refTable ref:wrapper.callbackRef];

                    //
                    // Get Device Name:
                    //
                    NSString *deviceName;
                    deviceName = [device name];

                    //
                    // Get Virtual Status:
                    //
                    BOOL isVirtual = [device isVirtual];

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
                            commandTypeString = @"noteOff";
                            break;
                        }
                        case MIKMIDICommandTypeNoteOn:{
                            commandTypeString = @"noteOn";
                            break;
                        }
                        case MIKMIDICommandTypePolyphonicKeyPressure:{
                            commandTypeString = @"polyphonicKeyPressure";
                            break;
                        }
                        case MIKMIDICommandTypeControlChange:{
                            commandTypeString = @"controlChange";
                            break;
                        }
                        case MIKMIDICommandTypeProgramChange:{
                            commandTypeString = @"programChange";
                            break;
                        }
                        case MIKMIDICommandTypeChannelPressure:{
                            commandTypeString = @"channelPressure";
                            break;
                        }
                        case MIKMIDICommandTypePitchWheelChange:{
                            commandTypeString = @"pitchWheelChange";
                            break;
                        }
                        case MIKMIDICommandTypeSystemMessage:{
                            commandTypeString = @"systemMessage";
                            break;
                        }
                        case MIKMIDICommandTypeSystemExclusive:{
                            commandTypeString = @"systemExclusive";
                            break;
                        }
                        case MIKMIDICommandTypeSystemTimecodeQuarterFrame:{
                            commandTypeString = @"systemTimecodeQuarterFrame";
                            break;
                        }
                        case MIKMIDICommandTypeSystemSongPositionPointer:{
                            commandTypeString = @"systemSongPositionPointer";
                            break;
                        }
                        case MIKMIDICommandTypeSystemSongSelect:{
                            commandTypeString = @"systemSongSelect";
                            break;
                        }
                        case MIKMIDICommandTypeSystemTuneRequest:{
                            commandTypeString = @"systemTuneRequest";
                            break;
                        }
                        case MIKMIDICommandTypeSystemTimingClock:{
                            commandTypeString = @"systemTimingClock";
                            break;
                        }
                        case MIKMIDICommandTypeSystemStartSequence:{
                            commandTypeString = @"systemStartSequence";
                            break;
                        }
                        case MIKMIDICommandTypeSystemContinueSequence:{
                            commandTypeString = @"systemContinueSequence";
                            break;
                        }
                        case MIKMIDICommandTypeSystemStopSequence:{
                            commandTypeString = @"systemStopSequence";
                            break;
                        }
                        case MIKMIDICommandTypeSystemKeepAlive:{
                            commandTypeString = @"systemKeepAlive";
                            break;
                        }
                    };

                    //
                    // Push Values:
                    //
                    [skin pushNSObject:wrapper];                ///    * `object`       - The `hs.midi` object.
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
                            //      * note                - The note number for the command. Must be between 0 and 127.
                            //      * velocity            - The velocity for the command. Must be between 0 and 127.
                            //      * channel             - The channel for the command. Must be a number between 15.
                            //      * timestamp           - The timestamp for the command.
                            //      * data                - Raw MIDI Data as Hex String.
                            //      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
                            MIKMIDINoteOffCommand *noteCommand = (MIKMIDINoteOffCommand *)command;
                            NSString *data = [noteCommand.data hexadecimalString];
                            lua_newtable(L) ;
                            lua_pushinteger(L, noteCommand.note);             lua_setfield(L, -2, "note");
                            lua_pushinteger(L, noteCommand.velocity);         lua_setfield(L, -2, "velocity");
                            lua_pushinteger(L, noteCommand.channel);          lua_setfield(L, -2, "channel");
                            lua_pushstring(L, [timestamp UTF8String]);        lua_setfield(L, -2, "timestamp");
                            lua_pushstring(L, [data UTF8String]);             lua_setfield(L, -2, "data");
                            lua_pushboolean(L, isVirtual);                    lua_setfield(L, -2, "isVirtual");
                            break;
                        }
                        case MIKMIDICommandTypeNoteOn: {
                            //      * note                - The note number for the command. Must be between 0 and 127.
                            //      * velocity            - The velocity for the command. Must be between 0 and 127.
                            //      * channel             - The channel for the command. Must be a number between 15.
                            //      * timestamp           - The timestamp for the command.
                            //      * data                - Raw MIDI Data as Hex String.
                            //      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
                            MIKMIDINoteOnCommand *noteCommand = (MIKMIDINoteOnCommand *)command;
                            NSString *data = [noteCommand.data hexadecimalString];
                            lua_newtable(L) ;
                            lua_pushinteger(L, noteCommand.note);             lua_setfield(L, -2, "note");
                            lua_pushinteger(L, noteCommand.velocity);         lua_setfield(L, -2, "velocity");
                            lua_pushinteger(L, noteCommand.channel);          lua_setfield(L, -2, "channel");
                            lua_pushstring(L, [timestamp UTF8String]);        lua_setfield(L, -2, "timestamp");
                            lua_pushstring(L, [data UTF8String]);             lua_setfield(L, -2, "data");
                            lua_pushboolean(L, isVirtual);                    lua_setfield(L, -2, "isVirtual");
                            break;
                        }
                        case MIKMIDICommandTypePolyphonicKeyPressure: {
                            //      * note                - The note number for the command. Must be between 0 and 127.
                            //      * pressure            - Key pressure of the polyphonic key pressure message. In the range 0-127.
                            //      * channel             - The channel for the command. Must be a number between 15.
                            //      * timestamp           - The timestamp for the command.
                            //      * data                - Raw MIDI Data as Hex String.
                            //      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
                            MIKMIDIPolyphonicKeyPressureCommand *noteCommand = (MIKMIDIPolyphonicKeyPressureCommand *)command;
                            NSString *data = [noteCommand.data hexadecimalString];
                            lua_newtable(L) ;
                            lua_pushinteger(L, noteCommand.note);             lua_setfield(L, -2, "note");
                            lua_pushinteger(L, noteCommand.pressure);         lua_setfield(L, -2, "pressure");
                            lua_pushinteger(L, noteCommand.channel);          lua_setfield(L, -2, "channel");
                            lua_pushstring(L, [timestamp UTF8String]);        lua_setfield(L, -2, "timestamp");
                            lua_pushstring(L, [data UTF8String]);             lua_setfield(L, -2, "data");
                            lua_pushboolean(L, isVirtual);                    lua_setfield(L, -2, "isVirtual");
                            break;
                        }
                        case MIKMIDICommandTypeControlChange: {
                            //      * controllerNumber    - The MIDI control number for the command.
                            //      * controllerValue     - The controllerValue of the command. Only the lower 7-bits of this are used.
                            //      * channel             - The channel for the command. Must be a number between 15.
                            //      * timestamp           - The timestamp for the command.
                            //      * data                - Raw MIDI Data as Hex String.
                            //      * fourteenBitValue    - The 14-bit value of the command.
                            //      * fourteenBitCommand  - `true` if the command contains 14-bit value data.
                            //      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
                            MIKMIDIControlChangeCommand *result = (MIKMIDIControlChangeCommand *)command;
                            NSString *data = [result.data hexadecimalString];
                            lua_newtable(L) ;
                            lua_pushinteger(L, result.controllerNumber);             lua_setfield(L, -2, "controllerNumber");
                            lua_pushinteger(L, result.value);                        lua_setfield(L, -2, "controllerValue");
                            lua_pushinteger(L, result.channel);                      lua_setfield(L, -2, "channel");
                            lua_pushstring(L, [timestamp UTF8String]);               lua_setfield(L, -2, "timestamp");
                            lua_pushstring(L, [data UTF8String]);                    lua_setfield(L, -2, "data");
                            lua_pushinteger(L, result.fourteenBitValue);             lua_setfield(L, -2, "fourteenBitValue");
                            lua_pushboolean(L, result.fourteenBitCommand);           lua_setfield(L, -2, "fourteenBitCommand");
                            lua_pushboolean(L, isVirtual);                           lua_setfield(L, -2, "isVirtual");
                            break;
                        }
                        case MIKMIDICommandTypeProgramChange: {
                            //      * programNumber       - The program (aka patch) number. From 0-127.
                            //      * channel             - The channel for the command. Must be a number between 15.
                            //      * timestamp           - The timestamp for the command as a string.
                            //      * data                - Raw MIDI Data as Hex String.
                            //      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
                            MIKMIDIProgramChangeCommand *result = (MIKMIDIProgramChangeCommand *)command;
                            NSString *data = [result.data hexadecimalString];
                            lua_newtable(L) ;
                            lua_pushinteger(L, result.programNumber);                lua_setfield(L, -2, "programNumber");
                            lua_pushinteger(L, result.channel);                      lua_setfield(L, -2, "channel");
                            lua_pushstring(L, [timestamp UTF8String]);               lua_setfield(L, -2, "timestamp");
                            lua_pushstring(L, [data UTF8String]);                    lua_setfield(L, -2, "data");
                            lua_pushboolean(L, isVirtual);                           lua_setfield(L, -2, "isVirtual");
                            break;
                        }
                        case MIKMIDICommandTypeChannelPressure: {
                            //      * pressure            - Key pressure of the channel pressure message. In the range 0-127.
                            //      * channel             - The channel for the command. Must be a number between 15.
                            //      * timestamp           - The timestamp for the command as a string.
                            //      * data                - Raw MIDI Data as Hex String.
                            //      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
                            MIKMIDIChannelPressureCommand *result = (MIKMIDIChannelPressureCommand *)command;
                            NSString *data = [result.data hexadecimalString];
                            lua_newtable(L) ;
                            lua_pushinteger(L, result.pressure);                     lua_setfield(L, -2, "pressure");
                            lua_pushinteger(L, result.channel);                      lua_setfield(L, -2, "channel");
                            lua_pushstring(L, [timestamp UTF8String]);               lua_setfield(L, -2, "timestamp");
                            lua_pushstring(L, [data UTF8String]);                    lua_setfield(L, -2, "data");
                            lua_pushboolean(L, isVirtual);                           lua_setfield(L, -2, "isVirtual");
                            break;
                        }
                        case MIKMIDICommandTypePitchWheelChange: {
                            //      * pitchChange         -  A 14-bit value indicating the pitch bend. Center is 0x2000 (8192). Valid range is from 0-16383.
                            //      * channel             - The channel for the command. Must be a number between 15.
                            //      * timestamp           - The timestamp for the command as a string.
                            //      * data                - Raw MIDI Data as Hex String.
                            //      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
                            MIKMIDIPitchBendChangeCommand *result = (MIKMIDIPitchBendChangeCommand *)command;
                            NSString *data = [result.data hexadecimalString];
                            lua_newtable(L) ;
                            lua_pushinteger(L, result.pitchChange);                 lua_setfield(L, -2, "pitchChange");
                            lua_pushinteger(L, result.channel);                     lua_setfield(L, -2, "channel");
                            lua_pushstring(L, [timestamp UTF8String]);              lua_setfield(L, -2, "timestamp");
                            lua_pushstring(L, [data UTF8String]);                   lua_setfield(L, -2, "data");
                            lua_pushboolean(L, isVirtual);                           lua_setfield(L, -2, "isVirtual");
                            break;
                        }
                        case MIKMIDICommandTypeSystemMessage: {
                            //      * dataByte1           - Data Byte 1 as integer.
                            //      * dataByte2           - Data Byte 2 as integer.
                            //      * timestamp           - The timestamp for the command as a string.
                            //      * data                - Raw MIDI Data as Hex String.
                            //      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
                            MIKMIDISystemMessageCommand *result = (MIKMIDISystemMessageCommand *)command;
                            NSString *data = [result.data hexadecimalString];
                            lua_newtable(L) ;
                            lua_pushinteger(L, result.dataByte1);                  lua_setfield(L, -2, "dataByte1");
                            lua_pushinteger(L, result.dataByte2);                  lua_setfield(L, -2, "dataByte2");
                            lua_pushstring(L, [timestamp UTF8String]);             lua_setfield(L, -2, "timestamp");
                            lua_pushstring(L, [data UTF8String]);                  lua_setfield(L, -2, "data");
                            lua_pushboolean(L, isVirtual);                         lua_setfield(L, -2, "isVirtual");
                            break;
                        }
                        case MIKMIDICommandTypeSystemExclusive: {
                            //      * manufacturerID      - The manufacturer ID for the command. This is used by devices to determine if the message is one they support.
                            //      * sysexChannel        - The channel of the message. Only valid for universal exclusive messages, will always be 0 for non-universal messages.
                            //      * sysexData           - The system exclusive data for the message. For universal messages subID's are included in sysexData, for non-universal messages, any device specific information (such as modelID, versionID or whatever manufactures decide to include) will be included in sysexData.
                            //      * timestamp           - The timestamp for the command as a string.
                            //      * data                - Raw MIDI Data as Hex String.
                            //      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
                            MIKMIDISystemExclusiveCommand *result = (MIKMIDISystemExclusiveCommand *)command;
                            NSString *sysexData = [result.sysexData hexadecimalString];
                            NSString *data = [result.data hexadecimalString];
                            lua_newtable(L) ;
                            lua_pushinteger(L, result.manufacturerID);             lua_setfield(L, -2, "manufacturerID");
                            lua_pushinteger(L, result.sysexChannel);               lua_setfield(L, -2, "sysexChannel");
                            lua_pushstring(L, [timestamp UTF8String]);             lua_setfield(L, -2, "timestamp");
                            lua_pushstring(L, [sysexData UTF8String]);             lua_setfield(L, -2, "sysexData");
                            lua_pushstring(L, [data UTF8String]);                  lua_setfield(L, -2, "data");
                            lua_pushboolean(L, isVirtual);                         lua_setfield(L, -2, "isVirtual");
                            break;
                        }
                        case MIKMIDICommandTypeSystemKeepAlive: {
                            //      * dataByte1           - Data Byte 1 as integer.
                            //      * dataByte2           - Data Byte 2 as integer.
                            //      * timestamp           - The timestamp for the command as a string.
                            //      * data                - Raw MIDI Data as Hex String.
                            //      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
                            MIKMIDISystemKeepAliveCommand *result = (MIKMIDISystemKeepAliveCommand *)command;
                            NSString *data = [result.data hexadecimalString];
                            lua_newtable(L) ;
                            lua_pushinteger(L, result.dataByte1);                  lua_setfield(L, -2, "dataByte1");
                            lua_pushinteger(L, result.dataByte2);                  lua_setfield(L, -2, "dataByte2");
                            lua_pushstring(L, [timestamp UTF8String]);             lua_setfield(L, -2, "timestamp");
                            lua_pushstring(L, [data UTF8String]);                  lua_setfield(L, -2, "data");
                            lua_pushboolean(L, isVirtual);                         lua_setfield(L, -2, "isVirtual");
                            break;
                        }
                        case MIKMIDICommandTypeSystemTimecodeQuarterFrame:
                        case MIKMIDICommandTypeSystemSongPositionPointer:
                        case MIKMIDICommandTypeSystemSongSelect:
                        case MIKMIDICommandTypeSystemTuneRequest:
                        case MIKMIDICommandTypeSystemTimingClock:
                        case MIKMIDICommandTypeSystemStartSequence:
                        case MIKMIDICommandTypeSystemContinueSequence:
                        case MIKMIDICommandTypeSystemStopSequence: {
                            //      * dataByte1           - Data Byte 1 as integer.
                            //      * dataByte2           - Data Byte 2 as integer.
                            //      * timestamp           - The timestamp for the command as a string.
                            //      * data                - Raw MIDI Data as Hex String.
                            //      * isVirtual           - `true` if Virtual MIDI Source otherwise `false`.
                            MIKMIDISystemMessageCommand *result = (MIKMIDISystemMessageCommand *)command;
                            NSString *data = [result.data hexadecimalString];
                            lua_newtable(L) ;
                            lua_pushinteger(L, result.dataByte1);                  lua_setfield(L, -2, "dataByte1");
                            lua_pushinteger(L, result.dataByte2);                  lua_setfield(L, -2, "dataByte2");
                            lua_pushstring(L, [timestamp UTF8String]);             lua_setfield(L, -2, "timestamp");
                            lua_pushstring(L, [data UTF8String]);                  lua_setfield(L, -2, "data");
                            lua_pushboolean(L, isVirtual);                         lua_setfield(L, -2, "isVirtual");
                            break;
                        }
                    };

                    [skin protectedCallAndError:@"hs.midi callback" nargs:5 nresults:0];
                }
            }
        }];

        if (result == nil) {
            [skin logError:[NSString stringWithFormat:@"%s:callback error:%@", USERDATA_TAG, error]] ;
            wrapper.callbackToken = nil;
        }
        else
        {
            wrapper.callbackToken = result;
        }

    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.midi:sendSysex(command) -> none
/// Method
/// Sends a System Exclusive Command to the `hs.midi` object.
///
/// Parameters:
///  * `command` - The system exclusive command you wish to send as a string. White spaces in the string will be ignored.
///
/// Returns:
///  * None
///
/// Notes:
///  * Example Usage:
///    ```midiDevice:sendSysex("f07e7f06 01f7")```
static int midi_sendSysex(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK];
    HSMIDIDeviceManager *wrapper = [skin toNSObjectAtIndex:1] ;
    [wrapper sendSysex:[skin toNSObjectAtIndex:2]];
    return 0;
}

/// hs.midi:sendCommand(commandType, metadata) -> boolean
/// Method
/// Sends a command to the `hs.midi` object.
///
/// Parameters:
///  * `commandType`    - The type of command you want to send as a string. See `hs.midi.commandTypes[]`.
///  * `metadata`       - A table of data for the MIDI command (see notes below).
///
/// Returns:
///  * `true` if successful, otherwise `false`
///
/// Notes:
///  * The `metadata` table can accept following, depending on the `commandType` supplied:
///
///    * `noteOff` - Note off command:
///      * note                - The note number for the command. Must be between 0 and 127. Defaults to 0.
///      * velocity            - The velocity for the command. Must be between 0 and 127. Defaults to 0.
///      * channel             - The channel for the command. Must be a number between 0 and 16. Defaults to 0, which sends the command to All Channels.
///
///    * `noteOn` - Note on command:
///      * note                - The note number for the command. Must be between 0 and 127. Defaults to 0.
///      * velocity            - The velocity for the command. Must be between 0 and 127. Defaults to 0.
///      * channel             - The channel for the command. Must be a number between 0 and 16. Defaults to 0, which sends the command to All Channels.
///
///    * `polyphonicKeyPressure` - Polyphonic key pressure command:
///      * note                - The note number for the command. Must be between 0 and 127. Defaults to 0.
///      * pressure            - Key pressure of the polyphonic key pressure message. In the range 0-127. Defaults to 0.
///      * channel             - The channel for the command. Must be a number between 0 and 16. Defaults to 0, which sends the command to All Channels.
///
///    * `controlChange` - Control change command. This is the most common command sent by MIDI controllers:
///      * controllerNumber    - The MIDI control number for the command. Defaults to 0.
///      * controllerValue     - The controllerValue of the command. Only the lower 7-bits of this are used. Defaults to 0.
///      * channel             - The channel for the command. Must be a number between 0 and 16. Defaults to 0, which sends the command to All Channels.
///      * fourteenBitValue    - The 14-bit value of the command. Must be between 0 and 16383. Defaults to 0. `fourteenBitCommand` must be `true`.
///      * fourteenBitCommand  - `true` if the command contains 14-bit value data otherwise, `false`. `controllerValue` will be ignored if this is set to `true`.
///
///    * `programChange` - Program change command:
///      * programNumber       - The program (aka patch) number. From 0-127. Defaults to 0.
///      * channel             - The channel for the command. Must be a number between 0 and 16. Defaults to 0, which sends the command to All Channels.
///
///    * `channelPressure` - Channel pressure command:
///      * pressure            - Key pressure of the channel pressure message. In the range 0-127. Defaults to 0.
///      * channel             - The channel for the command. Must be a number between 0 and 16. Defaults to 0, which sends the command to All Channels.
///
///    * `pitchWheelChange` - Pitch wheel change command:
///      * pitchChange         -  A 14-bit value indicating the pitch bend. Center is 0x2000 (8192). Valid range is from 0-16383. Defaults to 0.
///      * channel             - The channel for the command. Must be a number between 0 and 16. Defaults to 0, which sends the command to All Channels.
///
///  * Example Usage:
///     ```
///     midiDevice = hs.midi.new(hs.midi.devices()[1])
///     midiDevice:sendCommand("noteOn", {
///         ["note"] = 72,
///         ["velocity"] = 50,
///         ["channel"] = 0,
///     })
///     hs.timer.usleep(500000)
///     midiDevice:sendCommand("noteOn", {
///         ["note"] = 74,
///         ["velocity"] = 50,
///         ["channel"] = 0,
///     })
///     hs.timer.usleep(500000)
///     midiDevice:sendCommand("noteOn", {
///         ["note"] = 76,
///         ["velocity"] = 50,
///         ["channel"] = 0,
///     })
///     midiDevice:sendCommand("pitchWheelChange", {
///         ["pitchChange"] = 1000,
///         ["channel"] = 0,
///     })
///     hs.timer.usleep(100000)
///     midiDevice:sendCommand("pitchWheelChange", {
///         ["pitchChange"] = 2000,
///         ["channel"] = 0,
///     })
///     hs.timer.usleep(100000)
///     midiDevice:sendCommand("pitchWheelChange", {
///         ["pitchChange"] = 3000,
///         ["channel"] = 0,
///     })
///     ```
static int midi_sendCommand(lua_State *L) {

    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TTABLE, LS_TBREAK];

    //
    // Get Parameters:
    //
    NSString *commandType = [skin toNSObjectAtIndex:2];
    NSDate *date = [NSDate date];
    NSError *error = nil;

    //
    // Default Values:
    //
    bool result = true;
    lua_Integer note = 0;
    lua_Integer velocity = 0;
    lua_Integer channel = 0;
    lua_Integer pressure = 0;
    lua_Integer controllerNumber = 0;
    lua_Integer controllerValue = 0;
    lua_Integer programNumber = 0;
    lua_Integer pitchChange = 0;
    lua_Integer fourteenBitValue = 0;
    bool fourteenBitCommand = false;

    //
    // Get Values from metadata table:
    //
    if (lua_istable(L, 3)) {
        if (lua_getfield(L, -1, "note") == LUA_TNUMBER) {
            note = lua_tointeger(L, -1);
        }
        lua_pop(L, 1);
        if (lua_getfield(L, -1, "velocity") == LUA_TNUMBER) {
            velocity = lua_tointeger(L, -1);
        }
        lua_pop(L, 1);
        if (lua_getfield(L, -1, "channel") == LUA_TNUMBER) {
            channel = lua_tointeger(L, -1);
        }
        lua_pop(L, 1);
        if (lua_getfield(L, -1, "pressure") == LUA_TNUMBER) {
            pressure = lua_tointeger(L, -1);
        }
        lua_pop(L, 1);
        if (lua_getfield(L, -1, "controllerNumber") == LUA_TNUMBER) {
            controllerNumber = lua_tointeger(L, -1);
        }
        lua_pop(L, 1);
        if (lua_getfield(L, -1, "controllerValue") == LUA_TNUMBER) {
            controllerValue = lua_tointeger(L, -1);
        }
        lua_pop(L, 1);
        if (lua_getfield(L, -1, "programNumber") == LUA_TNUMBER) {
            programNumber = lua_tointeger(L, -1);
        }
        lua_pop(L, 1);
        if (lua_getfield(L, -1, "pitchChange") == LUA_TNUMBER) {
            pitchChange = lua_tointeger(L, -1);
        }
        lua_pop(L, 1);
        if (lua_getfield(L, -1, "fourteenBitValue") == LUA_TNUMBER) {
            fourteenBitValue = lua_tointeger(L, -1);
        }
        lua_pop(L, 1);
        if (lua_getfield(L, -1, "fourteenBitCommand") == LUA_TBOOLEAN) {
            fourteenBitCommand = lua_toboolean(L, -1);
        }
        lua_pop(L, 1);
    }

    //
    // Setup Device Manager:
    //
    HSMIDIDeviceManager *wrapper = [skin toNSObjectAtIndex:1] ;
    MIKMIDIDestinationEndpoint *destinationEndpoint;

    //
    // Setup Destination Endpoint:
    //
    if (wrapper.midiDevice.isVirtual == YES) {
        NSArray *virtualDestinations = [wrapper.midiDeviceManager virtualDestinations];
        for (MIKMIDIDestinationEndpoint * endpoint in virtualDestinations)
        {
            NSString *currentDevice = [endpoint name];
            if ([wrapper.midiDevice.name isEqualToString:currentDevice]) {
                destinationEndpoint = endpoint;
            }
        }
        if (!destinationEndpoint) {
            //
            // This shouldn't happen, but if it does, catch the error:
            //
            [skin logError:[NSString stringWithFormat:@"%s:callback error:%@", USERDATA_TAG, @"No MIDI Device Virtual Destinations detected."]] ;
            wrapper.callbackToken = nil;
            lua_pushvalue(L, 1);
            return 1;
        }
    }
    else {
        NSArray *destinations = [wrapper.midiDevice.entities valueForKeyPath:@"@unionOfArrays.destinations"];
        if (destinations.count == 0) {
            //
            // This shouldn't happen, but if it does, catch the error:
            //
            [skin logError:[NSString stringWithFormat:@"%s:callback error:%@", USERDATA_TAG, @"No MIDI Device Destinations detected."]] ;
            wrapper.callbackToken = nil;
            lua_pushvalue(L, 1);
            return 1;
        }
        destinationEndpoint = [destinations objectAtIndex:0];
    }

    //
    // Send Commands:
    //
    if ([commandType isEqualToString:@"noteOff"])
    {
        //      * note                - The note number for the command. Must be between 0 and 127.
        //      * velocity            - The velocity for the command. Must be between 0 and 127.
        //      * channel             - The channel for the command. Must be a number between 15.
        MIKMIDINoteOffCommand *noteOff = [MIKMIDINoteOffCommand noteOffCommandWithNote:note velocity:velocity channel:channel timestamp:date];
        if (![wrapper.midiDeviceManager sendCommands:@[noteOff] toEndpoint:destinationEndpoint error:&error])
        {
            [skin logError:[NSString stringWithFormat:@"%s: %@", USERDATA_TAG, error]];
            result = false;
        }
    }
    else if ([commandType isEqualToString:@"noteOn"])
    {
        //      * note                - The note number for the command. Must be between 0 and 127.
        //      * velocity            - The velocity for the command. Must be between 0 and 127.
        //      * channel             - The channel for the command. Must be a number between 15.
        MIKMIDINoteOnCommand *noteOn = [MIKMIDINoteOnCommand noteOnCommandWithNote:note velocity:velocity channel:channel timestamp:date];
        if (![wrapper.midiDeviceManager sendCommands:@[noteOn] toEndpoint:destinationEndpoint error:&error])
        {
            [skin logError:[NSString stringWithFormat:@"%s: %@", USERDATA_TAG, error]];
            result = false;
        }
    }
    else if ([commandType isEqualToString:@"polyphonicKeyPressure"])
    {
        //      * note                - The note number for the command. Must be between 0 and 127.
        //      * pressure            - Key pressure of the polyphonic key pressure message. In the range 0-127.
        //      * channel             - The channel for the command. Must be a number between 15.
        MIKMutableMIDIPolyphonicKeyPressureCommand *polyphonicKeyPressure = [[MIKMutableMIDIPolyphonicKeyPressureCommand alloc] init];
        polyphonicKeyPressure.note = note;
        polyphonicKeyPressure.pressure = pressure;
        if (![wrapper.midiDeviceManager sendCommands:@[polyphonicKeyPressure] toEndpoint:destinationEndpoint error:&error])
        {
            [skin logError:[NSString stringWithFormat:@"%s: %@", USERDATA_TAG, error]];
            result = false;
        }
    }
    else if ([commandType isEqualToString:@"controlChange"])
    {
        //      * controllerNumber    - The MIDI control number for the command.
        //      * controllerValue     - The controllerValue of the command. Only the lower 7-bits of this are used.
        //      * channel             - The channel for the command. Must be a number between 15.
        //      * fourteenBitValue    - The 14-bit value of the command. Must be between 0 and 16383. Defaults to 0.
        //      * fourteenBitCommand  - `true` if the command contains 14-bit value data otherwise, `false`.
        MIKMutableMIDIControlChangeCommand *controlChange = [[MIKMutableMIDIControlChangeCommand alloc] init];
        controlChange.controllerNumber = controllerNumber;
        controlChange.channel = channel;
        if (fourteenBitCommand) {
            controlChange.fourteenBitCommand = YES;
            controlChange.fourteenBitValue = fourteenBitValue;
        } else
        {
            controlChange.fourteenBitCommand = NO;
            controlChange.controllerValue = controllerValue;
        }
        if (![wrapper.midiDeviceManager sendCommands:@[controlChange] toEndpoint:destinationEndpoint error:&error])
        {
            [skin logError:[NSString stringWithFormat:@"%s: %@", USERDATA_TAG, error]];
            result = false;
        }
    }
    else if ([commandType isEqualToString:@"programChange"])
    {
        //      * programNumber       - The program (aka patch) number. From 0-127.
        //      * channel             - The channel for the command. Must be a number between 15.
        MIKMutableMIDIProgramChangeCommand *programChange = [[MIKMutableMIDIProgramChangeCommand alloc] init];
        programChange.programNumber = programNumber;
        programChange.channel = channel;
        if (![wrapper.midiDeviceManager sendCommands:@[programChange] toEndpoint:destinationEndpoint error:&error])
        {
            [skin logError:[NSString stringWithFormat:@"%s: %@", USERDATA_TAG, error]];
            result = false;
        }
    }
    else if ([commandType isEqualToString:@"channelPressure"])
    {
        //      * pressure            - Key pressure of the channel pressure message. In the range 0-127.
        //      * channel             - The channel for the command. Must be a number between 15.
        MIKMutableMIDIChannelPressureCommand *channelPressure = [[MIKMutableMIDIChannelPressureCommand alloc] init];
        channelPressure.pressure = pressure;
        channelPressure.channel = channel;
        if (![wrapper.midiDeviceManager sendCommands:@[channelPressure] toEndpoint:destinationEndpoint error:&error])
        {
            [skin logError:[NSString stringWithFormat:@"%s: %@", USERDATA_TAG, error]];
            result = false;
        }
    }
    else if ([commandType isEqualToString:@"pitchWheelChange"])
    {
        //      * pitchChange         -  A 14-bit value indicating the pitch bend. Center is 0x2000 (8192). Valid range is from 0-16383.
        //      * channel             - The channel for the command. Must be a number between 15.
        MIKMutableMIDIPitchBendChangeCommand *pitchWheelChange = [[MIKMutableMIDIPitchBendChangeCommand alloc] init];
        pitchWheelChange.pitchChange = pitchChange;
        pitchWheelChange.channel = channel;
        if (![wrapper.midiDeviceManager sendCommands:@[pitchWheelChange] toEndpoint:destinationEndpoint error:&error])
        {
            [skin logError:[NSString stringWithFormat:@"%s: %@", USERDATA_TAG, error]];
            result = false;
        }
    }
    else {
        [skin logError:[NSString stringWithFormat:@"%s: %@", USERDATA_TAG, @"Unrecognised commandType."]];
        result = false;
    }

    lua_pushboolean(L, result) ;
    return 1;
}

/// hs.midi:identityRequest() -> none
/// Method
/// Sends an Identity Request message to the `hs.midi` device. You can use `hs.midi:callback()` to receive the `systemExclusive` response.
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
///
/// Notes:
///  * Example Usage:
///   ```
///   midiDevice = hs.midi.new(hs.midi.devices()[3])
///   midiDevice:callback(function(object, deviceName, commandType, description, metadata)
///                         print("object: " .. tostring(object))
///                         print("deviceName: " .. deviceName)
///                         print("commandType: " .. commandType)
///                         print("description: " .. description)
///                         print("metadata: " .. hs.inspect(metadata))
///                       end)
///   midiDevice:identityRequest()
///   ```
static int midi_identityRequest(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSMIDIDeviceManager *wrapper = [skin toNSObjectAtIndex:1] ;
    MIKMIDISystemExclusiveCommand *identityRequest = [MIKMIDISystemExclusiveCommand identityRequestCommand];
    NSString *identityRequestString = [NSString stringWithFormat:@"%@", identityRequest.data];
    identityRequestString = [identityRequestString stringByReplacingOccurrencesOfString:@"<" withString:@""];
    identityRequestString = [identityRequestString stringByReplacingOccurrencesOfString:@">" withString:@""];
    [wrapper sendSysex:identityRequestString];
    return 0;
}

/// hs.midi:synthesize([value]) -> boolean
/// Method
/// Set or display whether or not the MIDI device should synthesize audio on your computer.
///
/// Parameters:
///  * [value] - `true` if you want to synthesize audio, otherwise `false`.
///
/// Returns:
///  * `true` if enabled otherwise `false`
static int midi_synthesize(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];

    HSMIDIDeviceManager *wrapper = [skin toNSObjectAtIndex:1] ;

    BOOL enabled = lua_toboolean(L, 2);
    if (enabled == 1) {
        [wrapper startSynthesize];
    }
    else
    {
        [wrapper stopSynthesize];
    }

    lua_pushboolean(L, enabled) ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSMIDIDeviceManager *wrapper = [skin toNSObjectAtIndex:1] ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSMIDIDeviceManager *wrapper = [skin toNSObjectAtIndex:1] ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSMIDIDeviceManager *wrapper = [skin toNSObjectAtIndex:1] ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSMIDIDeviceManager *wrapper = [skin toNSObjectAtIndex:1] ;
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
///  * `true` if online, otherwise `false`
static int midi_isOnline(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSMIDIDeviceManager *wrapper = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, [wrapper.midiDevice isOnline]);
    return 1;
}

/// hs.midi:isVirtual() -> boolean
/// Method
/// Returns `true` if an `hs.midi` object is virtual, otherwise `false`.
///
/// Parameters:
///  * None
///
/// Returns:
///  * `true` if virtual, otherwise `false`
static int midi_isVirtual(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSMIDIDeviceManager *wrapper = [skin toNSObjectAtIndex:1] ;
    lua_pushboolean(L, [wrapper.midiDevice isVirtual]);
    return 1;
}

#pragma mark - Module Constants

/// hs.midi.commandTypes[]
/// Constant
/// A table containing the numeric value for the possible flags returned by the `commandType` parameter of the callback function.
///
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
static int pushHSMIDIDeviceManager(lua_State *L, id obj) {
    HSMIDIDeviceManager *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSMIDIDeviceManager *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSMIDIDeviceManagerFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSMIDIDeviceManager *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSMIDIDeviceManager, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                        lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSMIDIDeviceManager *obj = [skin luaObjectAtIndex:1 toClass:"HSMIDIDeviceManager"] ;
    NSString *title = obj.midiDevice.displayName ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
    //
    // Can't get here if at least one of us isn't a userdata type, and we only care if both types are ours, so use luaL_testudata before the macro causes a Lua error:
    //
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSMIDIDeviceManager *obj1 = [skin luaObjectAtIndex:1 toClass:"HSMIDIDeviceManager"] ;
        HSMIDIDeviceManager *obj2 = [skin luaObjectAtIndex:2 toClass:"HSMIDIDeviceManager"] ;
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
    HSMIDIDeviceManager *obj = get_objectFromUserdata(__bridge_transfer HSMIDIDeviceManager, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj.selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            LuaSkin *skin = [LuaSkin sharedWithState:L] ;
            obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;

            //
            // Disconnect Callback:
            //
            if (obj.callbackToken != nil) {
                [obj.midiDeviceManager disconnectConnectionForToken:obj.callbackToken];
                obj.callbackToken = nil;
            }

            //
            // Stop Synthesis:
            //
            [obj stopSynthesize];

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
static int meta_gc(lua_State* L) {
    if (watcherDeviceManager) {
        watcherDeviceManager.deviceCallbackRef = [[LuaSkin sharedWithState:L] luaUnref:refTable ref:watcherDeviceManager.deviceCallbackRef] ;
        [watcherDeviceManager unwatchDevices] ;
        watcherDeviceManager = nil ;
    }
    return 0 ;
}

//
// Metatable for userdata objects:
//
static const luaL_Reg userdata_metaLib[] = {
    {"synthesize", midi_synthesize},
    {"sendCommand", midi_sendCommand},
    {"sendSysex", midi_sendSysex},
    {"identityRequest", midi_identityRequest},
    {"name", midi_name},
    {"displayName", midi_displayName},
    {"isOnline", midi_isOnline},
    {"isVirtual", midi_isVirtual},
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
    {"newVirtualSource", midi_newVirtualSource},
    {"devices", devices},
    {"virtualSources", virtualSources},
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
int luaopen_hs_midi_internal(lua_State* L) {

    //
    // Register Module:
    //
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:module_metaLib
                               objectFunctions:userdata_metaLib];

    //
    // Register MIDI Device:
    //
    [skin registerPushNSHelper:pushHSMIDIDeviceManager         forClass:"HSMIDIDeviceManager"];
    [skin registerLuaObjectHelper:toHSMIDIDeviceManagerFromLua forClass:"HSMIDIDeviceManager"
              withUserdataMapping:USERDATA_TAG];

    // Push Constants:
    pushCommandTypes(L) ; lua_setfield(L, -2, "commandTypes") ;
    return 1;
}
