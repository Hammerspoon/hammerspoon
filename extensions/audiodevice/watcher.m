#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioToolbox.h>
#import <Foundation/Foundation.h>
#import <LuaSkin/LuaSkin.h>
#import "math.h"

/// === hs.audiodevice.watcher ===
///
/// Watch for system level audio hardware events

#pragma mark - Library defines

// Define a datatype for hs.audiodevice.watcher objects
typedef struct _audiodevice_watcher_t {
    int callback;
    BOOL running;
    LSGCCanary lsCanary;
} audiodevice_watcher;

const AudioObjectPropertySelector watchSelectors[] = {
    kAudioHardwarePropertyDevices,
    kAudioHardwarePropertyDefaultInputDevice,
    kAudioHardwarePropertyDefaultOutputDevice,
    kAudioHardwarePropertyDefaultSystemOutputDevice,
};

static LSRefTable refTable;
static audiodevice_watcher *theWatcher = nil;

#pragma mark - Function definitions

static int audiodevicewatcher_setCallback(lua_State *L);
static int audiodevicewatcher_start(lua_State *L);
static int audiodevicewatcher_stop(lua_State *L);

#pragma mark - CoreAudio helper functions

OSStatus audiodevicewatcher_callback(AudioDeviceID deviceID, UInt32 numAddresses, const AudioObjectPropertyAddress addressList[], void *clientData) {
    NSMutableArray *events = [[NSMutableArray alloc] init];
    for (UInt32 i = 0; i < numAddresses; i++) {
        [events addObject:(__bridge_transfer NSString *)UTCreateStringForOSType(addressList[i].mSelector)];
    }

    dispatch_async(dispatch_get_main_queue(), ^{

        //NSLog(@"%i addresses to check", numAddresses);
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];

        if (!theWatcher) {
            [skin logWarn:@"hs.audiodevice.watcher callback fired, but theWatcher is nil. This is a bug"];
            return;
        }

        if (![skin checkGCCanary:theWatcher->lsCanary]) {
            return;
        }
        _lua_stackguard_entry(skin.L);

        if (theWatcher->callback == LUA_NOREF) {
            [skin logWarn:@"hs.audiodevice.watcher callback fired, but there is no callback. This is a bug"];
        } else {
            for (NSString *event in events) {
                [skin pushLuaRef:refTable ref:theWatcher->callback];
                [skin pushNSObject:event];
                [skin protectedCallAndError:@"hs.audiodevice.watcher callback" nargs:1 nresults:0];
            }
        }
        _lua_stackguard_exit(skin.L);
    });
    return noErr;
}

#pragma mark - hs.audiodevice.watcher library functions

/// hs.audiodevice.watcher.setCallback(fn)
/// Function
/// Sets the callback function for the audio device watcher
///
/// Parameters:
///  * fn - A callback function, or nil to remove a previously set callback. The callback function should accept a single argument (see Notes below)
///
/// Returns:
///  * None
///
/// Notes:
///  * This watcher will call the callback when various audio device related events occur (e.g. an audio device appears/disappears, a system default audio device setting changes, etc)
///  * To watch for changes within an audio device, see `hs.audiodevice:newWatcher()`
///  * The callback function argument is a string which may be one of the following strings, but might also be a different string entirely:
///   * dIn  - Default audio input device setting changed (Note that there is a space character after `dIn`, because these values always have to be four characters long)
///   * dOut - Default audio output device setting changed
///   * sOut - Default system audio output setting changed (i.e. the device that system sound effects use. This may also be triggered by dOut, depending on the user's settings)
///   * dev# - An audio device appeared or disappeared
///  * The callback will be called for each individual audio device event received from the OS, so you may receive multiple events for a single physical action (e.g. unplugging the default audio device will cause `dOut` and `dev#` events, and possibly `sOut` too)
///  * Passing nil will cause the watcher to stop if it is already running
static int audiodevicewatcher_setCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION|LS_TNIL, LS_TBREAK];

    if (!theWatcher) {
        theWatcher = malloc(sizeof(audiodevice_watcher));
        memset(theWatcher, 0, sizeof(audiodevice_watcher));
        theWatcher->running = NO;
        theWatcher->callback = LUA_NOREF;
        theWatcher->lsCanary = [skin createGCCanary];
    }

    theWatcher->callback = [skin luaUnref:refTable ref:theWatcher->callback];

    switch (lua_type(L, 1)) {
        case LUA_TFUNCTION:
            lua_pushvalue(L, 1);
            theWatcher->callback = [skin luaRef:refTable];
            break;

        case LUA_TNIL:
            audiodevicewatcher_stop(L);
            break;

        default:
            break;
    }

    return 0;
}

/// hs.audiodevice.watcher.start()
/// Function
/// Starts the audio device watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int audiodevicewatcher_start(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    if (!theWatcher || theWatcher->callback == LUA_NOREF) {
        [skin logError:@"You must call hs.audiodevice.watcher.setCallback() before hs.audiodevice.watcher.start()"];
        return 0;
    }

    if (theWatcher->running == YES) {
        return 0;
    }

    AudioObjectPropertyAddress propertyAddress = {
        0,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMaster
    };

    const int numSelectors = sizeof(watchSelectors) / sizeof(watchSelectors[0]);

    for (int i = 0; i < numSelectors; i++) {
        propertyAddress.mSelector = watchSelectors[i];
        AudioObjectAddPropertyListener(kAudioObjectSystemObject, &propertyAddress, audiodevicewatcher_callback, nil);
    }

    theWatcher->running = YES;

    return 0;
}

/// hs.audiodevice.watcher.stop() -> hs.audiodevice.watcher
/// Function
/// Stops the audio device watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.audiodevice.watcher` object
static int audiodevicewatcher_stop(lua_State *L) {
    if (!theWatcher || theWatcher->running == NO) {
        return 0;
    }

    AudioObjectPropertyAddress propertyAddress = {
        0,
        kAudioObjectPropertyScopeWildcard,
        kAudioObjectPropertyElementWildcard
    };

    const int numSelectors = sizeof(watchSelectors) / sizeof(watchSelectors[0]);

    for (int i = 0; i < numSelectors; i++) {
        propertyAddress.mSelector = watchSelectors[i];
        AudioObjectRemovePropertyListener(kAudioObjectSystemObject, &propertyAddress, &audiodevicewatcher_callback, nil);
    }

    theWatcher->running = NO;

    return 0;
}

/// hs.audiodevice.watcher.isRunning() -> boolean
/// Function
/// Gets the status of the audio device watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, true if the watcher is running, false if not
static int audiodevicewatcher_isRunning(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    if (!theWatcher) {
        lua_pushboolean(L, false);
        return 1;
    }

    lua_pushboolean(L, theWatcher->running);
    return 1;
}

static int audiodevicewatcher_gc(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    if (theWatcher) {
        audiodevicewatcher_stop(L);
        theWatcher->callback = [skin luaUnref:refTable ref:theWatcher->callback];
        [skin destroyGCCanary:&(theWatcher->lsCanary)];
        free(theWatcher);
        theWatcher = nil;
    }

    return 0;
}

#pragma mark - Library initialisation

// Metatable for audiodevice watcher objects
static const luaL_Reg audiodevicewatcherLib[] = {
    {"setCallback",             audiodevicewatcher_setCallback},
    {"start",                   audiodevicewatcher_start},
    {"stop",                    audiodevicewatcher_stop},
    {"isRunning",               audiodevicewatcher_isRunning},

    {NULL, NULL}
};

static const luaL_Reg metaLib[] = {
    {"__gc",                    audiodevicewatcher_gc},

    {NULL, NULL}
};

int luaopen_hs_audiodevice_watcher(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibrary:"hs.audiodevice.watcher" functions:audiodevicewatcherLib metaFunctions:metaLib];
    return 1;
}
