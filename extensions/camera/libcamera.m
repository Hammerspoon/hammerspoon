@import Cocoa;
@import AVFoundation;
@import CoreMediaIO;
#import <LuaSkin/LuaSkin.h>

#pragma mark - Module declarations
#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))
static LSRefTable refTable;
static const char *USERDATA_TAG = "hs.camera";


#pragma mark - Devices watcher declarations
typedef struct _deviceWatcher_t {
    int callback;
    BOOL running;
    LSGCCanary lsCanary;
} deviceWatcher_t;
static deviceWatcher_t *deviceWatcher = nil;
static id deviceWatcherAddedObserver = nil;
static id deviceWatcherRemovedObserver = nil;


#pragma mark - Device property watcher declarations
static const CMIOObjectPropertySelector propertyWatchSelectors[] = {
    kAudioDevicePropertyDeviceHasChanged,
    kAudioDevicePropertyDeviceIsRunningSomewhere
};


#pragma mark - HSCamera declaration
@interface HSCamera : NSObject
@property(nonatomic) CMIODeviceID deviceId;
@property(nonatomic) NSString *name;
@property(nonatomic) NSString *uid;
@property(nonatomic, readonly, getter=getIsInUse) BOOL isInUse;
@property(nonatomic) int propertyWatcherCallback;
@property(nonatomic) BOOL propertyWatcherRunning;
@property(nonatomic) CMIOObjectPropertyListenerBlock propertyWatcherBlock;
@property(nonatomic) LSGCCanary canary;

- (id)initWithDeviceID:(CMIODeviceID)deviceId;
- (NSString *)getCameraName;
- (NSString *)getCameraUID;
- (void)wasRemoved;
- (void)stopPropertyWatcher;
- (void)startPropertyWatcher;
@end


#pragma mark - HSCameraManager declaration
@interface HSCameraManager : NSObject
@property(nonatomic) NSMutableArray<HSCamera *>* cameraCache;

- (NSArray<HSCamera*>*) getCameras;
- (HSCamera *)cameraForDeviceID:(CMIODeviceID)deviceId;
- (void)deviceRemoved:(CMIODeviceID)deviceId;
- (void)drainCache;
@end

static HSCameraManager *cameraManager = nil;


#pragma mark - HSCamera implementation
@implementation HSCamera
- (id)initWithDeviceID:(CMIODeviceID) deviceId {
    self = [super init];
    if (self) {
        NSLog(@"HSCamera init: %@ (%d)", self, deviceId);
        LuaSkin *skin = [LuaSkin sharedWithState:NULL];

        self.deviceId = deviceId;
        self.propertyWatcherCallback = LUA_NOREF;
        self.propertyWatcherRunning = NO;
        self.canary = [skin createGCCanary];
        self.uid = [self getCameraUID];
        self.name = [self getCameraName];

        __weak HSCamera *weakSelf = self;
        self.propertyWatcherBlock = ^(UInt32 numberAddresses, const CMIOObjectPropertyAddress *addresses) {
            NSMutableArray *events = [[NSMutableArray alloc] init];

            for (UInt32 i = 0; i < numberAddresses; i++) {
                NSString *mSelector = (__bridge_transfer NSString *)UTCreateStringForOSType(addresses[i].mSelector);
                NSString *mScope = (__bridge_transfer NSString *)UTCreateStringForOSType(addresses[i].mScope);
                NSNumber *mElement = [NSNumber numberWithInt:addresses[i].mElement];
                [events addObject:@{@"mSelector":mSelector, @"mScope":mScope, @"mElement":mElement}];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                LuaSkin *skin = [LuaSkin sharedWithState:NULL];
                if (![skin checkGCCanary:weakSelf.canary]) {
                    return;
                }

                _lua_stackguard_entry(skin.L);
                if (self.propertyWatcherCallback == LUA_NOREF) {
                    [skin logError:@"hs.camera property watcher fired, but no callback has been set"];
                } else {
                    for (NSDictionary *event in events) {
                        [skin pushLuaRef:refTable ref:weakSelf.propertyWatcherCallback];
                        [skin pushNSObject:weakSelf];
                        [skin pushNSObject:event[@"mSelector"]];
                        [skin pushNSObject:event[@"mScope"]];
                        [skin pushNSObject:event[@"mElement"]];

                        [skin protectedCallAndError:@"hs.camera:propertyWatcherCallback" nargs:4 nresults:0];
                    }
                }
                _lua_stackguard_exit(skin.L);
            });
        };
    }
    return self;
}

- (void)dealloc {
    NSLog(@"HSCamera dealloc: %@", self);
    [self wasRemoved];
    [[LuaSkin sharedWithState:NULL] destroyGCCanary:&_canary];
}

- (void)wasRemoved {
    [self stopPropertyWatcher];
}

- (void)startPropertyWatcher {
    if (self.propertyWatcherRunning == YES) {
        return;
    }

    CMIOObjectPropertyAddress propertyAddress = {
        0,
        kAudioObjectPropertyScopeWildcard,
        kAudioObjectPropertyElementWildcard
    };

    const int numSelectors = sizeof(propertyWatchSelectors) / sizeof(propertyWatchSelectors[0]);

    for (int i = 0; i < numSelectors; i++) {
        propertyAddress.mSelector = propertyWatchSelectors[i];
        CMIOObjectAddPropertyListenerBlock(self.deviceId,
                                           &propertyAddress,
                                           dispatch_get_main_queue(),
                                           self.propertyWatcherBlock);
    }

    self.propertyWatcherRunning = YES;
}

- (void)stopPropertyWatcher {
    if (self.propertyWatcherRunning == NO) {
        return;
    }

    CMIOObjectPropertyAddress propertyAddress = {
        0,
        kAudioObjectPropertyScopeWildcard,
        kAudioObjectPropertyElementWildcard
    };

    const int numSelectors = sizeof(propertyWatchSelectors) / sizeof(propertyWatchSelectors[0]);

    for (int i = 0; i < numSelectors; i++) {
        propertyAddress.mSelector = propertyWatchSelectors[i];
        CMIOObjectRemovePropertyListenerBlock(self.deviceId,
                                              &propertyAddress,
                                              dispatch_get_main_queue(),
                                              self.propertyWatcherBlock);
    }

    self.propertyWatcherRunning = NO;
}

- (NSString *)getCameraUID {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    OSStatus err;
    UInt32 dataSize = 0;
    UInt32 dataUsed = 0;

    CMIOObjectPropertyAddress prop = {kCMIODevicePropertyDeviceUID,
        kCMIOObjectPropertyScopeWildcard,
        kCMIOObjectPropertyElementWildcard};

    err = CMIOObjectGetPropertyDataSize(self.deviceId, &prop, 0, nil, &dataSize);
    if (err != kCMIOHardwareNoError) {
        [skin logError:[NSString stringWithFormat:@"getUID: Unable to get data size: %d", err]];
        return nil;
    }

    CFStringRef uidStringRef = NULL;
    err = CMIOObjectGetPropertyData(self.deviceId, &prop, 0, nil, dataSize, &dataUsed,
                                    &uidStringRef);
    if (err != kCMIOHardwareNoError) {
        [skin logError:[NSString stringWithFormat:@"getUID: Unable to get data: %d", err]];
        return nil;
    }

    return (__bridge NSString *)uidStringRef;
}

- (NSString *)getCameraName {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    AVCaptureDevice *avDevice = [AVCaptureDevice deviceWithUniqueID:self.uid];
    if (!avDevice) {
        [skin logWarn:[NSString stringWithFormat:@"Unable to get camera name for: %@", self.uid]];
        return nil;
    }
    return avDevice.localizedName;
}

- (BOOL)getIsInUse {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    OSStatus err;
    UInt32 dataSize = 0;
    UInt32 dataUsed = 0;
    UInt32 isInUse = 0;

    CMIOObjectPropertyAddress prop = {kCMIODevicePropertyDeviceIsRunningSomewhere,
                                      kCMIOObjectPropertyScopeWildcard,
                                      kCMIOObjectPropertyElementWildcard};

    err = CMIOObjectGetPropertyDataSize(self.deviceId, &prop, 0, nil, &dataSize);
    if (err != kCMIOHardwareNoError) {
        [skin logError:[NSString stringWithFormat:@"getVideoDeviceIsUsed(): get data size error: %d", err]];
        return NO;
    }

    err = CMIOObjectGetPropertyData(self.deviceId, &prop, 0, nil, dataSize, &dataUsed, &isInUse);
    if (err != kCMIOHardwareNoError) {
        [skin logError:[NSString stringWithFormat:@"getVideoDeviceIsUsed(): get data error: %d", err]];
        return NO;
    }

    return isInUse;
}
@end

#pragma mark - HSCameraManager implementation
@implementation HSCameraManager
- (id)init {
    self = [super init];
    if (self) {
        self.cameraCache = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
    self.cameraCache = nil;
}

- (HSCamera *)cameraForDeviceID:(CMIODeviceID)deviceId {
    HSCamera *camera = nil;

    // Check if we already have this device cached
    for (HSCamera *device in self.cameraCache) {
        if (device.deviceId == deviceId) {
            // Found it, return the cached object
            return device;
        }
    }

    // We don't have this camera cached, so create a new object and cache it.
    camera = [[HSCamera alloc] initWithDeviceID:deviceId];
    [self.cameraCache addObject:camera];

    return camera;
}

- (void)deviceRemoved:(CMIODeviceID)deviceId {
    for (HSCamera *device in self.cameraCache) {
        if (device.deviceId == deviceId) {
            [device wasRemoved];
            [self.cameraCache removeObject:device];
            return;
        }
    }
}

- (void)drainCache {
    self.cameraCache = [[NSMutableArray alloc] init];
}

- (NSArray<HSCamera*>*) getCameras {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    NSMutableArray *cameras = [[NSMutableArray alloc] init];
    OSStatus err;
    UInt32 dataSize = 0;
    CMIOObjectPropertyAddress prop = {
        kCMIOHardwarePropertyDevices,
        kCMIOObjectPropertyScopeGlobal,
        kCMIOObjectPropertyElementMaster
    };

    // Get the number of cameras
    UInt32 numCameras = 0;

    err = CMIOObjectGetPropertyDataSize(kCMIOObjectSystemObject, &prop, 0, nil, &dataSize);
    if (err != kCMIOHardwareNoError) {
        [skin logError:[NSString stringWithFormat:@"Unable to fetch camera device count: %d", err]];
        return @[];
    }
    numCameras = (UInt32) dataSize / sizeof(CMIODeviceID);

    // Get the camera devices
    UInt32 dataUsed = 0;
    CMIODeviceID *cameraList = (CMIODeviceID *) calloc(numCameras, sizeof(CMIODeviceID));
    err = CMIOObjectGetPropertyData(kCMIOObjectSystemObject, &prop, 0, nil, dataSize, &dataUsed, cameraList);
    if (err != kCMIOHardwareNoError) {
        free(cameraList);
        [skin logError:[NSString stringWithFormat:@"Unable to fetch camera devices: %d", err]];
        return @[];
    }

    // Prepare the array
    for (UInt32 i = 0; i < numCameras; i++) {
        CMIOObjectID cameraID = cameraList[i];
        HSCamera *camera = [cameraManager cameraForDeviceID:cameraID];
        [cameras addObject:camera];
    }

    NSArray *immutableCameras = [cameras copy];
    free(cameraList);
    return immutableCameras;
}
@end

#pragma mark - Lua API
/// hs.camera.allCameras() -> table
/// Function
/// Get all the cameras known to the system
///
/// Parameters:
///  * None
///
/// Returns:
///  * A table containing all of the known cameras
static int allCameras(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    [skin pushNSObject:[cameraManager getCameras]];
    return 1;
}

// NOTE: Private API used here
@interface AVCaptureDevice (PrivateAPI)
- (CMIODeviceID)connectionID;
@end

// This calls the devices watcher callback Lua function when a device is added/removed
void deviceWatcherDoCallback(CMIODeviceID deviceId, NSString *event) {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];

    if (!deviceWatcher) {
        [skin logWarn:@"hs.camera devices watcher callback fired, but deviceWatcher is nil. This is a bug"];
        return;
    }

    if (![skin checkGCCanary:deviceWatcher->lsCanary]) {
        return;
    }
    _lua_stackguard_entry(skin.L);

    if (deviceWatcher->callback == LUA_NOREF) {
        [skin logWarn:@"hs.camera devices watcher callback fired, but there is no callback. This is a bug"];
        return;
    }

    [skin pushLuaRef:refTable ref:deviceWatcher->callback];
    [skin pushNSObject:[cameraManager cameraForDeviceID:deviceId]];
    [skin pushNSObject:event];
    [skin protectedCallAndError:@"hs.camera devices callback" nargs:2 nresults:0];

    _lua_stackguard_exit(skin.L);
}

/// hs.camera.startWatcher()
/// Function
/// Starts the camera devices watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int startWatcher(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    if (!deviceWatcher || deviceWatcher->callback == LUA_NOREF) {
        [skin logError:@"You must call hs.camera.setWatcherCallback() before hs.camera.startWatcher()"];
        return 0;
    }

    if (deviceWatcher->running == YES) {
        return 0;
    }

    // For some reason, the device added/removed notifications don't fire unless we ask macOS to enumerate the devices first
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [AVCaptureDevice devices];
#pragma clang diagnostic pop

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    deviceWatcherAddedObserver = [center addObserverForName:AVCaptureDeviceWasConnectedNotification
                                                object:nil
                                                 queue:[NSOperationQueue mainQueue]
                                            usingBlock:^(NSNotification * _Nonnull note) {
        AVCaptureDevice *device = [note object];
        if ([device hasMediaType:AVMediaTypeVideo]) {
            CMIODeviceID deviceId = device.connectionID;
            dispatch_async(dispatch_get_main_queue(), ^{
                deviceWatcherDoCallback(deviceId, @"Added");
            });
        }
    }];
    deviceWatcherRemovedObserver = [center addObserverForName:AVCaptureDeviceWasDisconnectedNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        AVCaptureDevice *device = [note object];
        if ([device hasMediaType:AVMediaTypeVideo]) {
            CMIODeviceID deviceId = device.connectionID;
            dispatch_async(dispatch_get_main_queue(), ^{
                deviceWatcherDoCallback(deviceId, @"Removed");
                [cameraManager deviceRemoved:deviceId];
            });
        }
    }];

    NSLog(@"startWatcher: got objects: %@, %@", deviceWatcherAddedObserver, deviceWatcherRemovedObserver);
    deviceWatcher->running = YES;
    return 0;
}

/// hs.camera.stopWatcher()
/// Function
/// Stops the camera devices watcher
///
/// Parameters:
///  * None
///
/// Returns:
///  * None
static int stopWatcher(lua_State *L) {
    // This is an ugly hack so we can call this from elsewhere without checkArgs exploding
    if (L) {
        LuaSkin *skin = [LuaSkin sharedWithState:L];
        [skin checkArgs:LS_TBREAK];
    }

    if (!deviceWatcher) {
        return 0;
    }

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center removeObserver:deviceWatcherAddedObserver
                      name:AVCaptureDeviceWasConnectedNotification
                    object:nil];
    [center removeObserver:deviceWatcherRemovedObserver
                      name:AVCaptureDeviceWasDisconnectedNotification
                    object:nil];

    deviceWatcher->running = NO;

    return 0;
}

/// hs.camera.isWatcherRunning() -> Boolean
/// Function
/// Checks if the camera devices watcher is running
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, True if the watcher is running, otherwise False
static int isWatcherRunning(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    lua_pushboolean(L, deviceWatcher && deviceWatcher->running);

    return 1;
}

/// hs.camera.setWatcherCallback(fn)
/// Function
/// Sets/clears the callback function for the camera devices watcher
///
/// Parameters:
///  * fn - A callback function, or nil to remove a previously set callback. The callback should accept a two arguments (see Notes below)
///
/// Returns:
///  * None
///
/// Notes:
///  * The callback will be called when a camera is added or removed from the system
///  * To watch for changes within a single camera device, see `hs.camera:newWatcher()`
///  * The callback function arguments are:
///   * An hs.camera device object for the affected device
///   * A string, either "Added" or "Removed" depending on whether the device was added or removed from the system
///  * For "Removed" events, most methods on the hs.camera device object will not function correctly anymore and the device object passed to the callback is likely to be useless. It is recommended you re-check `hs.camera.allCameras()` and keep records of the cameras you care about
///  * Passing nil will cause the watcher to stop if it is running
static int setWatcherCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TFUNCTION|LS_TNIL, LS_TBREAK];

    if (!deviceWatcher) {
        deviceWatcher = malloc(sizeof(deviceWatcher_t));
        memset(deviceWatcher, 0, sizeof(deviceWatcher_t));
        deviceWatcher->running = NO;
        deviceWatcher->callback = LUA_NOREF;
        deviceWatcher->lsCanary = [skin createGCCanary];
    }

    deviceWatcher->callback = [skin luaUnref:refTable ref:deviceWatcher->callback];

    switch (lua_type(L, 1)) {
        case LUA_TFUNCTION:
            lua_pushvalue(L, 1);
            deviceWatcher->callback = [skin luaRef:refTable];
            break;
        case LUA_TNIL:
            stopWatcher(NULL);
            break;
        default:
            break;
    }

    return 0;
}

/// hs.camera:uid() -> String
/// Method
/// Get the UID of the camera
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the UID of the camera
///
/// Notes:
///  * The UID is not guaranteed to be stable across reboots
static int camera_uid(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSCamera *camera = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:camera.uid];
    return 1;
}

/// hs.camera:connectionID() -> String
/// Method
/// Get the raw connection ID of the camera
///
/// Parameters:
///  * None
///
/// Returns:
///  * A number containing the connection ID of the camera
static int camera_cID(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSCamera *camera = [skin toNSObjectAtIndex:1];
    lua_pushinteger(L, camera.deviceId);
    return 1;
}

/// hs.camera:name() -> String
/// Method
/// Get the name of the camera
///
/// Parameters:
///  * None
///
/// Returns:
///  * A string containing the name of the camera
static int camera_name(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSCamera *camera = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:camera.name];
    return 1;
}

/// hs.camera:isInUse() -> Boolean
/// Method
/// Get the usage status of the camera
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, True if the camera is in use, otherwise False
static int camera_isinuse(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSCamera *camera = [skin toNSObjectAtIndex:1];
    lua_pushboolean(L, camera.isInUse);
    return 1;
}

/// hs.camera:setPropertyWatcherCallback(fn) -> hs.camera object
/// Method
/// Sets or clears a callback for when the properties of an hs.camera object change
///
/// Parameters:
///  * fn - A function to be called when properites of the camera change, or nil to clear a previously set callback. The function should accept the following parameters:
///   * The hs.camera object that changed
///   * A string describing the property that changed. Possible values are:
///    * gone - The device's "in use" status changed (ie another app started using the camera, or stopped using it)
///   * A string containing the scope of the event, this will likely always be "glob"
///   * A number containing the element of the event, this will likely always be "0"
///
/// Returns:
///  * The `hs.camera` object
static int camera_propertyWatcherCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION|LS_TNIL, LS_TBREAK];

    HSCamera *camera = [skin toNSObjectAtIndex:1];
    camera.propertyWatcherCallback = [skin luaUnref:refTable ref:camera.propertyWatcherCallback];

    switch (lua_type(L, 2)) {
        case LUA_TFUNCTION:
            lua_pushvalue(L, 2);
            camera.propertyWatcherCallback = [skin luaRef:refTable];
            break;
        case LUA_TNIL:
            break;
        default:
            break;
    }

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.camera:startPropertyWatcher()
/// Method
/// Starts the property watcher on a camera
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.camera` object
static int camera_startPropertyWatcher(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];

    HSCamera *camera = [skin toNSObjectAtIndex:1];

    if (camera.propertyWatcherCallback == LUA_NOREF) {
        [skin logError:@"You must call hs.camera:setPropertyWatcherCallback() before hs.camera:startPropertyWatcher()"];
        lua_pushnil(L);
        return 1;
    }

    [camera startPropertyWatcher];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.camera:stopPropertyWatcher()
/// Method
/// Stops the property watcher on a camera
///
/// Parameters:
///  * None
///
/// Returns:
///  * The `hs.camera` object
static int camera_stopPropertyWatcher(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSCamera *camera = [skin toNSObjectAtIndex:1];

    [camera stopPropertyWatcher];

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.camera:isPropertyWatcherRunning() -> bool
/// Method
/// Checks if the property watcher on a camera object is running
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean, True if the property watcher is running, otherwise False
static int camera_isPropertyWatcherRunning(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSCamera *camera = [skin toNSObjectAtIndex:1];

    lua_pushboolean(L, camera.propertyWatcherRunning);
    return 1;
}

#pragma mark - Lua<->NSObject Conversion Functions
static int pushHSCamera(lua_State *L, id obj) {
    HSCamera *value = obj;
    void** valuePtr = lua_newuserdata(L, sizeof(HSCamera *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSCameraFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    HSCamera *value;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSCamera, L, idx, USERDATA_TAG);
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG, lua_typename(L, lua_type(L, idx))]];
    }
    return value;
}

#pragma mark - Core Lua metamethods
static int hsCamera_tostring(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    HSCamera *camera = [skin toNSObjectAtIndex:1];
    [skin pushNSObject:[NSString stringWithFormat:@"%s: (%@:%@)", USERDATA_TAG, camera.uid, camera.name]];
    return 1;
}

static int hsCamera_eq(lua_State *L) {
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSCamera *obj1 = [skin luaObjectAtIndex:1 toClass:"HSCamera"] ;
        HSCamera *obj2 = [skin luaObjectAtIndex:2 toClass:"HSCamera"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int hsCamera_gc(lua_State *L) {
    lua_pushnil(L);
    lua_setmetatable(L, 1);
    return 0;
}

static int module_gc(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    if (deviceWatcher) {
        stopWatcher(NULL);
        deviceWatcher->callback = [skin luaUnref:refTable ref:deviceWatcher->callback];
        [skin destroyGCCanary:&(deviceWatcher->lsCanary)];
        free(deviceWatcher);
        deviceWatcher = nil;
    }

    for (HSCamera *camera in cameraManager.cameraCache) {
        [camera wasRemoved];
    }
    [cameraManager drainCache];
    cameraManager = nil;

    return 0;
}

#pragma mark - HSCamera userdata methods
static const luaL_Reg cameraDeviceLib[] = {
    {"uid", camera_uid},
    {"connectionID", camera_cID},
    {"name", camera_name},
    {"isInUse", camera_isinuse},
    {"setPropertyWatcherCallback", camera_propertyWatcherCallback},
    {"startPropertyWatcher", camera_startPropertyWatcher},
    {"stopPropertyWatcher", camera_stopPropertyWatcher},
    {"isPropertyWatcherRunning", camera_isPropertyWatcherRunning},

    {"__tostring", hsCamera_tostring},
    {"__eq",       hsCamera_eq},
    {"__gc",       hsCamera_gc},
    {NULL, NULL}
};

#pragma mark - module functions
static const luaL_Reg cameraLib[] = {
    {"allCameras", allCameras},
    {"setWatcherCallback", setWatcherCallback},
    {"startWatcher", startWatcher},
    {"stopWatcher", stopWatcher},
    {"isWatcherRunning", isWatcherRunning},

    {NULL, NULL}
};
static const luaL_Reg cameraLibMeta[] = {
    {"__gc", module_gc},
    {NULL, NULL}
};

#pragma mark - Lua initialisation
int luaopen_hs_libcamera(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    cameraManager = [[HSCameraManager alloc] init];

    refTable = [skin registerLibrary:USERDATA_TAG functions:cameraLib metaFunctions:cameraLibMeta];

    [skin registerObject:USERDATA_TAG objectFunctions:cameraDeviceLib];
    [skin registerPushNSHelper:pushHSCamera forClass:"HSCamera"];
    [skin registerLuaObjectHelper:toHSCameraFromLua forClass:"HSCamera" withUserdataMapping:USERDATA_TAG];

    return 1;
}
