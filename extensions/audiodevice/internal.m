#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioToolbox.h>
#include <LuaSkin/LuaSkin.h>
#include "math.h"

#define USERDATA_TAG    "hs.audiodevice"

#define MJ_Audio_Device(L, idx) *(AudioDeviceID*)luaL_checkudata(L, idx, USERDATA_TAG)

static bool _check_audio_device_has_streams(AudioDeviceID deviceId, AudioObjectPropertyScope scope) {

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyStreams,
        scope,
        kAudioObjectPropertyElementMaster
    };

    OSStatus result = noErr;
    UInt32 dataSize = 0;

    result = AudioObjectGetPropertyDataSize(deviceId, &propertyAddress, 0, NULL, &dataSize);

    if (result)
        goto error;

    return (dataSize / sizeof(AudioStreamID)) > 0;


error:
    return false;
}

void new_device(lua_State* L, AudioDeviceID deviceId) {
    AudioDeviceID* userData = (AudioDeviceID*) lua_newuserdata(L, sizeof(AudioDeviceID));
    *userData = deviceId;

    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
}

/// hs.audiodevice.allOutputDevices() -> audio[]
/// Function
/// Returns a list of all connected output devices.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table of zero or more audio output devices connected to the system
static int audiodevice_alloutputdevices(lua_State* L) {
    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };
    OSStatus result = noErr;
    AudioDeviceID *deviceList = NULL;
    UInt32 deviceListPropertySize = 0;
    UInt32 numDevices = 0;

    result = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &deviceListPropertySize);
    if (result) {
        goto error;
    }

    numDevices = deviceListPropertySize / sizeof(AudioDeviceID);
    deviceList = (AudioDeviceID*) calloc(numDevices, sizeof(AudioDeviceID));

    if (!deviceList)
        goto error;

    result = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &deviceListPropertySize, deviceList);
    if (result) {
        goto error;
    }

    lua_newtable(L);

    for(UInt32 i = 0, tableIndex = 1; i < numDevices; i++) {
        AudioDeviceID deviceId = deviceList[i];
        if (!_check_audio_device_has_streams(deviceId, kAudioDevicePropertyScopeOutput))
            continue;

        lua_pushinteger(L, tableIndex++);
        new_device(L, deviceId);
        lua_settable(L, -3);
    }

    goto end;

error:
    lua_pushnil(L);

end:
    if (deviceList)
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
    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };

    AudioDeviceID deviceId;
    UInt32 deviceIdSize = sizeof(AudioDeviceID);
    OSStatus result = noErr;

    result = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, &deviceIdSize, &deviceId);
    if (result)
        goto error;

    if (!_check_audio_device_has_streams(deviceId, kAudioDevicePropertyScopeOutput))
        goto error;

    new_device(L, deviceId);
    goto end;

error:
    lua_pushnil(L);

end:

    return 1;
}

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
    AudioDeviceID deviceId = MJ_Audio_Device(L, 1);

    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };

    UInt32 deviceIdSize = sizeof(AudioDeviceID);
    OSStatus result = noErr;

    if (!_check_audio_device_has_streams(deviceId, kAudioDevicePropertyScopeOutput))
        goto error;

    result = AudioObjectSetPropertyData(kAudioObjectSystemObject, &propertyAddress, 0, NULL, deviceIdSize, &deviceId);

    if (result)
        goto error;

    lua_pushboolean(L, true);
    goto end;

error:
    lua_pushboolean(L, false);

end:

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
    AudioDeviceID deviceId = MJ_Audio_Device(L, 1);

    AudioObjectPropertyAddress propertyAddress = {
        kAudioObjectPropertyName,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };
    CFStringRef deviceName;
    UInt32 propertySize = sizeof(CFStringRef);

    OSStatus result = noErr;

    result = AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &propertySize, &deviceName);
    if (result) {
        lua_pushnil(L);
        return 1;
    }

    NSString *deviceNameNS = (__bridge NSString *)deviceName;
    lua_pushstring(L, [deviceNameNS UTF8String]);

    CFRelease(deviceName);
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
    AudioDeviceID deviceId = MJ_Audio_Device(L, 1);

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyDeviceUID,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };
    CFStringRef deviceName;
    UInt32 propertySize = sizeof(CFStringRef);

    OSStatus result = noErr;

    result = AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &propertySize, &deviceName);
    if (result)
        goto error;

    CFIndex length = CFStringGetLength(deviceName);
    const char* deviceNameBytes = CFStringGetCStringPtr(deviceName, kCFStringEncodingMacRoman);

    lua_pushlstring(L, deviceNameBytes, length);
    CFRelease(deviceName);

    goto end;

error:
    lua_pushnil(L);

end:
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
static int audiodevice_muted(lua_State* L) {
    AudioDeviceID deviceId = MJ_Audio_Device(L, 1);

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyMute,
        kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };

    if (!AudioObjectHasProperty(deviceId, &propertyAddress)) {
        goto error;
    }

    OSStatus result = noErr;
    UInt32 muted;
    UInt32 mutedSize = sizeof(UInt32);

    result = AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &mutedSize, &muted);
    if (result)
        goto error;

    lua_pushboolean(L, muted != 0);

    goto end;

error:
    lua_pushnil(L);

end:
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
static int audiodevice_setmuted(lua_State* L) {
    AudioDeviceID deviceId = MJ_Audio_Device(L, 1);
    UInt32 muted = lua_toboolean(L, 2);

    AudioObjectPropertyAddress propertyAddress = {
        kAudioDevicePropertyMute,
        kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };

    if (!AudioObjectHasProperty(deviceId, &propertyAddress)) {
        goto error;
    }

    OSStatus result = noErr;
    UInt32 mutedSize = sizeof(UInt32);

    result = AudioObjectSetPropertyData(deviceId, &propertyAddress, 0, NULL, mutedSize, &muted);
    if (result)
        goto error;

    lua_pushboolean(L, true);

    goto end;

error:
    lua_pushboolean(L, false);

end:
    return 1;

}

/// hs.audiodevice:volume() -> number or bool
/// Method
/// Get the current volume of this audio device
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number between 0 and 100, representing the volume percentage, or nil if the audio device does not support volume levels
static int audiodevice_volume(lua_State* L) {
    AudioDeviceID deviceId = MJ_Audio_Device(L, 1);

    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
        kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };

    if (!AudioObjectHasProperty(deviceId, &propertyAddress))
        goto error;

    OSStatus result = noErr;
    Float32 volume;
    UInt32 volumeSize = sizeof(Float32);

    result = AudioObjectGetPropertyData(deviceId, &propertyAddress, 0, NULL, &volumeSize, &volume);

    if (result)
        goto error;

    lua_pushinteger(L, (int)(volume * 100.0));

    goto end;

error:
    lua_pushnil(L);

end:
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
static int audiodevice_setvolume(lua_State* L) {
    AudioDeviceID deviceId = MJ_Audio_Device(L, 1);
    Float32 volume = MIN(MAX((float)luaL_checkinteger(L, 2) / 100.0, 0.0), 1.0);

    AudioObjectPropertyAddress propertyAddress = {
        kAudioHardwareServiceDeviceProperty_VirtualMasterVolume,
        kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMaster
    };

    if (!AudioObjectHasProperty(deviceId, &propertyAddress))
        goto error;

    OSStatus result = noErr;
    UInt32 volumeSize = sizeof(Float32);

    result = AudioObjectSetPropertyData(deviceId, &propertyAddress, 0, NULL, volumeSize, &volume);

    if (result)
        goto error;

    lua_pushboolean(L, true);

    goto end;

error:
    lua_pushboolean(L, false);

end:
    return 1;

}

static int audiodevice_eq(lua_State* L) {
    AudioDeviceID deviceA = MJ_Audio_Device(L, 1);
    AudioDeviceID deviceB = MJ_Audio_Device(L, 2);
    lua_pushboolean(L, deviceA == deviceB);
    return 1;
}

// Metatable for audiodevice objects
static const luaL_Reg audiodevice_metalib[] = {
    {"setDefaultOutputDevice",  audiodevice_setdefaultoutputdevice},
    {"name",                    audiodevice_name},
    {"uid",                     audiodevice_uid},
    {"volume",                  audiodevice_volume},
    {"setVolume",               audiodevice_setvolume},
    {"muted",                   audiodevice_muted},
    {"setMuted",                audiodevice_setmuted},
    {NULL, NULL}
};

static const luaL_Reg audiodeviceLib[] = {
    {"allOutputDevices",        audiodevice_alloutputdevices},
    {"defaultOutputDevice",     audiodevice_defaultoutputdevice},
    {NULL, NULL}
};

int luaopen_hs_audiodevice_internal(lua_State* L) {
// Metatable for created objects
    luaL_newlib(L, audiodevice_metalib);
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        lua_pushcfunction(L, audiodevice_eq);
        lua_setfield(L, -2, "__eq");
        lua_setfield(L, LUA_REGISTRYINDEX, USERDATA_TAG);

// Create table for luaopen
    luaL_newlib(L, audiodeviceLib);

    return 1;
}
