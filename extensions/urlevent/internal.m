#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <CoreServices/CoreServices.h>
#import <LuaSkin/LuaSkin.h>
#import "../../Hammerspoon/MJAppDelegate.h"
#import "../hammerspoon.h"

int refTable;
NSMutableDictionary *restoreHandlers;

// ----------------------- Objective C ---------------------

@interface HSURLEventHandler : NSObject
@property (nonatomic, strong) NSAppleEventManager *appleEventManager;
- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent: (NSAppleEventDescriptor *)replyEvent;
- (void)gc;
@end

static HSURLEventHandler *eventHandler;
static int fnCallback;

@implementation HSURLEventHandler
- (id)init {
    self = [super init];
    if (self) {
        self.appleEventManager = [NSAppleEventManager sharedAppleEventManager];
        [self.appleEventManager setEventHandler:self
                               andSelector:@selector(handleAppleEvent:withReplyEvent:)
                             forEventClass:kInternetEventClass
                                andEventID:kAEGetURL];
    }
    return self;
}

- (void)gc {
    [self.appleEventManager removeEventHandlerForEventClass:kInternetEventClass
                                                 andEventID:kAEGetURL];
}

- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent: (NSAppleEventDescriptor * __unused)replyEvent {
    LuaSkin *skin = [LuaSkin shared];
    lua_State *L = skin.L;

    if (fnCallback == LUA_NOREF) {
        // Lua hasn't registered a callback. This possibly means we have been require()'d as hs.urlevent.internal and not set up properly. Weird. Refuse to do anything
        printToConsole(skin.L, "hs.urlevent handleAppleEvent:: No fnCallback has been set by Lua");
        return;
    }

    // Split the URL into its components
    NSURL *url = [NSURL URLWithString:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]];
    NSString *query = [url query];
    NSArray *queryPairs = [query componentsSeparatedByString:@"&"];
    NSMutableDictionary *pairs = [NSMutableDictionary dictionary];
    for (NSString *queryPair in queryPairs) {
        NSArray *bits = [queryPair componentsSeparatedByString:@"="];
        if ([bits count] != 2) { continue; }

        NSString *key = [[bits objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *value = [[bits objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];

        [pairs setObject:value forKey:key];
    }

    NSArray *keys = [pairs allKeys];
    NSArray *values = [pairs allValues];

    [skin pushLuaRef:refTable ref:fnCallback];
    lua_pushstring(L, [[url scheme] UTF8String]);
    lua_pushstring(L, [[url host] UTF8String]);
    lua_newtable(L);
    for (int i = 0; i < (int)[keys count]; i++) {
        // Push each URL parameter into the params table
        lua_pushstring(L, [[keys objectAtIndex:i] UTF8String]);
        lua_pushstring(L, [[values objectAtIndex:i] UTF8String]);
        lua_settable(L, -3);
    }
    lua_pushstring(L, [[url absoluteString] UTF8String]);

    if (![skin protectedCallAndTraceback:4 nresults:0]) {
        const char *errorMsg = lua_tostring(L, -1);
        CLS_NSLOG(@"%s", errorMsg);
        showError(L, (char *)errorMsg);
    }
}
@end

// ----------------------- C ---------------------

// Rather than manage complex callback state from C, we just have one path into Lua for all events, and events are directed to their callbacks from there
static int urleventSetCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];

    luaL_checktype(L, 1, LUA_TFUNCTION);
    lua_pushvalue(L, 1);
    fnCallback = [skin luaRef:refTable];

    MJAppDelegate *delegate = (MJAppDelegate *)[[NSApplication sharedApplication] delegate];

    if (delegate.startupEvent) {
        [eventHandler handleAppleEvent:delegate.startupEvent withReplyEvent:nil];
    }

    return 0;
}

/// hs.urlevent.setRestoreHandler(scheme, bundleID)
/// Function
/// Stores a URL handler that will be restored when Hammerspoon or reloads its config
///
/// Parameters:
///  * scheme - A string containing the URL scheme to change. This must be 'http' (although both http:// and https:// URLs will be affected)
///  * bundleID - A string containing an application bundle identifier (e.g. 'com.apple.Safari') for the application to set as the default handler when Hammerspoon exits or reloads its config
///
/// Returns:
///  * None
///
/// Notes:
///  * You don't have to call this function if you want Hammerspoon to permanently be your default handler. Only use this if you want the handler to be automatically reverted to something else when Hammerspoon exits/reloads.
static int urleventsetRestoreHandler(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TBREAK];

    CFStringRef scheme = CFStringCreateWithCString(NULL, lua_tostring(L, 1), kCFStringEncodingUTF8);
    [restoreHandlers setObject:[NSString stringWithUTF8String:lua_tostring(L, 2)] forKey:(__bridge NSString*)(scheme)];
    CFRelease(scheme);

    return 0;
}

/// hs.urlevent.setDefaultHandler(scheme[, bundleID])
/// Function
/// Sets the default system handler for URLs of a given scheme
///
/// Parameters:
///  * scheme - A string containing the URL scheme to change. This must be 'http' or 'https' (although entering either will restore the default for both)
///  * bundleID - An optional string containing an application bundle identifier for the application to set as the default handler. Defaults to `org.hammerspoon.Hammerspoon`.
///
/// Returns:
///  * None
///
/// Notes:
///  * Changing the default handler for http/https URLs will display a system prompt asking the user to confirm the change
static int urleventsetDefaultHandler(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TSTRING|LS_TOPTIONAL, LS_TBREAK];

    CFStringRef scheme = CFStringCreateWithCString(NULL, lua_tostring(L, 1), kCFStringEncodingUTF8);
    NSString *bundleID;

    if (lua_type(L, 2) == LUA_TSTRING) {
        bundleID = [NSString stringWithUTF8String:lua_tostring(L, 2)];
    } else {
        bundleID = @"org.hammerspoon.Hammerspoon";
    }

    OSStatus status = LSSetDefaultHandlerForURLScheme(scheme, (__bridge CFStringRef)bundleID);
    if (status != noErr) {
        showError(L, (char *)[[[NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil] localizedDescription] UTF8String]);
    } else {
        [restoreHandlers removeObjectForKey:(__bridge NSString *)scheme];
    }

    // FIXME: Do we care about these:
    //LSSetDefaultRoleHandlerForContentType(kUTTypeHTML, kLSRolesViewer, (CFStringRef) [[NSBundle mainBundle] bundleIdentifier]);
    //LSSetDefaultRoleHandlerForContentType(kUTTypeURL, kLSRolesViewer, (CFStringRef) [[NSBundle mainBundle] bundleIdentifier]);
    //LSSetDefaultRoleHandlerForContentType(kUTTypeFileURL, kLSRolesViewer, (CFStringRef) [[NSBundle mainBundle] bundleIdentifier]);
    //LSSetDefaultRoleHandlerForContentType(kUTTypeText, kLSRolesViewer, (CFStringRef) [[NSBundle mainBundle] bundleIdentifier]);

    CFRelease(scheme);

    return 0;
}

/// hs.urlevent.getDefaultHandler(scheme) -> string
/// Function
/// Gets the application bundle identifier of the application currently registered to handle a URL scheme
///
/// Parameters:
///  * scheme - A string containing a URL scheme (e.g. 'http')
///
/// Returns:
///  * A string containing the bundle identifier of the current default application
static int urleventgetDefaultHandler(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];

    NSString *scheme = [NSString stringWithUTF8String:lua_tostring(L, 1)];
    CFStringRef bundleID = LSCopyDefaultHandlerForURLScheme((__bridge CFStringRef)scheme);

    lua_pushstring(L, [(__bridge NSString *)bundleID UTF8String]);

    CFRelease(bundleID);
    return 1;
}

/// hs.urlevent.getAllHandlersForScheme(scheme) -> table
/// Function
/// Gets all of the application bundle identifiers of applications able to handle a URL scheme
///
/// Parameters:
///  * scheme - A string containing a URL scheme (e.g. 'http')
///
/// Returns:
///  * A table containing the bundle identifiers of all applications that can handle the scheme
static int urleventgetAllHandlersForScheme(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];

    NSString *scheme = [NSString stringWithUTF8String:lua_tostring(L, 1)];
    CFArrayRef array = LSCopyAllHandlersForURLScheme((__bridge CFStringRef)scheme);

    int i = 1;
    lua_newtable(L);

    if (array) {
        for (NSString *bundleID in (__bridge NSArray *)array) {
            lua_pushinteger(L, i++);
            lua_pushstring(L, [bundleID UTF8String]);
            lua_settable(L, -3);
        }
        CFRelease(array);
    }

    return 1;
}

/// hs.urlevent.openURLWithBundle(url, bundleID) -> boolean
/// Function
/// Opens a URL with a specified application
///
/// Parameters:
///  * url - A string containing a URL
///  * bundleID - A string containing an application bundle identifier (e.g. "com.apple.Safari")
///
/// Returns:
///  * True if the application was launched successfully, otherwise false
static int urleventopenURLWithBundle(lua_State *L) {
    LuaSkin *skin = [LuaSkin shared];
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TBREAK];

    BOOL result = false;

    // FIXME: Add optional argument to let the user compose their own launch options
    result = [[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:[NSURL URLWithString:[NSString stringWithUTF8String:lua_tostring(L, 1)]]]
                             withAppBundleIdentifier:[NSString stringWithUTF8String:lua_tostring(L, 2)]
                                             options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil
                                   launchIdentifiers:nil];

    lua_pushboolean(L, result);
    return 1;
}

static int urlevent_setup() {
    eventHandler = [[HSURLEventHandler alloc] init];
    fnCallback = LUA_NOREF;
    restoreHandlers = [[NSMutableDictionary alloc] init];

    return 0;
}

// ----------------------- Lua/hs glue GAR ---------------------

static int urlevent_gc(lua_State* __unused L) {
    LuaSkin *skin = [LuaSkin shared];

    [eventHandler gc];
    eventHandler = nil;
    fnCallback = [skin luaUnref:refTable ref:fnCallback];

    for (NSString *key in [restoreHandlers allKeys]) {
        LSSetDefaultHandlerForURLScheme((__bridge CFStringRef)key, (__bridge CFStringRef)[restoreHandlers objectForKey:key]);
    }

    [restoreHandlers removeAllObjects];
    restoreHandlers = nil;

    return 0;
}

static const luaL_Reg urleventlib[] = {
    {"setCallback", urleventSetCallback},
    {"setRestoreHandler", urleventsetRestoreHandler},
    {"setDefaultHandler", urleventsetDefaultHandler},
    {"getDefaultHandler", urleventgetDefaultHandler},
    {"getAllHandlersForScheme", urleventgetAllHandlersForScheme},
    {"openURLWithBundle", urleventopenURLWithBundle},

    {NULL, NULL}
};

static const luaL_Reg urlevent_gclib[] = {
    {"__gc", urlevent_gc},

    {NULL, NULL}
};

/* NOTE: The substring "hs_urlevent_internal" in the following function's name
         must match the require-path of this file, i.e. "hs.urlevent.internal". */

int luaopen_hs_urlevent_internal(lua_State *L __unused) {
    LuaSkin *skin = [LuaSkin shared];

    urlevent_setup();

    refTable = [skin registerLibrary:urleventlib metaFunctions:urlevent_gclib];

    return 1;
}
