#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <CoreServices/CoreServices.h>
#import <LuaSkin/LuaSkin.h>
#define NO_INTENTS
#import "../../Hammerspoon/MJAppDelegate.h"
#undef NO_INTENTS
#import "../../Hammerspoon/MJDockIcon.h"

static LSRefTable refTable;
NSArray *defaultContentTypes = nil;

// ----------------------- Objective C ---------------------

@interface HSURLEventHandler : NSObject <HSOpenFileDelegate>
@property (nonatomic, strong) NSAppleEventManager *appleEventManager;
@property (nonatomic) int fnCallback;
@property (nonatomic, strong) NSMutableDictionary *restoreHandlers;
@property (nonatomic, weak) MJAppDelegate *appDelegate;

- (void)handleStartupEvents;
- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent: (NSAppleEventDescriptor *)replyEvent;
- (void)callbackWithURL:(NSString *)openUrl senderPID:(pid_t)pid;
- (void)gcWithState:(lua_State *)L;
@end

static HSURLEventHandler *eventHandler;

@implementation HSURLEventHandler
- (id)init {
    self = [super init];
    if (self) {
        self.fnCallback = LUA_NOREF;
        self.restoreHandlers = [[NSMutableDictionary alloc] init];

        self.appleEventManager = [NSAppleEventManager sharedAppleEventManager];
        [self.appleEventManager setEventHandler:self
                               andSelector:@selector(handleAppleEvent:withReplyEvent:)
                             forEventClass:kInternetEventClass
                                andEventID:kAEGetURL];

        MJAppDelegate *delegate = (MJAppDelegate *)[[NSApplication sharedApplication] delegate];
        delegate.openFileDelegate = self;
    }
    return self;
}

- (void)gcWithState:(lua_State *)L {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    [self.appleEventManager removeEventHandlerForEventClass:kInternetEventClass
                                                 andEventID:kAEGetURL];

    _appDelegate.openFileDelegate = nil;

    _fnCallback = [skin luaUnref:refTable ref:_fnCallback];

    //NSLog(@"Restoring URL handlers: %@", eventHandler.restoreHandlers);
    for (NSString *key in [_restoreHandlers allKeys]) {
        OSStatus status;
        CFStringRef bundleID = (__bridge CFStringRef)[_restoreHandlers objectForKey:key];

        LSSetDefaultHandlerForURLScheme((__bridge CFStringRef)key, bundleID);

        if ([key isEqualToString:@"http"] || [key isEqualToString:@"https"]) {
            for (NSString *type in defaultContentTypes) {
                status = LSSetDefaultRoleHandlerForContentType((__bridge CFStringRef)type, kLSRolesViewer, bundleID);
                if (status != noErr) {
                    NSLog(@"Unable to set role handler for %@: %@", type, [[NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil] localizedDescription]);
                }
            }
        }
    }
    [_restoreHandlers removeAllObjects];

}

- (void)handleStartupEvents {
    if (_appDelegate.startupEvent) {
        [self handleAppleEvent:_appDelegate.startupEvent withReplyEvent:nil];
        _appDelegate.startupEvent = nil;
    }

    if (_appDelegate.startupFile) {
        [eventHandler callbackWithURL:_appDelegate.startupFile senderPID:-1];
        _appDelegate.startupFile = nil;
    }
}

- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent: (NSAppleEventDescriptor * __unused)replyEvent {
    // This is a completely disgusting workaround - starting in macOS 10.15 for some reason the OS reveals our Dock icon even if it's hidden, before we receive an Apple Event, so let's reassert our expected state before we go any further.
    MJDockIconSetVisible(MJDockIconVisible());

    // get the process id for the application that sent the current Apple Event
    NSAppleEventDescriptor *appleEventDescriptor = [[NSAppleEventManager sharedAppleEventManager] currentAppleEvent];
    NSAppleEventDescriptor* processSerialDescriptor = [appleEventDescriptor attributeDescriptorForKeyword:keyAddressAttr];
    NSAppleEventDescriptor* pidDescriptor = [processSerialDescriptor coerceToDescriptorType:typeKernelProcessID];

    pid_t pid;

    if (pidDescriptor) {
        pid = *(pid_t *)[[pidDescriptor data] bytes];
    } else {
        pid = -1;
    }

    [self callbackWithURL:[[event paramDescriptorForKeyword:keyDirectObject] stringValue] senderPID:pid];
}

- (void)callbackWithURL:(NSString *)openUrl senderPID:(pid_t)pid {
    LuaSkin *skin = [LuaSkin sharedWithState:NULL];
    _lua_stackguard_entry(skin.L);

    if (self.fnCallback == LUA_NOREF || self.fnCallback == LUA_REFNIL) {
        // Lua hasn't registered a callback. This possibly means we have been require()'d as hs.urlevent.internal and not set up properly. Weird. Refuse to do anything
        [skin logWarn:[NSString stringWithFormat:@"hs.urlevent callbackWithURL received a URL with no callback set: %@", openUrl]];
        _lua_stackguard_exit(skin.L);
        return;
    }

    if ([openUrl hasPrefix:@"/"]) {
        openUrl = [NSString stringWithFormat:@"file://%@", openUrl];
        openUrl = [openUrl stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    }

    // Split the URL into its components
    NSURL *url = [NSURL URLWithString:openUrl];

    if (!url) {
        NSLog(@"ERROR: Unable to parse '%@' as a URL", openUrl);
        _lua_stackguard_exit(skin.L);
        return;
    }

    NSString *query = [url query];
    NSArray *queryPairs = [query componentsSeparatedByString:@"&"];
    NSMutableDictionary *pairs = [NSMutableDictionary dictionary];

    for (NSString *queryPair in queryPairs) {
        NSArray *bits = [queryPair componentsSeparatedByString:@"="];
        if ([bits count] != 2) { continue; }

        NSString *key = [[bits objectAtIndex:0] stringByRemovingPercentEncoding];
        NSString *value = [[bits objectAtIndex:1] stringByRemovingPercentEncoding];

        [pairs setObject:value forKey:key];
    }

    [skin pushLuaRef:refTable ref:self.fnCallback];
    [skin pushNSObject:[url scheme]];
    [skin pushNSObject:[url host]];
    [skin pushNSObject:pairs];
    [skin pushNSObject:[url absoluteString]];
    lua_pushinteger(skin.L, pid);
    [skin protectedCallAndError:[NSString stringWithFormat:@"hs.urlevent callback for %@", url.absoluteString] nargs:5 nresults:0];
    _lua_stackguard_exit(skin.L);
}
@end

// ----------------------- C ---------------------

// Rather than manage complex callback state from C, we just have one path into Lua for all events, and events are directed to their callbacks from there
static int urleventSetCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    luaL_checktype(L, 1, LUA_TFUNCTION);
    lua_pushvalue(L, 1);
    eventHandler.fnCallback = [skin luaRef:refTable];

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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TBREAK];

    [eventHandler.restoreHandlers setObject:[skin toNSObjectAtIndex:2] forKey:[skin toNSObjectAtIndex:1]];
    //NSLog(@"%@", eventHandler.restoreHandlers);

    return 0;
}

/// hs.urlevent.setDefaultHandler(scheme[, bundleID])
/// Function
/// Sets the default system handler for URLs of a given scheme
///
/// Parameters:
///  * scheme - A string containing the URL scheme to change. This must be 'http' or 'https' (although entering either will change the handler for both)
///  * bundleID - An optional string containing an application bundle identifier for the application to set as the default handler. Defaults to `org.hammerspoon.Hammerspoon`.
///
/// Returns:
///  * None
///
/// Notes:
///  * Changing the default handler for http/https URLs will display a system prompt asking the user to confirm the change
static int urleventsetDefaultHandler(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TSTRING|LS_TOPTIONAL, LS_TBREAK];

    OSStatus status;
    NSString *scheme = [[NSString stringWithUTF8String:lua_tostring(L, 1)] lowercaseString];
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

    if (lua_type(L, 2) == LUA_TSTRING) {
        bundleID = [NSString stringWithUTF8String:lua_tostring(L, 2)];
    }

    status = LSSetDefaultHandlerForURLScheme((__bridge CFStringRef)scheme, (__bridge CFStringRef)bundleID);
    if (status != noErr) {
        [skin logError:[NSString stringWithFormat:@"hs.urlevent.setDefaultHandler() unable to set the handler for %@ to %@: %@", scheme, bundleID, [[NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil] localizedDescription]]];
    } else {
        [eventHandler.restoreHandlers removeObjectForKey:scheme];
    }

    if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
        // If we're dealing with http/https, also register ourselves for various filetypes that are relevant
        for (NSString *type in defaultContentTypes) {
            status = LSSetDefaultRoleHandlerForContentType((__bridge CFStringRef)type, kLSRolesViewer, (__bridge CFStringRef)bundleID);
            if (status != noErr) {
                [skin logWarn:[NSString stringWithFormat:@"Unable to set role handler for %@: %@", type, [[NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil] localizedDescription]]];
            }
        }

        // Handle any startup events for http/https/file
        [eventHandler handleStartupEvents];
    }

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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TBREAK];

    NSString *scheme = [NSString stringWithUTF8String:lua_tostring(L, 1)];
    CFStringRef bundleID = LSCopyDefaultHandlerForURLScheme((__bridge CFStringRef)scheme);

    if (bundleID) {
        lua_pushstring(L, [(__bridge NSString *)bundleID UTF8String]);
        CFRelease(bundleID);
    } else {
        lua_pushnil(L) ;
    }
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
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
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING, LS_TSTRING, LS_TBREAK];

    BOOL result = false;

    // FIXME: Add optional argument to let the user compose their own launch options
    NSURL *url = [NSURL URLWithString:[skin toNSObjectAtIndex:1]];

    if (url) {
        result = [[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:url]
                                 withAppBundleIdentifier:[NSString stringWithUTF8String:lua_tostring(L, 2)]
                                                 options:NSWorkspaceLaunchDefault additionalEventParamDescriptor:nil
                                       launchIdentifiers:nil];
    }

    lua_pushboolean(L, result);
    return 1;
}

static int urlevent_setup() {
    eventHandler = [[HSURLEventHandler alloc] init];

    defaultContentTypes = @[(__bridge NSString *)kUTTypeURL,
                            (__bridge NSString *)kUTTypeFileURL,
                            (__bridge NSString *)kUTTypeText
                            ];

    return 0;
}

// ----------------------- Lua/hs glue GAR ---------------------

static int urlevent_gc(lua_State* L) {
    [eventHandler gcWithState:L];
    eventHandler = nil;

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

int luaopen_hs_liburlevent(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];

    urlevent_setup();

    refTable = [skin registerLibrary:"hs.urlevent" functions:urleventlib metaFunctions:urlevent_gclib];

    return 1;
}
