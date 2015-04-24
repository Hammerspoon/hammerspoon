#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <lauxlib.h>
#import "../hammerspoon.h"

#define USERDATA_TAG    "hs.sound"

@interface soundDelegate : NSObject <NSSoundDelegate>
@property lua_State* L;
@property int fn;
@end

@implementation soundDelegate
- (void) sound:(NSSound __unused *)sound didFinishPlaying:(BOOL)playbackSuccessful
{
    lua_State* L = self.L;
    lua_getglobal(L, "debug"); lua_getfield(L, -1, "traceback"); lua_remove(L, -2);
    lua_rawgeti(L, LUA_REGISTRYINDEX, self.fn);
    lua_pushboolean(L, playbackSuccessful);
    if (lua_pcall(L, 1, 0, -3) != LUA_OK) {
        CLS_NSLOG(@"%s", lua_tostring(L, -1));
        lua_getglobal(L, "hs"); lua_getfield(L, -1, "showError"); lua_remove(L, -2);
        lua_pushvalue(L, -2);
        lua_pcall(L, 1, 0, 0);
    }
}
@end

// Common Code

static int store_udhandler(lua_State* L, NSMutableIndexSet* theHandler, int idx) {
    lua_pushvalue(L, idx);
    int x = luaL_ref(L, LUA_REGISTRYINDEX);
    [theHandler addIndex: x];
    return x;
}

static int remove_udhandler(lua_State* L, NSMutableIndexSet* theHandler, int x) {
    luaL_unref(L, LUA_REGISTRYINDEX, x);
    [theHandler removeIndex: x];
    return LUA_NOREF;
}

static NSMutableIndexSet* soundHandlers;

typedef struct _sound_t{
    void*   soundObject;
    bool    stopOnRelease;
    void*   callback;
    int     fn;
    int     registryHandle;
} sound_t;

// Not so common code

/// hs.sound.getByName(name) -> sound or nil
/// Constructor
/// Creates an `hs.sound` object from a named sound
///
/// Parameters:
///  * name - A string containing the name of a sound
///
/// Returns:
///  * An `hs.sound` object or nil if no matching sound could be found
///
/// Notes:
///  * Sounds can only be loaded by name if they are System Sounds (i.e. those found in ~/Library/Sounds, /Library/Sounds, /Network/Library/Sounds and /System/Library/Sounds) or are sound files that have previously been loaded and named
static int sound_byname(lua_State* L) {
    NSSound* theSound = [NSSound soundNamed:[NSString stringWithUTF8String: luaL_checkstring(L, 1)]] ;
    if (theSound) {
        sound_t* soundUserData = lua_newuserdata(L, sizeof(sound_t)) ;
        memset(soundUserData, 0, sizeof(sound_t)) ;
        soundUserData->soundObject = (__bridge_retained void*)theSound ;
        soundUserData->stopOnRelease = YES;
        soundUserData->callback = nil;
        soundUserData->fn = 0;
        soundUserData->registryHandle = store_udhandler(L, soundHandlers, -1) ;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
    } else {
        lua_pushnil(L) ;
    }
    return 1;
}

/// hs.sound.getByFile(path) -> sound or nil
/// Constructor
/// Creates an `hs.sound` object from a file
///
/// Parameters:
///  * path - A string containing the path to a sound file
///
/// Returns:
///  * An `hs.sound` object or nil if the file could not be loaded
static int sound_byfile(lua_State* L) {
    NSSound* theSound = [[NSSound alloc] initWithContentsOfFile:[NSString stringWithUTF8String: luaL_checkstring(L, 1)] byReference: NO] ;
    if (theSound) {
        sound_t* soundUserData = lua_newuserdata(L, sizeof(sound_t)) ;
        memset(soundUserData, 0, sizeof(sound_t)) ;
        soundUserData->soundObject = (__bridge_retained void*)theSound ;
        soundUserData->stopOnRelease = YES;
        soundUserData->callback = nil;
        soundUserData->fn = 0;
        soundUserData->registryHandle = store_udhandler(L, soundHandlers, -1) ;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
    } else {
        lua_pushnil(L) ;
    }
    return 1;
}

/// hs.systemSounds() -> table
/// Function
/// Gets a table of available system sounds
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing all of the available sound files (i.e. those found in ~/Library/Sounds, /Library/Sounds, /Network/Library/Sounds and /System/Library/Sounds)
///
/// Notes:
///  * The sounds listed by this function can be loaded using `hs.sound.getByName()`
static int sound_systemSounds(lua_State* L) {
    int i = 0;
    lua_newtable(L) ;
        NSEnumerator *librarySources = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES) objectEnumerator];
        NSString *sourcePath;

        while ( sourcePath = [librarySources nextObject] )
        {
            NSEnumerator *soundSource = [[NSFileManager defaultManager] enumeratorAtPath: [sourcePath stringByAppendingPathComponent: @"Sounds"]];
            NSString *soundFile;
            while ( soundFile = [soundSource nextObject] )
                if ( [NSSound soundNamed: [soundFile stringByDeletingPathExtension]] ) {
                    lua_pushstring(L, [[soundFile stringByDeletingPathExtension] UTF8String]);
                    lua_rawseti(L, -2, ++i);
                }
        }
    return 1;
}

/// hs.sound:play() -> sound, bool
/// Method
/// Plays an `hs.sound` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.sound` object and a boolean, true if the sound was played, otherwise false
static int sound_play(lua_State* L) {
    sound_t* sound = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L, 1);
    lua_pushboolean(L, [(__bridge NSSound*)sound->soundObject play]);
    return 2;
}

/// hs.sound:pause() -> sound, bool
/// Method
/// Pauses an `hs.sound` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.sound` object and a boolean, true if the sound was paused, otherwise false
static int sound_pause(lua_State* L) {
    sound_t* sound = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L, 1);
    lua_pushboolean(L, [(__bridge NSSound*)sound->soundObject pause]);
    return 2;
}

/// hs.sound:resume() -> sound, bool
/// Method
/// Resumes playing a paused `hs.sound` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.sound` object and a boolean, true if the sound resumed playing, otherwise false
static int sound_resume(lua_State* L) {
    sound_t* sound = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L, 1);
    lua_pushboolean(L, [(__bridge NSSound*) sound->soundObject resume]);
    return 2;
}

/// hs.sound:stop() -> sound, bool
/// Method
/// Stops playing an `hs.sound` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.sound` object and a boolean, true if the sound was stopped, otherwise false
static int sound_stop(lua_State* L) {
    sound_t* sound = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_settop(L, 1);
    lua_pushboolean(L, [(__bridge NSSound*) sound->soundObject stop]);
    return 2;
}

/// hs.sound:loopSound([loop]) -> bool
/// Method
/// Gets, and optionally sets, the looping behaviour of an `hs.sound` object
///
/// Parameters:
///  * loop - An optional boolean, true to loop playback, false to not loop
///
/// Returns:
///  * A boolean, true if the sound will be looped, otherwise false
///
/// Notes:
///  * If you have registered a callback function for completion of a sound's playback, it will not be called when the sound loops
static int sound_loopSound(lua_State* L) {
    sound_t* sound = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        [(__bridge NSSound*) sound->soundObject setLoops:lua_toboolean(L, 2)];
    }
    lua_pushboolean(L, [(__bridge NSSound*) sound->soundObject loops]);
    return 1;
}

/// hs.sound:stopOnReload([stopOnReload]) -> bool
/// Method
/// Gets, and optionally sets, whether a sound should be stopped when Hammerspoon reloads its config
///
/// Parameters:
///  * stopOnReload - An optional boolean, true to stop playback when Hammerspoon reloads its config, false to continue playback regardless
///
/// Returns:
///  * A boolean, true if the sound will be stopped on reload, otherwise false
///
/// Notes:
///  * This method can only be used on a named `hs.sound` object, see `hs.sound:name()`
static int sound_stopOnRelease(lua_State* L) {
    sound_t* sound = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        if ([(__bridge NSSound*) sound->soundObject name]) {
            sound->stopOnRelease = lua_toboolean(L, 2);
        } else {
            lua_pushstring(L, "you must first assign a name to this sound in order to change this attribute");
            lua_error(L);
        }
    }
    lua_pushboolean(L, sound->stopOnRelease);
    return 1;
}

/// hs.sound:name([soundName]) -> string or nil
/// Method
/// Gets, and optionally sets, the name of an `hs.sound` object
///
/// Parameters:
///  * soundName - An optional string to use as the name of the object, or nil to remove the name
///
/// Returns:
///  * A string containing the name of the object, or nil if no name has been set
static int sound_name(lua_State* L) {
    sound_t* sound = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        if (lua_isnil(L,2)) {
            [(__bridge NSSound*) sound->soundObject setName:nil];
            sound->stopOnRelease = YES;
        } else {
            [(__bridge NSSound*) sound->soundObject setName:[NSString stringWithUTF8String: luaL_checkstring(L, 2)]];
        }
    }
    lua_pushstring(L, [[(__bridge NSSound*) sound->soundObject name] UTF8String]);
    return 1;
}

/// hs.sound:device([deviceUID]) -> string
/// Method
/// Gets, and optionally sets, the playback device to use for an `hs.sound` object
///
/// Parameters:
///  * deviceUID - An optional string containing the UID of an `hs.audiodevice` object to use for playback of this sound. Use nil to use the system's default device
///
/// Returns:
///  * A string containing the UID of the device that will be used for playback
///
/// Notes:
///  * To obtain the UID of a sound device, see `hs.audiodevice:uid()`
static int sound_device(lua_State* L) {
    sound_t* sound = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        if (lua_isnil(L,2)) {
            [(__bridge NSSound*) sound->soundObject setPlaybackDeviceIdentifier:nil];
        } else {
            @try {
                [(__bridge NSSound*) sound->soundObject setPlaybackDeviceIdentifier:[NSString stringWithUTF8String: luaL_checkstring(L, 2)]];
            } @catch(NSException *theException) {
                CLS_NSLOG(@"%s:device -- %@: %@", USERDATA_TAG, theException.name, theException.reason);
                lua_pushstring(L, [[NSString stringWithFormat:@"%@: %@", theException.name, theException.reason] UTF8String]);
                lua_error(L);
            }
        }
    }
    lua_pushstring(L, [[(__bridge NSSound*) sound->soundObject playbackDeviceIdentifier] UTF8String]);
    return 1;
}

/// hs.sound:currentTime([seekTime]) -> seconds
/// Method
/// Gets the current seek offset within an `hs.sound` object, and optionally sets a new seek offset
///
/// Parameters:
///  * seekTime - An optional number of seconds to seek to within the sound object
///
/// Returns:
///  * A number containing the current seek offset in the sound (i.e. the current playback position in the sound)
static int sound_currentTime(lua_State* L) {
    sound_t* sound = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        [(__bridge NSSound*) sound->soundObject setCurrentTime:luaL_checknumber(L, 2)];
    }
    lua_pushnumber(L, [(__bridge NSSound*) sound->soundObject currentTime]);
    return 1;
}

/// hs.sound:duration() -> seconds
/// Method
/// Gets the length of an `hs.sound` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the length of the sound, in seconds
static int sound_duration(lua_State* L) {
    sound_t* sound = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_pushnumber(L, [(__bridge NSSound*) sound->soundObject duration]);
    return 1;
}

/// hs.sound:volume([level]) -> number
/// Method
/// Gets, and optionally sets, the playback volume of an `hs.sound` object
///
/// Parameters:
///  * level - A number between 0.0 and 1.0, representing the volume of the sound, relative to the current system volume
///
/// Returns:
///  * The current volume offset
static int sound_volume(lua_State* L) {
    sound_t* sound = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        [(__bridge NSSound*) sound->soundObject setVolume:luaL_checknumber(L, 2)];
    }
    lua_pushnumber(L, [(__bridge NSSound*) sound->soundObject volume]);
    return 1;
}

/// hs.sound:function([fn]) -> bool
/// Method
/// Gets the status of the completion callback of an `hs.sound` object, and optionally sets the status
///
/// Parameters:
///  * fn - An optional function that will be called when playback is completed, or nil to remove a previously assigned callback
///
/// Returns:
///  * A boolean, true if there is a playback completion callback assigned, otherwise false
static int sound_callback(lua_State* L) {
    sound_t* sound = luaL_checkudata(L, 1, USERDATA_TAG);
    if (!lua_isnone(L, 2)) {
        if (lua_isnil(L,2)) {
            luaL_unref(L, LUA_REGISTRYINDEX, sound->fn);
            sound->fn = LUA_NOREF;
            if (sound->callback) {
                [(__bridge NSSound*) sound->soundObject setDelegate:nil];
                soundDelegate* object = (__bridge_transfer soundDelegate *) sound->callback ;
                sound->callback = nil ; object = nil ;
            }
        } else {
            luaL_checktype(L, 2, LUA_TFUNCTION);
            lua_pushvalue(L, 2);
            sound->fn = luaL_ref(L, LUA_REGISTRYINDEX);
            soundDelegate* object = [[soundDelegate alloc] init];
            object.L = L;
            object.fn = sound->fn;
            sound->callback = (__bridge_retained void*) object;
            [(__bridge NSSound*) sound->soundObject setDelegate: object];
        }
    }
    if (sound->callback) {
        lua_pushboolean(L, YES);
    } else {
        lua_pushboolean(L, NO);
    }
    return 1;
}

/// hs.sound.soundTypes() -> table
/// Function
/// Gets the supported UTI sound file formats
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the UTI sound formats that are supported by the system
static int sound_soundUnfilteredTypes(lua_State* L) {
    int i = 0;
    NSArray* list = [NSSound soundUnfilteredTypes];
    lua_newtable(L);
    for (id item in list) {
        lua_pushstring(L, [item UTF8String]);
        lua_rawseti(L, -2, ++i);
    }
    return 1;
}

/// hs.sound.soundFileTypes() -> table
/// Function
/// Gets the supported sound file types
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the sound file filename extensions that are supported by the system
///
/// Notes:
///  * This function is unlikely to be tremendously useful, as filename extensions are essentially meaningless. The data returned by `hs.sound.soundTypes()` is far more valuable
static int sound_soundUnfilteredFileTypes(lua_State* L) {
    if ([NSSound respondsToSelector:@selector(soundUnfilteredFileTypes)]) {
        int i = 0;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSArray* list = [NSSound soundUnfilteredFileTypes];
#pragma clang diagnostic pop
        lua_newtable(L);
        for (id item in list) {
            lua_pushstring(L, [item UTF8String]);
            lua_rawseti(L, -2, ++i);
        }
    } else {
        lua_pushstring(L, "Deprecated selector soundUnfilteredFileTypes not supported under this OS X version.  Please use `hs.sound.soundTypes` instead.");
    }
    return 1;
}

/// hs.sound:isPlaying() -> bool
/// Method
/// Gets the current playback state of an `hs.sound` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if the sound is currently playing, otherwise false
///
/// Notes:
///  * This method is only available in OS X 10.9 (Mavericks) and earlier
static int sound_isPlaying(lua_State* L) {
    sound_t* sound = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_pushboolean(L, [(__bridge NSSound*) sound->soundObject isPlaying]);
    return 1;
}


// Common wrap-up

static int sound_setup(lua_State* __unused L) {
    if (!soundHandlers) soundHandlers = [NSMutableIndexSet indexSet];
    return 0;
}

static int sound_gc(lua_State* L) {
    sound_t* sound = luaL_checkudata(L, 1, USERDATA_TAG);
    lua_pushcfunction(L, sound_callback) ;
    lua_pushvalue(L,1); lua_pushnil(L); lua_call(L, 2, 1);
    if (sound->stopOnRelease) [(__bridge NSSound*) sound->soundObject stop];
    sound->registryHandle = remove_udhandler(L, soundHandlers, sound->registryHandle);
    NSSound* theSound = (__bridge_transfer NSSound *) sound->soundObject ;
    theSound = nil; sound->soundObject = nil;
    return 0;
}

static int meta_gc(lua_State* __unused L) {
    [soundHandlers removeAllIndexes];
    soundHandlers = nil;
    return 0;
}

// Metatable for created objects when _new invoked
static const luaL_Reg sound_metalib[] = {
    {"play",            sound_play},
    {"pause",           sound_pause},
    {"resume",          sound_resume},
    {"stop",            sound_stop},
    {"loopSound",       sound_loopSound},
    {"name",            sound_name},
    {"volume",          sound_volume},
    {"currentTime",     sound_currentTime},
    {"duration",        sound_duration},
    {"device",          sound_device},
    {"stopOnReload",    sound_stopOnRelease},
    {"callback",        sound_callback},
    {"isPlaying",       sound_isPlaying}, // Not in 10.10... can we replicate another way?
    {"__gc",	        sound_gc},
    {NULL,              NULL}
};

// Functions for returned object when module loads
static const luaL_Reg soundLib[] = {
    {"soundTypes",      sound_soundUnfilteredTypes},
    {"soundFileTypes",  sound_soundUnfilteredFileTypes},
    {"getByName",      sound_byname},
    {"getByFile",      sound_byfile},
    {"systemSounds",   sound_systemSounds},
    {NULL,              NULL}
};

// Metatable for returned object when module loads
static const luaL_Reg meta_gcLib[] = {
    {"__gc",    meta_gc},
    {NULL,      NULL}
};

int luaopen_hs_sound_internal(lua_State* L) {
    sound_setup(L);

// Metatable for created objects
    luaL_newlib(L, sound_metalib);
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        lua_setfield(L, LUA_REGISTRYINDEX, USERDATA_TAG);

// Create table for luaopen
    luaL_newlib(L, soundLib);

        luaL_newlib(L, meta_gcLib);
        lua_setmetatable(L, -2);

    return 1;
}
