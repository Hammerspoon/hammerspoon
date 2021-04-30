@import Cocoa;
@import Carbon;
@import CoreAudio;
@import AudioToolbox;
@import Foundation;
@import Darwin.C.math;
#import <LuaSkin/LuaSkin.h>

#pragma mark - Library defines

static const char *USERDATA_TAG            = "hs.audiodevice";
static const char *USERDATA_DATASOURCE_TAG = "hs.audiodevice.datasource";

#define userdataToAudioDevice(L, idx) ((audioDeviceUserData*)luaL_checkudata(L, idx, USERDATA_TAG))
#define userdataToDataSource(L, idx) ((dataSourceUserData*)luaL_checkudata(L, idx, USERDATA_DATASOURCE_TAG))

// Define a datatype for hs.audiodevice objects
typedef struct _audioDeviceUserData {
    AudioDeviceID deviceId;
    int callback;
    BOOL watcherRunning;
    LSGCCanary lsCanary;
} audioDeviceUserData;

// Define a datatype for hs.audiodevice.datasource objects
typedef struct _dataSourceUserData {
    AudioDeviceID hostDevice;
    UInt32 dataSource;
} dataSourceUserData;

static const AudioObjectPropertySelector watchSelectors[] = {
    kAudioDevicePropertyMute,
    kAudioDevicePropertyJackIsConnected,
    kAudioDevicePropertyDeviceHasChanged,
    kAudioDevicePropertyStereoPan,
    kAudioHardwareServiceDeviceProperty_VirtualMasterVolume
};

static LSRefTable refTable;

#pragma mark - Function definitions

static int audiodevice_watcherSetCallback(lua_State *L);
static int audiodevice_watcherStart(lua_State *L);
static int audiodevice_watcherStop(lua_State *L);
void watcherStop(audioDeviceUserData *audioDevice);

#pragma mark - CoreAudio helper functions

OSStatus audiodevice_callback(AudioDeviceID deviceID, UInt32 numAddresses, const AudioObjectPropertyAddress addressList[], void *clientData) {
    // Get the UID of the device, to pass into the callback
    NSString *deviceUIDNS = nil;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyDeviceUID,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };
    CFStringRef deviceUID;
    UInt32 propertySize = sizeof(CFStringRef);

    OSStatus result;

    result = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, NULL, &propertySize, &deviceUID);
    if (result == noErr) {
        deviceUIDNS = (__bridge NSString *)deviceUID;
    }

    //NSLog(@"Found UID: %@", deviceUIDNS);

    NSMutableArray *events = [[NSMutableArray alloc] init];

    for (UInt32 i = 0; i < numAddresses; i++) {
        NSString *mSelector = (__bridge_transfer NSString *)UTCreateStringForOSType(addressList[i].mSelector);
        NSString *mScope = (__bridge_transfer NSString *)UTCreateStringForOSType(addressList[i].mScope);
        NSNumber *mElement = [NSNumber numberWithInt:addressList[i].mElement];
        [events addObject:@{@"mSelector":mSelector, @"mScope":mScope, @"mElement":mElement}];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        //NSLog(@"audiodevice_callback called with %i addresses", numAddresses);

        audioDeviceUserData *userData = (audioDeviceUserData *)clientData;
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        if (![skin checkGCCanary:userData->lsCanary]) {
            return;
        }

        _lua_stackguard_entry(skin.L);
        if (userData->callback == LUA_NOREF) {
            [skin logError:@"hs.audiodevice.watcher callback fired, but no function has been set with hs.audiodevice.watcher.setCallback()"];
        } else {
            for (NSDictionary *event in events) {
                [skin pushLuaRef:refTable ref:userData->callback];

                if (deviceUIDNS) {
                    lua_pushstring(skin.L, deviceUIDNS.UTF8String);
                } else {
                    lua_pushnil(skin.L);
                }

                [skin pushNSObject:event[@"mSelector"]];
                [skin pushNSObject:event[@"mScope"]];
                [skin pushNSObject:event[@"mElement"]];

                [skin protectedCallAndError:@"hs.audiodevice:watcherCallback" nargs:4 nresults:0];
            }
        }
        _lua_stackguard_exit(skin.L);
    });
    return noErr;
}


#pragma mark - Helper functions to identify the type of device
static bool _check_audio_device_has_streams(AudioDeviceID deviceId, AudioObjectPropertyScope scope) {
    UInt32 dataSize = 0;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyStreams,
        scope,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectGetPropertyDataSize(deviceId, &propertyAddress, 0, NULL, &dataSize) == noErr) {
        return (dataSize / sizeof(AudioStreamID)) > 0;
    } else {
        return true;
    }
}

static bool isOutputDevice(AudioDeviceID deviceID) {
    return _check_audio_device_has_streams(deviceID, kAudioObjectPropertyScopeOutput);
}

static bool isInputDevice(AudioDeviceID deviceID) {
    return _check_audio_device_has_streams(deviceID, kAudioObjectPropertyScopeInput);
}

#pragma mark - Helper functions for creating userdata objects
void new_device(lua_State* L, AudioDeviceID deviceId) {
    audioDeviceUserData *audioDevice = (audioDeviceUserData *)lua_newuserdata(L, sizeof(audioDeviceUserData));
    audioDevice->deviceId = deviceId;
    audioDevice->callback = LUA_NOREF;
    audioDevice->watcherRunning = NO;

    LuaSkin *skin = [LuaSkin sharedWithState:L];
    audioDevice->lsCanary = [skin createGCCanary];

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
}

void new_dataSource(lua_State *L, AudioDeviceID deviceID, UInt32 dataSource) {
    dataSourceUserData *userData = (dataSourceUserData *)lua_newuserdata(L, sizeof(dataSourceUserData));
    userData->dataSource = dataSource;
    userData->hostDevice = deviceID;

    luaL_getmetatable(L, USERDATA_DATASOURCE_TAG);
    lua_setmetatable(L, -2);
}

#pragma mark - hs.audiodevice library functions

/// hs.audiodevice.allDevices() -> hs.audiodevice[]
/// Function
/// Returns a list of all connected devices
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table of zero or more audio devices connected to the system
static int audiodevice_alldevices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeWildcard,
        kAudioObjectPropertyElementWildcard
    };
    AudioDeviceID *deviceList = NULL;
    UInt32 deviceListPropertySize = 0;
    UInt32 numDevices = 0;
    UInt32 tableIndex = 1;
    UInt32 i;

    if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &deviceListPropertySize) != noErr)
        goto error;

    numDevices = deviceListPropertySize / sizeof(AudioDeviceID);
    deviceList = (AudioDeviceID*) calloc(numDevices, sizeof(AudioDeviceID));

    if (!deviceList)
        goto error;

    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &deviceListPropertySize, deviceList) != noErr)
        goto error;

    lua_newtable(L);

    for(i = 0; i < numDevices; i++) {
        AudioDeviceID deviceId = deviceList[i];
        lua_pushinteger(L, tableIndex++);
        new_device(L, deviceId);
        lua_settable(L, -3);
    }

    // 10.11 stopped including AirPlay in the audio device enumeration output, but there is a way to still get a device ID for it, however, it appears to be completely useless, so this code is disabled.
/*
    if ([processInfo respondsToSelector:@selector(isOperatingSystemAtLeastVersion:)]) {
        NSOperatingSystemVersion minVersion = {10, 11, 0};
        if ([processInfo isOperatingSystemAtLeastVersion:minVersion]) {
            AudioDeviceID airplayDeviceId;
            CFStringRef airplayDeviceUID = CFSTR("AirPlay");
            UInt32 dataSize = 0;
            AudioObjectPropertyAddress propertyAddress = {
                kAudioHardwarePropertyTranslateUIDToDevice,
                kAudioObjectPropertyScopeGlobal,
                kAudioObjectPropertyElementMaster
            };

            if ((AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &propertyAddress, sizeof(CFStringRef), &airplayDeviceUID, &dataSize) == noErr) && \
                (AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, sizeof(CFStringRef), &airplayDeviceUID, &dataSize, &airplayDeviceId) == noErr)) {
                    lua_pushinteger(L, tableIndex++);
                    new_device(L, airplayDeviceId);
                    lua_settable(L, -3);
            }
        }
    }
*/

    goto end;

error:
    lua_pushnil(L);

end:
    free(deviceList);

    return 1;
}

/// hs.audiodevice.defaultOutputDevice() -> audio or nil
/// Function
/// Get the currently selected audio output device
///
/// Parameters:
///  * None
///
/// Returns:
///  * An hs.audiodevice object, or nil if no suitable device could be found
static int audiodevice_defaultoutputdevice(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };

    AudioDeviceID deviceId;
    UInt32 deviceIdSize = sizeof(AudioDeviceID);

    if ((AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &deviceIdSize, &deviceId) == noErr) && isOutputDevice(deviceId)) {
        new_device(L, deviceId);
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.audiodevice.defaultInputDevice() -> audio or nil
/// Function
/// Get the currently selected audio input device
///
/// Parameters:
///  * None
///
/// Returns:
///  * An hs.audiodevice object, or nil if no suitable device could be found
static int audiodevice_defaultinputdevice(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwarePropertyDefaultInputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };

    AudioDeviceID deviceId;
    UInt32 deviceIdSize = sizeof(AudioDeviceID);

    if ((AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &deviceIdSize, &deviceId) == noErr) && isInputDevice(deviceId)) {
        new_device(L, deviceId);
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.audiodevice.defaultEffectDevice() -> audio or nil
/// Function
/// Get the currently selected sound effect device
///
/// Parameters:
///  * None
///
/// Returns:
///  * An hs.audiodevice object, or nil if no suitable device could be found
static int audiodevice_defaulteffectdevice(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwarePropertyDefaultSystemOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };

    AudioDeviceID deviceId;
    UInt32 deviceIdSize = sizeof(AudioDeviceID);

    if ((AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &deviceIdSize, &deviceId) == noErr) && isOutputDevice(deviceId)) {
        new_device(L, deviceId);
    } else {
        lua_pushnil(L);
    }

    return 1;
}


#pragma mark - hs.audiodevice object methods

/// hs.audiodevice:setDefaultOutputDevice() -> bool
/// Method
/// Selects this device as the system's audio output device
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the audio device was successfully selected, otherwise false.
static int audiodevice_setdefaultoutputdevice(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };

    UInt32 deviceIdSize = sizeof(AudioDeviceID);

    if (isOutputDevice(deviceId) && (AudioObjectSetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, deviceIdSize, &deviceId) == noErr)) {
        lua_pushboolean(L, TRUE);
    } else {
        lua_pushboolean(L, FALSE);
    }

    return 1;
}

/// hs.audiodevice:setDefaultEffectDevice() -> bool
/// Method
/// Selects this device as the audio output device for system sound effects
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the audio device was successfully selected, otherwise false.
static int audiodevice_setdefaulteffectdevice(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwarePropertyDefaultSystemOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };

    UInt32 deviceIdSize = sizeof(AudioDeviceID);

    if (isOutputDevice(deviceId) && (AudioObjectSetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, deviceIdSize, &deviceId) == noErr)) {
        lua_pushboolean(L, TRUE);
    } else {
        lua_pushboolean(L, FALSE);
    }

    return 1;
}

/// hs.audiodevice:setDefaultInputDevice() -> bool
/// Method
/// Selects this device as the system's audio input device
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the audio device was successfully selected, otherwise false.
static int audiodevice_setdefaultinputdevice(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwarePropertyDefaultInputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };

    UInt32 deviceIdSize = sizeof(AudioDeviceID);

    if (isInputDevice(deviceId) && (AudioObjectSetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, deviceIdSize, &deviceId) == noErr)) {
        lua_pushboolean(L, TRUE);
    } else {
        lua_pushboolean(L, FALSE);
    }

    return 1;
}

/// hs.audiodevice:name() -> string or nil
/// Method
/// Get the name of the audio device
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the name of the audio device, or nil if it has no name
static int audiodevice_name(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioObjectPropertyName,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };
    CFStringRef deviceName;
    UInt32 propertySize = sizeof(CFStringRef);

    if (AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &propertySize, &deviceName) == noErr) {
        NSString *deviceNameNS = (__bridge_transfer NSString *)deviceName;
        lua_pushstring(L, deviceNameNS.UTF8String);
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.audiodevice:uid() -> string or nil
/// Method
/// Get the unique identifier of the audio device
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the UID of the audio device, or nil if it has no UID.
static int audiodevice_uid(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyDeviceUID,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };
    CFStringRef deviceUID;
    UInt32 propertySize = sizeof(CFStringRef);

    OSStatus result;

    result = AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &propertySize, &deviceUID);
    if (result != noErr) {
        lua_pushnil(L);
        return 1;
    }

    NSString *deviceUIDNS = (__bridge NSString *)deviceUID;
    lua_pushstring(L, deviceUIDNS.UTF8String);

    CFRelease(deviceUID);
    return 1;
}

/// hs.audiodevice:inputMuted() -> bool or nil
/// Method
/// Get the Input mutedness state of the audio device
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the audio device's Input is muted. False if it's not muted, nil if it does not support muting
static int audiodevice_inputMuted(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    unsigned int scope;
    UInt32 muted;
    UInt32 mutedSize = sizeof(UInt32);

    scope = kAudioObjectPropertyScopeInput;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyMute,
        scope,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectHasProperty(deviceId, &propertyAddress) && (AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &mutedSize, &muted) == noErr)) {
        lua_pushboolean(L, muted != 0);
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.audiodevice:outputMuted() -> bool or nil
/// Method
/// Get the Output mutedness state of the audio device
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the audio device's Output is muted. False if it's not muted, nil if it does not support muting
static int audiodevice_outputMuted(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    unsigned int scope;
    UInt32 muted;
    UInt32 mutedSize = sizeof(UInt32);

    scope = kAudioObjectPropertyScopeOutput;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyMute,
        scope,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectHasProperty(deviceId, &propertyAddress) && (AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &mutedSize, &muted) == noErr)) {
        lua_pushboolean(L, muted != 0);
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.audiodevice:muted() -> bool or nil
/// Method
/// Get the mutedness state of the audio device
///
/// Parameters:
///  * None
///
/// Returns:
///  * True if the audio device is muted, False if it is not muted, nil if it does not support muting
///
/// Notes:
///  * If a device is capable of both input and output, this method will prefer the output. See `:inputMuted()` and `:outputMuted()` for specific variants.
static int audiodevice_muted(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    unsigned int scope;
    UInt32 muted;
    UInt32 mutedSize = sizeof(UInt32);

    if (isOutputDevice(deviceId)) {
        scope = kAudioObjectPropertyScopeOutput;
    } else {
        scope = kAudioObjectPropertyScopeInput;
    }

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyMute,
        scope,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectHasProperty(deviceId, &propertyAddress) && (AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &mutedSize, &muted) == noErr)) {
        lua_pushboolean(L, muted != 0);
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.audiodevice:setInputMuted(state) -> bool
/// Method
/// Set the mutedness state of the Input of the audio device
///
/// Parameters:
///  * state - A boolean value. True to mute the device, False to unmute it
///
/// Returns:
///  * True if the device's Input mutedness state was set, or False if it does not support muting
static int audiodevice_setInputMuted(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    unsigned int scope;
    UInt32 muted = lua_toboolean(L, 2);
    UInt32 mutedSize = sizeof(UInt32);

    scope = kAudioObjectPropertyScopeInput;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyMute,
        scope,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectHasProperty(deviceId, &propertyAddress) && (AudioObjectSetPropertyData(deviceId, &propertyAddress, 0, NULL, mutedSize, &muted) == noErr)) {
        lua_pushboolean(L, TRUE);
    } else {
        lua_pushboolean(L, FALSE);
    }

    return 1;
}

/// hs.audiodevice:setOutputMuted(state) -> bool
/// Method
/// Set the mutedness state of the Output of the audio device
///
/// Parameters:
///  * state - A boolean value. True to mute the device, False to unmute it
///
/// Returns:
///  * True if the device's Output mutedness state was set, or False if it does not support muting
static int audiodevice_setOutputMuted(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    unsigned int scope;
    UInt32 muted = lua_toboolean(L, 2);
    UInt32 mutedSize = sizeof(UInt32);

    scope = kAudioObjectPropertyScopeOutput;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyMute,
        scope,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectHasProperty(deviceId, &propertyAddress) && (AudioObjectSetPropertyData(deviceId, &propertyAddress, 0, NULL, mutedSize, &muted) == noErr)) {
        lua_pushboolean(L, TRUE);
    } else {
        lua_pushboolean(L, FALSE);
    }

    return 1;
}


/// hs.audiodevice:setMuted(state) -> bool
/// Method
/// Set the mutedness state of the audio device
///
/// Parameters:
///  * state - A boolean value. True to mute the device, False to unmute it
///
/// Returns:
///  * True if the device's mutedness state was set, or False if it does not support muting
///
/// Notes:
///  * If a device is capable of both input and output, this method will prefer the output. See `:inputSetMuted()` and `:outputSetMuted()` for specific variants.
static int audiodevice_setmuted(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    unsigned int scope;
    UInt32 muted = lua_toboolean(L, 2);
    UInt32 mutedSize = sizeof(UInt32);

    if (isOutputDevice(deviceId)) {
        scope = kAudioObjectPropertyScopeOutput;
    } else {
        scope = kAudioObjectPropertyScopeInput;
    }

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyMute,
        scope,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectHasProperty(deviceId, &propertyAddress) && (AudioObjectSetPropertyData(deviceId, &propertyAddress, 0, NULL, mutedSize, &muted) == noErr)) {
        lua_pushboolean(L, TRUE);
    } else {
        lua_pushboolean(L, FALSE);
    }

    return 1;
}

/// hs.audiodevice:inputVolume() -> number or nil
/// Method
/// Get the current input volume of this audio device
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number between 0 and 100, representing the input volume percentage, or nil if the audio device does not support input volume levels
///
/// Notes:
///  * The return value will be a floating point number
static int audiodevice_inputVolume(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    Float32 volume;
    UInt32 volumeSize = sizeof(Float32);

    if (!isInputDevice(deviceId)) {
        lua_pushnil(L);
        return 1;
    }

    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
        kAudioObjectPropertyScopeInput,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectHasProperty(deviceId, &propertyAddress) && (AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &volumeSize, &volume) == noErr)) {
        lua_pushnumber(L, (lua_Number)(volume * 100.0f));
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.audiodevice:outputVolume() -> number or nil
/// Method
/// Get the current output volume of this audio device
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number between 0 and 100, representing the output volume percentage, or nil if the audio device does not support output volume levels
///
/// Notes:
///  * The return value will be a floating point number
static int audiodevice_outputVolume(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    Float32 volume;
    UInt32 volumeSize = sizeof(Float32);

    if (!isOutputDevice(deviceId)) {
        lua_pushnil(L);
        return 1;
    }

    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
        kAudioObjectPropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectHasProperty(deviceId, &propertyAddress) && (AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &volumeSize, &volume) == noErr)) {
        lua_pushnumber(L, (lua_Number)(volume * 100.0f));
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.audiodevice:volume() -> number or nil
/// Method
/// Get the current volume of this audio device
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number between 0 and 100, representing the volume percentage, or nil if the audio device does not support volume levels
///
/// Notes:
///  * The return value will be a floating point number
///  * This method will inspect the device to determine if it is an input or output device, and return the appropriate volume. For devices that are both input and output devices, see `:inputVolume()` and `:outputVolume()`
static int audiodevice_volume(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    unsigned int scope;
    Float32 volume;
    UInt32 volumeSize = sizeof(Float32);

    if (isOutputDevice(deviceId)) {
        scope = kAudioObjectPropertyScopeOutput;
    } else {
        scope = kAudioObjectPropertyScopeInput;
    }

    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
        scope,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectHasProperty(deviceId, &propertyAddress) && (AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &volumeSize, &volume) == noErr)) {
        lua_pushnumber(L, (lua_Number)(volume * 100.0f));
    } else {
        lua_pushnil(L);
    }

    return 1;

}

/// hs.audiodevice:setInputVolume(level) -> bool
/// Method
/// Set the input volume of this audio device
///
/// Parameters:
///  * level - A number between 0 and 100, representing the input volume as a percentage
///
/// Returns:
///  * True if the volume was set, false if the audio device does not support setting an input volume level
///
/// Notes:
///  * The volume level is a floating point number. Depending on your audio hardware, it may not be possible to increase volume in single digit increments
static int audiodevice_setInputVolume(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    Float32 value = (Float32)lua_tonumber(L, 2);

    if (value < 0) {
        value = 0;
    }

    if (value > 100) {
        value = 100;
    }

    Float32 volume = (Float32)value / 100.0f;
    UInt32 volumeSize = sizeof(Float32);

    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
        kAudioObjectPropertyScopeInput,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectHasProperty(deviceId, &propertyAddress) && (AudioObjectSetPropertyData(deviceId, &propertyAddress, 0, NULL, volumeSize, &volume) == noErr)) {
        lua_pushboolean(L, TRUE);
    } else {
        lua_pushboolean(L, FALSE);
    }

    return 1;
}

/// hs.audiodevice:setOutputVolume(level) -> bool
/// Method
/// Set the output volume of this audio device
///
/// Parameters:
///  * level - A number between 0 and 100, representing the output volume as a percentage
///
/// Returns:
///  * True if the volume was set, false if the audio device does not support setting an output volume level
///
/// Notes:
///  * The volume level is a floating point number. Depending on your audio hardware, it may not be possible to increase volume in single digit increments
static int audiodevice_setOutputVolume(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    Float32 value = (Float32)lua_tonumber(L, 2);

    if (value < 0) {
        value = 0;
    }

    if (value > 100) {
        value = 100;
    }

    Float32 volume = (Float32)value / 100.0f;
    UInt32 volumeSize = sizeof(Float32);

    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
        kAudioObjectPropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectHasProperty(deviceId, &propertyAddress) && (AudioObjectSetPropertyData(deviceId, &propertyAddress, 0, NULL, volumeSize, &volume) == noErr)) {
        lua_pushboolean(L, TRUE);
    } else {
        lua_pushboolean(L, FALSE);
    }

    return 1;
}

/// hs.audiodevice:setVolume(level) -> bool
/// Method
/// Set the volume of this audio device
///
/// Parameters:
///  * level - A number between 0 and 100, representing the volume as a percentage
///
/// Returns:
///  * True if the volume was set, false if the audio device does not support setting a volume level.
///
/// Notes:
///  * The volume level is a floating point number. Depending on your audio hardware, it may not be possible to increase volume in single digit increments.
///  * This method will inspect the device to determine if it is an input or output device, and set the appropriate volume. For devices that are both input and output devices, see `:setInputVolume()` and `:setOutputVolume()`
static int audiodevice_setvolume(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    unsigned int scope;
    Float32 value = (Float32)lua_tonumber(L, 2);

    if (value < 0) {
        value = 0;
    }
    if (value > 100) {
        value = 100;
    }

    Float32 volume = (Float32)value / 100.0f;
    UInt32 volumeSize = sizeof(Float32);

    if (isOutputDevice(deviceId)) {
        scope = kAudioObjectPropertyScopeOutput;
    } else {
        scope = kAudioObjectPropertyScopeInput;
    }

    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
        scope,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectHasProperty(deviceId, &propertyAddress) && (AudioObjectSetPropertyData(deviceId, &propertyAddress, 0, NULL, volumeSize, &volume) == noErr)) {
        lua_pushboolean(L, TRUE);
    } else {
        lua_pushboolean(L, FALSE);
    }

    return 1;

}

/// hs.audiodevice:balance() -> number or nil
/// Method
/// Get the current left/right balance of this audio device
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number between 0.0 and 1.0, representing the balance (0.0 for full left, 1.0 for full right, 0.5 for center), or nil if the audio device does not support balance
///
/// Notes:
///  * The return value will be a floating point number
///  * This method will inspect the device to determine if it is an input or output device, and return the appropriate volume. For devices that are both input and output devices, see `:inputVolume()` and `:outputVolume()`
static int audiodevice_balance(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    unsigned int scope;
    Float32 balance;
    UInt32 balanceSize = sizeof(Float32);

    if (isOutputDevice(deviceId)) {
        scope = kAudioObjectPropertyScopeOutput;
    } else {
        scope = kAudioObjectPropertyScopeInput;
    }

    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwareServiceDeviceProperty_VirtualMasterBalance,
        scope,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectHasProperty(deviceId, &propertyAddress) && (AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &balanceSize, &balance) == noErr)) {
        lua_pushnumber(L, (lua_Number)balance);
    } else {
        lua_pushnil(L);
    }

    return 1;

}

/// hs.audiodevice:setBalance(level) -> bool
/// Method
/// Set the balance of this audio device
///
/// Parameters:
///  * level - A number between 0.0 and 1.0, representing the balance (0.0 for full left, 1.0 for full right, 0.5 for center)
///
/// Returns:
///  * True if the balance was set, false if the audio device does not support setting a balance.
///
/// Notes:
///  * This method will inspect the device to determine if it is an input or output device, and set the appropriate volume. For devices that are both input and output devices, see `:setInputVolume()` and `:setOutputVolume()`
static int audiodevice_setbalance(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    unsigned int scope;
    Float32 value = (Float32)lua_tonumber(L, 2);

    if (value < 0) {
        value = 0;
    }
    if (value > 1) {
        value = 1;
    }

    Float32 balance = value;
    UInt32 balanceSize = sizeof(Float32);

    if (isOutputDevice(deviceId)) {
        scope = kAudioObjectPropertyScopeOutput;
    } else {
        scope = kAudioObjectPropertyScopeInput;
    }

    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwareServiceDeviceProperty_VirtualMasterBalance,
        scope,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectHasProperty(deviceId, &propertyAddress) && (AudioObjectSetPropertyData(deviceId, &propertyAddress, 0, NULL, balanceSize, &balance) == noErr)) {
        lua_pushboolean(L, TRUE);
    } else {
        lua_pushboolean(L, FALSE);
    }

    return 1;

}

/// hs.audiodevice:isOutputDevice() -> boolean
/// Method
/// Determins if an audio device is an output device
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if the device is an output device, false if not
static int audiodevice_isOutputDevice(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    lua_pushboolean(L, isOutputDevice(deviceId));

    return 1;
}

/// hs.audiodevice:isInputDevice() -> boolean
/// Method
/// Determins if an audio device is an input device
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if the device is an input device, false if not
static int audiodevice_isInputDevice(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    lua_pushboolean(L, isInputDevice(deviceId));

    return 1;
}

/// hs.audiodevice:transportType() -> string
/// Method
/// Gets the hardware transport type of an audio device
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the transport type, or nil if an error occurred
static int audiodevice_transportType(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    UInt32 transportType;
    UInt32 transportTypeSize = sizeof(UInt32);
    char *transportTypeName;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyTransportType,
        kAudioObjectPropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectHasProperty(deviceId, &propertyAddress) && (AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &transportTypeSize, &transportType) == noErr)) {
        switch (transportType) {
            case kAudioDeviceTransportTypeBuiltIn:
                transportTypeName = "Built-in";
                break;
            case kAudioDeviceTransportTypeAggregate:
                transportTypeName = "Aggregate";
                break;
            case kAudioDeviceTransportTypeAutoAggregate:
                transportTypeName = "Auto Aggregate";
                break;
            case kAudioDeviceTransportTypeVirtual:
                transportTypeName = "Virtual";
                break;
            case kAudioDeviceTransportTypePCI:
                transportTypeName = "PCI";
                break;
            case kAudioDeviceTransportTypeUSB:
                transportTypeName = "USB";
                break;
            case kAudioDeviceTransportTypeFireWire:
                transportTypeName = "FireWire";
                break;
            case kAudioDeviceTransportTypeBluetooth:
                transportTypeName = "Bluetooth";
                break;
            case kAudioDeviceTransportTypeHDMI:
                transportTypeName = "HDMI";
                break;
            case kAudioDeviceTransportTypeDisplayPort:
                transportTypeName = "DisplayPort";
                break;
            case kAudioDeviceTransportTypeAirPlay:
                transportTypeName = "AirPlay";
                break;
            case kAudioDeviceTransportTypeAVB:
                transportTypeName = "AVB";
                break;
            case kAudioDeviceTransportTypeThunderbolt:
                transportTypeName = "Thunderbolt";
                break;
            case kAudioDeviceTransportTypeUnknown:
            default:
                transportTypeName = "UNKNOWN";
                break;
        }
        lua_pushstring(L, transportTypeName);
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.audiodevice:jackConnected() -> boolean or nil
/// Method
/// Determines whether an audio jack (e.g. headphones) is connected to an audio device
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if a jack is connected, false if not, or nil if the device does not support jack sense
static int audiodevice_jackConnected(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    UInt32 jackConnected;
    UInt32 jackConnectedSize = sizeof(UInt32);
    AudioObjectPropertyScope scope = isOutputDevice(deviceId) ? kAudioObjectPropertyScopeOutput : kAudioObjectPropertyScopeInput;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyJackIsConnected,
        scope,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &jackConnectedSize, &jackConnected) != noErr) {
        lua_pushnil(L);
    } else {
        lua_pushboolean(L, (jackConnected != 0));
    }

    return 1;
}

/// hs.audiodevice:supportsInputDataSources() -> boolean
/// Method
/// Determines whether an audio device supports input data sources
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if the device supports input data sources, false if not
static int audiodevice_supportsInputDataSources(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyDataSources,
        kAudioObjectPropertyScopeInput,
        kAudioObjectPropertyElementMaster
    };

    lua_pushboolean(L, AudioObjectHasProperty(deviceId, &propertyAddress) ? true : false);

    return 1;
}

/// hs.audiodevice:supportsOutputDataSources() -> boolean
/// Method
/// Determines whether an audio device supports output data sources
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if the device supports output data sources, false if not
static int audiodevice_supportsOutputDataSources(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyDataSources,
        kAudioObjectPropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };

    lua_pushboolean(L, AudioObjectHasProperty(deviceId, &propertyAddress) ? true : false);

    return 1;
}

/// hs.audiodevice:currentInputDataSource() -> hs.audiodevice.dataSource object or nil
/// Method
/// Gets the current input data source of an audio device
///
/// Parameters:
///  * None
///
/// Returns:
///  * An hs.audiodevice.dataSource object, or nil if an error occurred
///
/// Notes:
///  * Before calling this method, you should check the result of hs.audiodevice:supportsInputDataSources()
static int audiodevice_currentInputDataSource(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyDataSource,
        kAudioObjectPropertyScopeInput,
        kAudioObjectPropertyElementMaster
    };

    UInt32 dataSourceId = 0;
    UInt32 dataSourceIdSize = sizeof(UInt32);

    if (AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &dataSourceIdSize, &dataSourceId) == noErr) {
        new_dataSource(L, deviceId, dataSourceId);
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.audiodevice:currentOutputDataSource() -> hs.audiodevice.dataSource object or nil
/// Method
/// Gets the current output data source of an audio device
///
/// Parameters:
///  * None
///
/// Returns:
///  * An hs.audiodevice.dataSource object, or nil if an error occurred
///
/// Notes:
///  * Before calling this method, you should check the result of hs.audiodevice:supportsOutputDataSources()
static int audiodevice_currentOutputDataSource(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyDataSource,
        kAudioObjectPropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };

    UInt32 dataSourceId = 0;
    UInt32 dataSourceIdSize = sizeof(UInt32);

    if (AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &dataSourceIdSize, &dataSourceId) == noErr) {
        new_dataSource(L, deviceId, dataSourceId);
    } else {
        lua_pushnil(L);
    }

    return 1;
}

/// hs.audiodevice:allOutputDataSources() -> hs.audiodevice.dataSource[] or nil
/// Method
/// Gets all of the output data sources of an audio device
///
/// Parameters:
///  * None
///
/// Returns:
///  * A list of hs.audiodevice.dataSource objects, or nil if an error occurred
static int audiodevice_allOutputDataSources(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    UInt32 datasourceListPropertySize = 0;
    UInt32 *datasourceList = NULL;
    UInt32 i;
    UInt32 tableIndex = 1;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyDataSources,
        kAudioObjectPropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectGetPropertyDataSize(deviceId, &propertyAddress, 0, NULL, &datasourceListPropertySize) != noErr)
        goto error;

    datasourceList = calloc(datasourceListPropertySize, sizeof(UInt32));

    if (AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &datasourceListPropertySize, datasourceList) != noErr)
        goto error;

    lua_newtable(L);

    for(i = 0; i < datasourceListPropertySize; i++) {
        lua_pushinteger(L, tableIndex++);
        new_dataSource(L, deviceId, datasourceList[i]);
        lua_settable(L, -3);
    }

    goto end;

error:
    lua_pushnil(L);

end:
    free(datasourceList);

    return 1;
}

/// hs.audiodevice:allInputDataSources() -> hs.audiodevice.dataSource[] or nil
/// Method
/// Gets all of the input data sources of an audio device
///
/// Parameters:
///  * None
///
/// Returns:
///  * A list of hs.audiodevice.dataSource objects, or nil if an error occurred
static int audiodevice_allInputDataSources(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    UInt32 datasourceListPropertySize = 0;
    UInt32 *datasourceList = NULL;
    UInt32 i;
    UInt32 tableIndex = 1;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyDataSources,
        kAudioObjectPropertyScopeInput,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectGetPropertyDataSize(deviceId, &propertyAddress, 0, NULL, &datasourceListPropertySize) != noErr)
        goto error;

    datasourceList = calloc(datasourceListPropertySize, sizeof(UInt32));

    if (AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &datasourceListPropertySize, datasourceList) != noErr)
        goto error;

    lua_newtable(L);

    for(i = 0; i < datasourceListPropertySize; i++) {
        lua_pushinteger(L, tableIndex++);
        new_dataSource(L, deviceId, datasourceList[i]);
        lua_settable(L, -3);
    }

    goto end;

error:
    lua_pushnil(L);

end:
    free(datasourceList);

    return 1;
}

/// hs.audiodevice:watcherCallback(fn) -> hs.audiodevice
/// Method
/// Sets or removes a callback function for an audio device watcher
///
/// Parameters:
///  * fn - A callback function that will be called when properties of this audio device change, or nil to remove an existing callback. The function should accept four arguments:
///   * A string containing the UID of the audio device (see `hs.audiodevice.findDeviceByUID()`)
///   * A string containing the name of the event. Possible values are:
///    * vmvc - Volume changed
///    * mute - Mute state changed
///    * jack - Jack sense state changed (usually this means headphones were plugged/unplugged)
///    * span - Stereo pan changed
///    * diff - Device configuration changed (if you are caching audio device properties, this event indicates you should flush your cache)
///   * A string containing the scope of the event. Possible values are:
///    * glob - This is a global event pertaining to the whole device
///    * inpt - This is an event pertaining only to the input functions of the device
///    * outp - This is an event pertaining only to the output functions of the device
///   * A number containing the element of the event. Typical values are:
///    * 0 - Typically this means the Master channel
///    * 1 - Typically this means the Left channel
///    * 2 - Typically this means the Right channel
///
/// Returns:
///  * The `hs.audiodevice` object
///
/// Notes:
///  * You will receive many events to your callback, so filtering on the name/scope/element arguments is vital. For example, on a stereo device, it is not uncommon to receive a `volm` event for each audio channel when the volume changes, or multiple `mute` events for channels. Dragging a volume slider in the system Sound preferences will produce a large number of `volm` events. Plugging/unplugging headphones may trigger `volm` events in addition to `jack` ones, etc.
///  * If you need to use the `hs.audiodevice` object in your callback, use `hs.audiodevice.findDeviceByUID()` to obtain it fro the first callback argument
static int audiodevice_watcherSetCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION|LS_TNIL, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);

    audioDevice->callback = [skin luaUnref:refTable ref:audioDevice->callback];

    switch (lua_type(L, 2)) {
        case LUA_TFUNCTION:
            lua_pushvalue(L, 2);
            audioDevice->callback = [skin luaRef:refTable];
            break;

        case LUA_TNIL:
            watcherStop(audioDevice);
            break;

        default:
            break;
    }

    lua_pushvalue(L, 1);

    return 1;
}

/// hs.audiodevice:watcherStart() -> hs.audiodevice or nil
/// Method
/// Starts the watcher on an `hs.audiodevice` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.audiodevice` object, or nil if an error occurred
static int audiodevice_watcherStart(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);

    if (audioDevice->callback == LUA_NOREF) {
        [skin logError:@"You must call hs.audiodevice:setCallback() before hs.audiodevice:start()"];
        lua_pushnil(L);
        return 1;
    }

    if (audioDevice->watcherRunning == YES) {
        lua_pushvalue(L, 1);
        return 1;
    }

    AudioObjectPropertyAddress propertyAddress = {
        0,
        kAudioObjectPropertyScopeWildcard,
        kAudioObjectPropertyElementWildcard
    };

    const int numSelectors = sizeof(watchSelectors) / sizeof(watchSelectors[0]);

    for (int i = 0; i < numSelectors; i++) {
        //NSLog(@"Registering callback for: %@", (__bridge_transfer NSString *)UTCreateStringForOSType(watchSelectors[i]));
        propertyAddress.mSelector = watchSelectors[i];
        AudioObjectAddPropertyListener(audioDevice->deviceId, &propertyAddress, audiodevice_callback, (void *)audioDevice);
    }

    audioDevice->watcherRunning = YES;

    lua_pushvalue(L, 1);

    return 1;
}

void watcherStop(audioDeviceUserData *audioDevice) {
    if (audioDevice->watcherRunning == NO) {
        return;
    }

    AudioObjectPropertyAddress propertyAddress = {
        0,
        kAudioObjectPropertyScopeWildcard,
        kAudioObjectPropertyElementWildcard
    };

    const int numSelectors = sizeof(watchSelectors) / sizeof(watchSelectors[0]);

    for (int i = 0; i < numSelectors; i++) {
        propertyAddress.mSelector = watchSelectors[i];
        AudioObjectRemovePropertyListener(audioDevice->deviceId, &propertyAddress, audiodevice_callback, (void *)audioDevice);
    }

    audioDevice->watcherRunning = NO;
}

/// hs.audiodevice:watcherStop() -> hs.audiodevice
/// Method
/// Stops the watcher on an `hs.audiodevice` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.audiodevice` object
static int audiodevice_watcherStop(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);

    watcherStop(audioDevice);

    lua_pushvalue(L, 1);

    return 1;
}

/// hs.audiodevice:watcherIsRunning() -> boolean
/// Method
/// Gets the status of the `hs.audiodevice` object watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if the watcher is running, false if not
static int audiodevice_watcherIsRunning(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);

    lua_pushboolean(L, audioDevice->watcherRunning);

    return 1;
}

static int audiodevice_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);
    AudioDeviceID deviceId = audioDevice->deviceId;
    CFStringRef deviceName;
    UInt32 propertySize = sizeof(CFStringRef);
    NSString *deviceNameNS ;

    AudioObjectPropertyAddress propertyAddress = {
        kAudioObjectPropertyName,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };

    if (AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &propertySize, &deviceName) == noErr) {
        deviceNameNS = (__bridge_transfer NSString *)deviceName;
    } else {
        deviceNameNS = @"(un-named audiodevice)";
    }

    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, deviceNameNS, lua_topointer(L, 1)]];

    return 1 ;
}

static int audiodevice_eq(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *deviceA = userdataToAudioDevice(L, 1);
    audioDeviceUserData *deviceB = userdataToAudioDevice(L, 2);
    lua_pushboolean(L, deviceA->deviceId == deviceB->deviceId);

    return 1;
}

static int audiodevice_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    audioDeviceUserData *audioDevice = userdataToAudioDevice(L, 1);

    audiodevice_watcherStop(L);

    audioDevice->callback = [skin luaUnref:refTable ref:audioDevice->callback];
    [skin destroyGCCanary:&(audioDevice->lsCanary)];

    return 0;
}

#pragma mark - hs.audiodevice.datasource object methods

NSString *get_datasource_name(AudioDeviceID hostDevice, UInt32 dataSource) {
    NSString *name = @"(un-named datasource)";
    CFStringRef dataSourceName;
    AudioObjectPropertyScope scope;

    if (isOutputDevice(hostDevice)) {
        scope = kAudioObjectPropertyScopeOutput;
    } else if (isInputDevice(hostDevice)) {
        scope = kAudioObjectPropertyScopeInput;
    } else {
        return name;
    }

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyDataSourceNameForIDCFString,
        scope,
        kAudioObjectPropertyElementMaster
    };

    AudioValueTranslation avt;
    avt.mInputData = (void *)&dataSource;
    avt.mInputDataSize = sizeof(UInt32);
    avt.mOutputData = (void *)&dataSourceName;
    avt.mOutputDataSize = sizeof(CFStringRef);

    UInt32 avtSize = sizeof(avt);

    if (AudioObjectGetPropertyData(hostDevice, &propertyAddress, 0, NULL, &avtSize, &avt) == noErr) {
        name = (__bridge_transfer NSString *)dataSourceName;
    }

    return name;
}

/// hs.audiodevice.datasource:name() -> string
/// Method
/// Gets the name of an audio device datasource
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the name of the datasource
static int datasource_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_DATASOURCE_TAG, LS_TBREAK];

    dataSourceUserData *dataSource = userdataToDataSource(L, 1);
    NSString *name = get_datasource_name(dataSource->hostDevice, dataSource->dataSource);

    lua_pushstring(L, name.UTF8String);

    return 1;
}

/// hs.audiodevice.datasource:setDefault() -> hs.audiodevice.datasource
/// Method
/// Sets the audio device datasource as the default
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.audiodevice.datasource` object
static int datasource_setDefault(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_DATASOURCE_TAG, LS_TBREAK];

    dataSourceUserData *dataSource = userdataToDataSource(L, 1);
    AudioObjectPropertyScope scope;

    if (isOutputDevice(dataSource->hostDevice)) {
        scope = kAudioObjectPropertyScopeOutput;
    } else if (isInputDevice(dataSource->hostDevice)) {
        scope = kAudioObjectPropertyScopeInput;
    } else {
        NSLog(@"ERROR: datasource host device is neither input nor output");
        lua_pushvalue(L, 1);
        return 1;
    }

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyDataSource,
        scope,
        kAudioObjectPropertyElementMaster
    };

    AudioObjectSetPropertyData(dataSource->hostDevice, &propertyAddress, 0, NULL, sizeof(UInt32), &dataSource->dataSource);

    lua_pushvalue(L, 1);

    return 1;
}

static int datasource_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_DATASOURCE_TAG, LS_TBREAK];

    dataSourceUserData *dataSource = userdataToDataSource(L, 1);
    NSString *name = get_datasource_name(dataSource->hostDevice, dataSource->dataSource);

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_DATASOURCE_TAG, name, lua_topointer(L, 1)] UTF8String]) ;

    return 1;
}

static int datasource_eq(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_DATASOURCE_TAG, LS_TUSERDATA, USERDATA_DATASOURCE_TAG, LS_TBREAK];

    dataSourceUserData *sourceA = userdataToDataSource(L, 1);
    dataSourceUserData *sourceB = userdataToDataSource(L, 2);
    lua_pushboolean(L, sourceA->dataSource == sourceB->dataSource);

    return 1;
}
#pragma mark - Library initialisation

// Metatable for audiodevice objects
static const luaL_Reg audiodevice_metalib[] = {
    {"setDefaultOutputDevice",  audiodevice_setdefaultoutputdevice},
    {"setDefaultInputDevice",   audiodevice_setdefaultinputdevice},
    {"setDefaultEffectDevice",  audiodevice_setdefaulteffectdevice},
    {"name",                    audiodevice_name},
    {"uid",                     audiodevice_uid},
    {"volume",                  audiodevice_volume},
    {"inputVolume",             audiodevice_inputVolume},
    {"outputVolume",            audiodevice_outputVolume},
    {"setVolume",               audiodevice_setvolume},
    {"balance",                 audiodevice_balance},
    {"setBalance",              audiodevice_setbalance},
    {"setInputVolume",          audiodevice_setInputVolume},
    {"setOutputVolume",         audiodevice_setOutputVolume},
    {"muted",                   audiodevice_muted},
    {"inputMuted",              audiodevice_inputMuted},
    {"outputMuted",             audiodevice_outputMuted},
    {"setMuted",                audiodevice_setmuted},
    {"setInputMuted",           audiodevice_setInputMuted},
    {"setOutputMuted",          audiodevice_setOutputMuted},
    {"transportType",           audiodevice_transportType},
    {"jackConnected",           audiodevice_jackConnected},
    {"supportsInputDataSources",audiodevice_supportsInputDataSources},
    {"supportsOutputDataSources",audiodevice_supportsOutputDataSources},
    {"currentInputDataSource",  audiodevice_currentInputDataSource},
    {"currentOutputDataSource", audiodevice_currentOutputDataSource},
    {"allOutputDataSources",    audiodevice_allOutputDataSources},
    {"allInputDataSources",     audiodevice_allInputDataSources},
    {"isInputDevice",           audiodevice_isInputDevice},
    {"isOutputDevice",          audiodevice_isOutputDevice},
    {"watcherCallback",         audiodevice_watcherSetCallback},
    {"watcherStart",            audiodevice_watcherStart},
    {"watcherStop",             audiodevice_watcherStop},
    {"watcherIsRunning",        audiodevice_watcherIsRunning},
    {"__tostring",              audiodevice_tostring},
    {"__eq",                    audiodevice_eq},
    {"__gc",                    audiodevice_gc},

    {NULL, NULL}
};

static const luaL_Reg audiodeviceLib[] = {
    {"allDevices",              audiodevice_alldevices},
    {"defaultOutputDevice",     audiodevice_defaultoutputdevice},
    {"defaultInputDevice",      audiodevice_defaultinputdevice},
    {"defaultEffectDevice",     audiodevice_defaulteffectdevice},

    {NULL, NULL}
};

static const luaL_Reg dataSourceLib[] = {
    {"name",                    datasource_name},
    {"setDefault",              datasource_setDefault},
    {"__tostring",              datasource_tostring},
    {"__eq",                    datasource_eq},

    {NULL, NULL}
};

int luaopen_hs_audiodevice_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG functions:audiodeviceLib metaFunctions:nil objectFunctions:audiodevice_metalib];
    [skin registerObject:USERDATA_DATASOURCE_TAG objectFunctions:dataSourceLib];

    return 1;
}
