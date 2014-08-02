#import "helpers.h"
#include <CoreAudio/CoreAudio.h>
#include <AudioToolbox/AudioToolbox.h>

/// === audiodevice ===
///
/// Manipulate the system's audio devices.


#define hydra_audio_device(L, idx) *(AudioDeviceID*)luaL_checkudata(L, idx, "audiodevice")

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
    
    luaL_getmetatable(L, "audiodevice");
    lua_setmetatable(L, -2);
}

/// audiodevice.alloutputdevices() -> audio[]
/// Returns a list of all connected output devices.
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
        
        lua_pushnumber(L, tableIndex++);
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

/// audiodevice.defaultoutputdevice() -> audio or nil
/// Gets the system's default audio device, or nil, it it does not exist.
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

/// audiodevice:setdefaultoutputdevice() -> bool
/// Sets the system's default audio device to this device. Returns true if the audio device was successfully set.
static int audiodevice_setdefaultoutputdevice(lua_State* L) {
    AudioDeviceID deviceId = hydra_audio_device(L, 1);
    
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

/// audiodevice:name() -> string or nil
/// Returns the name of the audio device, or nil if it does not have a name.
static int audiodevice_name(lua_State* L) {
    AudioDeviceID deviceId = hydra_audio_device(L, 1);
    
    AudioObjectPropertyAddress propertyAddress = {
        kAudioObjectPropertyName,
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

/// audiodevice:muted() -> bool or nil
/// Returns true/false if the audio device is muted, or nil if it does not support being muted.
static int audiodevice_muted(lua_State* L) {
    AudioDeviceID deviceId = hydra_audio_device(L, 1);
    
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

/// audiodevice:setmuted(bool) -> bool
/// Returns true if the the device's muted status was set, or false if it does not support being muted.
static int audiodevice_setmuted(lua_State* L) {
    AudioDeviceID deviceId = hydra_audio_device(L, 1);
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

/// audiodevice:volume() -> number or bool
/// Returns a number between 0 and 100 inclusive, representing the volume percentage. Or nil, if the audio device does not have a volume level.
static int audiodevice_volume(lua_State* L) {
    AudioDeviceID deviceId = hydra_audio_device(L, 1);
    
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
    
    lua_pushnumber(L, volume * 100.0);
    
    goto end;
    
error:
    lua_pushnil(L);
    
end:
    return 1;
    
}


/// audiodevice:setvolume(level) -> bool
/// Returns true if the volume was set, or false if the audio device does not support setting a volume level. Level is a percentage between 0 and 100.
static int audiodevice_setvolume(lua_State* L) {
    AudioDeviceID deviceId = hydra_audio_device(L, 1);
    Float32 volume = MIN(MAX(luaL_checknumber(L, 2) / 100.0, 0.0), 1.0);
    
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
    AudioDeviceID deviceA = hydra_audio_device(L, 1);
    AudioDeviceID deviceB = hydra_audio_device(L, 2);
    lua_pushboolean(L, deviceA == deviceB);
    return 1;
}

static const luaL_Reg audiodevicelib[] = {
    
    {"alloutputdevices", audiodevice_alloutputdevices},
    {"defaultoutputdevice", audiodevice_defaultoutputdevice},
    {"setdefaultoutputdevice", audiodevice_setdefaultoutputdevice},
    
    {"name", audiodevice_name},
    
    {"volume", audiodevice_volume},
    {"setvolume", audiodevice_setvolume},
    
    {"muted", audiodevice_muted},
    {"setmuted", audiodevice_setmuted},
    
    {NULL, NULL}
};

int luaopen_audiodevice(lua_State* L) {
    luaL_newlib(L, audiodevicelib);
    
    if (luaL_newmetatable(L, "audiodevice")) {
        lua_pushvalue(L, -2);
        lua_setfield(L, -2, "__index");
        
        lua_pushcfunction(L, audiodevice_eq);
        lua_setfield(L, -2, "__eq");
    }
    lua_pop(L, 1);
    
    return 1;
}
