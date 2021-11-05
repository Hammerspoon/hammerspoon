#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>
#import <AVFoundation/AVFoundation.h>

#define USERDATA_TAG "hs.sound"
static LSRefTable refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_cfobjectFromUserdata(objType, L, idx) *((objType*)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Support Functions and Classes

@interface HSSoundObject : NSObject <NSSoundDelegate>
@property NSSound *soundObject ;
@property int     callbackRef ;
@property int     selfRef ;
@property BOOL    stopOnRelease ;
@end

@implementation HSSoundObject

- (instancetype)initWithSound:(NSSound *)theSound {
    self = [super init] ;
    if (self) {
        _soundObject   = theSound ;
        _callbackRef   = LUA_NOREF ;
        _selfRef       = LUA_NOREF ;
        _stopOnRelease = YES ;
        [_soundObject setDelegate:self] ;
    }
    return self ;
}

#pragma mark - NSSoundDelegate methods

- (void) sound:(NSSound __unused *)sound didFinishPlaying:(BOOL)playbackSuccessful {
    dispatch_async(dispatch_get_main_queue(), ^{
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];
        _lua_stackguard_entry(skin.L);
//         [skin logVerbose:[NSString stringWithFormat:@"%s:in delegate", USERDATA_TAG]] ;
        if (self->_callbackRef != LUA_NOREF) {
            lua_State *L = skin.L;

            [skin pushLuaRef:refTable ref:self->_callbackRef];
            lua_pushboolean(L, playbackSuccessful);
            [skin pushNSObject:self];
            [skin protectedCallAndError:@"hs.sound:didFinishPlaying callback" nargs:2 nresults:0];
        }
        // a completed song should rely solely on user saved userdata values to prevent __gc
        // since there will be no other way to access it once this point is reached if it hasn't
        // been saved in a variable somewhere.
        self->_selfRef = [skin luaUnref:refTable ref:self->_selfRef] ;
        _lua_stackguard_exit(skin.L);
    }) ;
}

@end

#pragma mark - Module Functions

/// hs.sound.getAudioEffectNames() -> table
/// Function
/// Gets a table of installed Audio Units Effect names.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing the names of all installed Audio Units Effects.
///
/// Notes:
///  * Example usage: `hs.inspect(hs.audiounit.getAudioEffectNames())`
static int sound_getAudioEffectNames(lua_State *L) {
    AudioComponentDescription description;
    description.componentType = kAudioUnitType_Effect;
    description.componentSubType = 0;
    description.componentManufacturer = 0;
    description.componentFlags = 0;
    description.componentFlagsMask = 0;
    
    AudioComponent component = nil;
        
    int count = 1;
    
    lua_newtable(L);
    while((component = AudioComponentFindNext(component, &description))) {
        CFStringRef name;
        AudioComponentCopyName(component, &name);
        NSString *theName = (__bridge NSString *)name;
        
        if (theName) {
            lua_pushstring(L,[[NSString stringWithFormat:@"%@", theName] UTF8String]);
            lua_rawseti(L, -2, count++);
        }
        if (name) {
            CFRelease(name);
        }
    }
    return 1 ;
}

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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;
    luaL_checkstring(L, 1) ; // force number to be a string
    NSSound* theSound = [NSSound soundNamed:[skin toNSObjectAtIndex:1]] ;
    if (theSound) {
        [skin pushNSObject:theSound] ;
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER, LS_TBREAK] ;
    luaL_checkstring(L, 1) ; // force number to be a string
    NSSound* theSound = [[NSSound alloc] initWithContentsOfFile:[skin toNSObjectAtIndex:1] byReference: NO] ;
    if (theSound) {
        [skin pushNSObject:theSound] ;
    } else {
        lua_pushnil(L) ;
    }
    return 1;
}

/// hs.sound.systemSounds() -> table
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
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
                    [skin pushNSObject:[soundFile stringByDeletingPathExtension]] ;
                    lua_rawseti(L, -2, ++i);
                }
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    [skin pushNSObject:[NSSound soundUnfilteredTypes]];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TBREAK] ;
    if ([NSSound respondsToSelector:@selector(soundUnfilteredFileTypes)]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [skin pushNSObject:[NSSound soundUnfilteredFileTypes]];
#pragma clang diagnostic pop
    } else {
        lua_pushstring(L, "Deprecated selector soundUnfilteredFileTypes not supported in this OS X version.  Please use `hs.sound.soundTypes` instead.");
    }
    return 1;
}

#pragma mark - Module Methods

/// hs.sound:play() -> soundObject | bool
/// Method
/// Plays an `hs.sound` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.sound` object if the command was successful, otherwise false.
static int sound_play(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSSoundObject *obj = [skin luaObjectAtIndex:1 toClass:"HSSoundObject"] ;
    if ([obj.soundObject play]) {
        lua_pushvalue(L, 1) ;
        if (obj.selfRef == LUA_NOREF) {
            lua_pushvalue(L, 1) ;
            obj.selfRef = [skin luaRef:refTable];
        }
    } else {
        lua_pushboolean(L, NO);
    }
    return 1;
}

/// hs.sound:pause() -> soundObject | bool
/// Method
/// Pauses an `hs.sound` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.sound` object if the command was successful, otherwise false.
static int sound_pause(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSSound *obj = [skin luaObjectAtIndex:1 toClass:"NSSound"] ;
    if ([obj pause]) {
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, NO);
    }
    return 1 ;
}

/// hs.sound:resume() -> soundObject | bool
/// Method
/// Resumes playing a paused `hs.sound` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.sound` object if the command was successful, otherwise false.
static int sound_resume(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSSound *obj = [skin luaObjectAtIndex:1 toClass:"NSSound"] ;
    if ([obj resume]) {
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, NO);
    }
    return 1 ;
}

/// hs.sound:stop() -> soundObject | bool
/// Method
/// Stops playing an `hs.sound` object
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.sound` object if the command was successful, otherwise false.
static int sound_stop(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSSound *obj = [skin luaObjectAtIndex:1 toClass:"NSSound"] ;
    if ([obj stop]) {
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, NO);
    }
    return 1 ;
}

/// hs.sound:loopSound([loop]) -> soundObject | bool
/// Method
/// Get or set the looping behaviour of an `hs.sound` object
///
/// Parameters:
///  * loop - An optional boolean, true to loop playback, false to not loop
///
/// Returns:
///  * If a parameter is provided, returns the sound object; otherwise returns the current setting.
///
/// Notes:
///  * If you have registered a callback function for completion of a sound's playback, it will not be called when the sound loops
static int sound_loopSound(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    NSSound *obj = [skin luaObjectAtIndex:1 toClass:"NSSound"] ;
    if (lua_gettop(L) == 2) {
        [obj setLoops:(BOOL)lua_toboolean(L, 2)];
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, [obj loops]);
    }
    return 1;
}

/// hs.sound:stopOnReload([stopOnReload]) -> soundObject | bool
/// Method
/// Get or set whether a sound should be stopped when Hammerspoon reloads its configuration
///
/// Parameters:
///  * stopOnReload - An optional boolean, true to stop playback when Hammerspoon reloads its config, false to continue playback regardless.  Defaults to true.
///
/// Returns:
///  * If a parameter is provided, returns the sound object; otherwise returns the current setting.
///
/// Notes:
///  * This method can only be used on a named `hs.sound` object, see `hs.sound:name()`
static int sound_stopOnRelease(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSSoundObject *obj = [skin luaObjectAtIndex:1 toClass:"HSSoundObject"] ;
    if (lua_gettop(L) == 2) {
        if ([obj.soundObject name]) {
            obj.stopOnRelease = (BOOL)lua_toboolean(L, 2);
            lua_pushvalue(L, 1) ;
        } else {
            return luaL_error(L, "you must first assign a name to this sound in order to change this attribute");
        }
    } else {
        lua_pushboolean(L, obj.stopOnRelease);
    }
    return 1;
}

/// hs.sound:name([soundName]) -> soundObject | name string
/// Method
/// Get or set the name of an `hs.sound` object
///
/// Parameters:
///  * soundName - An optional string to use as the name of the object; use an explicit nil to remove the name
///
/// Returns:
///  * If a parameter is provided, returns the sound object; otherwise returns the current setting.
///
/// Notes:
///  * If remove the sound name by specifying `nil`, the sound will automatically be set to stop when Hammerspoon is reloaded.
static int sound_name(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    HSSoundObject *obj = [skin luaObjectAtIndex:1 toClass:"HSSoundObject"] ;
    if (lua_gettop(L) == 2) {
        if (lua_isnil(L,2)) {
            [obj.soundObject setName:nil];
            obj.stopOnRelease = YES;
        } else {
            [obj.soundObject setName:[skin toNSObjectAtIndex:2]];
        }
        lua_pushvalue(L, 1) ;
    } else {
        [skin pushNSObject:[obj.soundObject name]] ;
    }
    return 1;
}

/// hs.sound:device([deviceUID]) -> soundObject | UID string
/// Method
/// Get or set the playback device to use for an `hs.sound` object
///
/// Parameters:
///  * deviceUID - An optional string containing the UID of an `hs.audiodevice` object to use for playback of this sound. Use an explicit nil to use the system's default device
///
/// Returns:
///  * If a parameter is provided, returns the sound object; otherwise returns the current setting.
///
/// Notes:
///  * To obtain the UID of a sound device, see `hs.audiodevice:uid()`
static int sound_device(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    NSSound *obj = [skin luaObjectAtIndex:1 toClass:"NSSound"] ;
    if (lua_gettop(L) == 2) {
        if (lua_type(L, 2) == LUA_TNIL) {
            [obj setPlaybackDeviceIdentifier:nil] ;
        } else {
            luaL_checkstring(L, 2) ;
            @try {
                [obj setPlaybackDeviceIdentifier:[skin toNSObjectAtIndex:2]] ;
            } @catch(NSException *theException) {
                return luaL_error(L, [[NSString stringWithFormat:@"%@: %@", theException.name,
                                                                            theException.reason] UTF8String]);
            }
        }
        lua_pushvalue(L, 1) ;
    } else {
        [skin pushNSObject:[obj playbackDeviceIdentifier]];
    }
    return 1;
}

/// hs.sound:currentTime([seekTime]) -> soundObject | seconds
/// Method
/// Get or set the current seek offset within an `hs.sound` object.
///
/// Parameters:
///  * seekTime - An optional number of seconds to seek to within the sound object
///
/// Returns:
///  * If a parameter is provided, returns the sound object; otherwise returns the current position.
static int sound_currentTime(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    NSSound *obj = [skin luaObjectAtIndex:1 toClass:"NSSound"] ;
    if (lua_gettop(L) == 2) {
        [obj setCurrentTime:luaL_checknumber(L, 2)];
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushnumber(L, [obj currentTime]);
    }
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
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSSound *obj = [skin luaObjectAtIndex:1 toClass:"NSSound"] ;
    lua_pushnumber(L, [obj duration]);
    return 1;
}

/// hs.sound:volume([level]) -> soundObject | number
/// Method
/// Get or set the playback volume of an `hs.sound` object
///
/// Parameters:
///  * level - A number between 0.0 and 1.0, representing the volume of the sound object relative to the current system volume
///
/// Returns:
///  * If a parameter is provided, returns the sound object; otherwise returns the current value.
static int sound_volume(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    NSSound *obj = [skin luaObjectAtIndex:1 toClass:"NSSound"] ;
    if (lua_gettop(L) == 2) {
        [obj setVolume:(float)luaL_checknumber(L, 2)];
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushnumber(L, [obj volume]);
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
static int sound_isPlaying(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    NSSound *obj = [skin luaObjectAtIndex:1 toClass:"NSSound"] ;
    lua_pushboolean(L, [obj isPlaying]);
    return 1;
}

/// hs.sound:setCallback(function) -> soundObject
/// Method
/// Set or remove the callback for receiving completion notification for the sound object.
///
/// Parameters:
///  * function - A function which should be called when the sound completes playing.  Specify an explicit nil to remove the callback function.
///
/// Returns:
///  * the sound object
///
/// Notes:
///  * the callback function should accept two parameters and return none.  The parameters passed to the callback function are:
///    * state - a boolean flag indicating if the sound completed playing.  Returns true if playback completes properly, or false if a decoding error occurs or if the sound is stopped early with `hs.sound:stop`.
///    * sound - the soundObject userdata
static int sound_callback(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    HSSoundObject *obj = [skin luaObjectAtIndex:1 toClass:"HSSoundObject"] ;
    // in either case, we need to remove an existing callback, so...
    obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef];
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        obj.callbackRef = [skin luaRef:refTable];
        if (obj.selfRef == LUA_NOREF) {
            lua_pushvalue(L, 1) ;
            obj.selfRef = [skin luaRef:refTable];
        }
    } else {
        if (![obj.soundObject isPlaying]) {
            obj.selfRef = [skin luaUnref:refTable ref:obj.selfRef];
        }
    }
    lua_pushvalue(L, 1) ;
    return 1;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

// pushes HSSoundObject userdata onto stack, or reuses selfRef, if defined
static int pushHSSoundObject(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSSoundObject *value = obj ;
    if (value.selfRef != LUA_NOREF) {
        [skin pushLuaRef:refTable ref:value.selfRef] ;
    } else {
        void** valuePtr = lua_newuserdata(L, sizeof(HSSoundObject *));
        *valuePtr = (__bridge_retained void *)value;
        luaL_getmetatable(L, USERDATA_TAG);
        lua_setmetatable(L, -2);
    }
    return 1;
}

// retrieves userdata on stack as HSSoundObject
static id toHSSoundObjectFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSSoundObject *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSSoundObject, L, idx) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

// creates new HSSoundObject from NSSound and pushes userdata onto stack
static int pushNSSound(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSSoundObject *value = [[HSSoundObject alloc] initWithSound:obj] ;
    return [skin pushNSObject:value] ;
}

// retrieves userdata on stack as HSSoundObject, but returns NSSound portion only
static id toNSSoundFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSSoundObject *value = [skin luaObjectAtIndex:idx toClass:"HSSoundObject"];
    return [value soundObject];
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSSoundObject *obj = [skin luaObjectAtIndex:1 toClass:"HSSoundObject"] ;
    NSString *title = [obj.soundObject name] ;
    if (!title) title = @"(unnamed sound)" ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSSoundObject *obj1 = [skin luaObjectAtIndex:1 toClass:"HSSoundObject"] ;
        HSSoundObject *obj2 = [skin luaObjectAtIndex:2 toClass:"HSSoundObject"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
//     [skin logVerbose:[NSString stringWithFormat:@"%s:__gc", USERDATA_TAG]] ;
    HSSoundObject *obj = get_objectFromUserdata(__bridge_transfer HSSoundObject, L, 1) ;
    if (obj) {
        obj.selfRef     = [skin luaUnref:refTable ref:obj.selfRef] ;
        obj.callbackRef = [skin luaUnref:refTable ref:obj.callbackRef] ;
        [obj.soundObject setDelegate:nil] ;
        if (obj.stopOnRelease) [obj.soundObject stop] ;
        obj.soundObject = nil ;
        obj = nil ;
    }
    // Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;
    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"play",         sound_play},
    {"pause",        sound_pause},
    {"resume",       sound_resume},
    {"stop",         sound_stop},
    {"loopSound",    sound_loopSound},
    {"name",         sound_name},
    {"volume",       sound_volume},
    {"currentTime",  sound_currentTime},
    {"duration",     sound_duration},
    {"device",       sound_device},
    {"stopOnReload", sound_stopOnRelease},
    {"setCallback",  sound_callback},
    {"isPlaying",    sound_isPlaying},

    {"__tostring",   userdata_tostring},
    {"__eq",         userdata_eq},
    {"__gc",         userdata_gc},
    {NULL,           NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"soundTypes",          sound_soundUnfilteredTypes},
    {"soundFileTypes",      sound_soundUnfilteredFileTypes},
    {"getByName",           sound_byname},
    {"getByFile",           sound_byfile},
    {"systemSounds",        sound_systemSounds},
    {"getAudioEffectNames", sound_getAudioEffectNames},
    {NULL,              NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs_libsound(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    // pushes HSSoundObject userdata onto stack, or reuses selfRef, if defined
    [skin registerPushNSHelper:pushHSSoundObject         forClass:"HSSoundObject"];
    // retrieves userdata on stack as HSSoundObject
    [skin registerLuaObjectHelper:toHSSoundObjectFromLua forClass:"HSSoundObject"];

    // creates new HSSoundObject from NSSound and pushes userdata onto stack
    [skin registerPushNSHelper:pushNSSound         forClass:"NSSound"];
    // retrieves userdata on stack as HSSoundObject, but returns NSSound portion only; also
    // makes this the default for the USERDATA type, since I doubt there will be much call
    // for HSSoundObject outside of this specific module, but may for NSSound in array's, etc.
    [skin registerLuaObjectHelper:toNSSoundFromLua forClass:"NSSound" withUserdataMapping:USERDATA_TAG] ;

    return 1;
}
