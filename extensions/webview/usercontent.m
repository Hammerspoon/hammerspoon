#import "webview.h"

static LSRefTable refTable ;

#pragma mark - our userContentController

@implementation HSUserContentController
- (id)initWithName:(NSString *)name {
    self = [super init] ;
    if (self) {
        self.name = name ;
        self.udRef = LUA_NOREF ;
        self.userContentCallback = LUA_NOREF ;
        [self addScriptMessageHandler:self name:name];
    }
    return self ;
}

- (void)userContentController:(__unused WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message {
    if ([message.name isEqualToString:self.name] && self.userContentCallback != LUA_NOREF) {
        LuaSkin *skin = [LuaSkin sharedWithState:NULL] ;
        _lua_stackguard_entry(skin.L);
        [skin pushLuaRef:refTable ref:self.userContentCallback];
        [skin pushNSObject:message] ;
        [skin protectedCallAndError:@"hs.webview.usercontent callback" nargs:1 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}
@end

#pragma mark - The module methods and constructor

/// hs.webview.usercontent.new(name) -> usercontentControllerObject
/// Constructor
/// Create a new user content controller for a webview and create the message port with the specified name for JavaScript message support.
///
/// Parameters:
///  * name - the name of the message port which JavaScript in the webview can use to post messages to Hammerspoon.
///
/// Returns:
///  * the usercontentControllerObject
///
/// Notes:
///  * This object should be provided as the final argument to the `hs.webview.new` constructor in order to tie the webview to this content controller.  All new windows which are created from this parent webview will also use this controller.
///  * See `hs.webview.usercontent:setCallback` for more information about the message port.
static int ucc_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TBREAK] ;

    NSString *theName = [skin toNSObjectAtIndex:1] ;
    HSUserContentController *newUCC = [[HSUserContentController alloc] initWithName:theName] ;

    [skin pushNSObject:newUCC] ;

    return 1 ;
}

/// hs.webview.usercontent:injectScript(scriptTable) -> usercontentControllerObject
/// Method
/// Add a script to be injected into webviews which use this user content controller.
///
/// Parameters:
///  * scriptTable - a table containing the following keys which define the script and how it is to be injected:
///    * source        - the javascript which is injected (required)
///    * mainFrame     - a boolean value which indicates whether this script is only injected for the main webview frame (true) or for all frames within the webview (false).  Defaults to true.
///    * injectionTime - a string which indicates whether the script is injected at "documentStart" or "documentEnd". Defaults to "documentStart".
///
/// Returns:
///  * the usercontentControllerObject or nil if the script table was malformed in some way.
static int ucc_inject(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_UCC_TAG, LS_TTABLE, LS_TBREAK] ;
    HSUserContentController *ucc = get_objectFromUserdata(__bridge HSUserContentController, L, 1, USERDATA_UCC_TAG) ;

    WKUserScript *userScript = [skin luaObjectAtIndex:2 toClass:"WKUserScript"] ;
    if (userScript) {
        [ucc addUserScript:userScript] ;
        lua_pushvalue(L, 1);
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.webview.usercontent:userScripts() -> array
/// Method
/// Get a table containing all of the currently defined injection scripts for this user content controller
///
/// Parameters:
///  * None
///
/// Returns:
///  * An array of injected user scripts.  Each entry in the array will be a table containing the following keys:
///    * source        - the javascript which is injected
///    * mainFrame     - a boolean value which indicates whether this script is only injected for the main webview frame (true) or for all frames within the webview (false)
///    * injectionTime - a string which indicates whether the script is injected at "documentStart" or "documentEnd".
///
/// Notes:
///  * Because the WKUserContentController class only allows for removing all scripts, you can use this method to generate a list of all scripts, modify it, and then use it in a loop to reapply the scripts if you need to remove just a few scripts.
static int ucc_userScripts(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_UCC_TAG, LS_TBREAK] ;
    HSUserContentController *ucc = get_objectFromUserdata(__bridge HSUserContentController, L, 1, USERDATA_UCC_TAG) ;

    [skin pushNSObject:[ucc userScripts]] ;

    return 1;
}

/// hs.webview.usercontent:removeAllScripts() -> usercontentControllerObject
/// Method
/// Removes all user scripts currently defined for this user content controller.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the usercontentControllerObject
/// Notes:
///  * The WKUserContentController class only allows for removing all scripts.  If you need finer control, make a copy of the current scripts with `hs.webview.usercontent.userScripts()` first so you can recreate the scripts you want to keep.
static int ucc_removeAllScripts(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_UCC_TAG, LS_TBREAK] ;
    HSUserContentController *ucc = get_objectFromUserdata(__bridge HSUserContentController, L, 1, USERDATA_UCC_TAG) ;

    [ucc removeAllUserScripts] ;

    lua_pushvalue(L, 1);
    return 1;
}

/// hs.webview.usercontent:setCallback(fn) -> usercontentControllerObject
/// Method
/// Set or remove the callback function to handle message posted to this user content's message port.
///
/// Parameters:
///  * fn - The function which should receive messages posted to this user content's message port.  Specify an explicit nil to disable the callback.  The function should take one argument which will be the message posted and any returned value will be ignored.
///
/// Returns:
///  * the usercontentControllerObject
///
/// Notes:
///  * Within your (injected or served) JavaScript, you can post messages via the message port created with the constructor like this:
///
///      try {
///          webkit.messageHandlers.*name*>.postMessage(*message-object*);
///      } catch(err) {
///          console.log('The controller does not exist yet');
///      }
///
///  * Where *name* matches the name specified in the constructor and *message-object* is the object to post to the function.  This object can be a number, string, date, array, dictionary(table), or nil.
static int ucc_setCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_UCC_TAG,
                                LS_TFUNCTION | LS_TNIL,
                                LS_TBREAK] ;
    HSUserContentController *ucc = get_objectFromUserdata(__bridge HSUserContentController, L, 1, USERDATA_UCC_TAG) ;

    // We're either removing a callback, or setting a new one. Either way, we want to clear out any callback that exists
    ucc.userContentCallback = [skin luaUnref:refTable ref:ucc.userContentCallback] ;

    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        ucc.userContentCallback = [skin luaRef:refTable] ;
    }

    lua_pushvalue(L, 1);
    return 1;
}

#pragma mark - NSObject <-> Lua converters

static int HSUserContentController_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUserContentController *ucc = obj ;

    if (ucc.udRef == LUA_NOREF) {
        void** uccPtr = lua_newuserdata(L, sizeof(HSUserContentController *)) ;
        *uccPtr = (__bridge_retained void *)ucc ;
        luaL_getmetatable(L, USERDATA_UCC_TAG) ;
        lua_setmetatable(L, -2) ;
        ucc.udRef = [skin luaRef:refTable] ;
    }

    [skin pushLuaRef:refTable ref:ucc.udRef] ;
    return 1 ;
}

static int WKUserScript_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    WKUserScript *script = obj ;

    lua_newtable(L) ;
      lua_pushboolean(L, [script isForMainFrameOnly]) ;   lua_setfield(L, -2, "forMainFrameOnly") ;
      switch([script injectionTime]) {
          case WKUserScriptInjectionTimeAtDocumentStart:  lua_pushstring(L, "documentStart") ;   break ;
          case WKUserScriptInjectionTimeAtDocumentEnd:    lua_pushstring(L, "documentEnd") ;     break ;
          default:                                        lua_pushstring(L, "unknown") ;         break ;
      }
      lua_setfield(L, -2, "injectionTime") ;
      [skin pushNSObject:[script source]] ; lua_setfield(L, -2, "source") ;
    return 1 ;
}

static int WKScriptMessage_toLua(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    WKScriptMessage *message = obj ;

    lua_newtable(L) ;
      [skin pushNSObject:message.body] ;      lua_setfield(L, -2, "body") ;
      [skin pushNSObject:message.frameInfo] ; lua_setfield(L, -2, "frameInfo") ;
      [skin pushNSObject:message.name] ;      lua_setfield(L, -2, "name") ;
      [skin pushNSObject:(HSWebViewWindow *)((HSWebViewView *)message.webView).window] ;
          lua_setfield(L, -2, "webView") ;
    return 1 ;
}

static id table_toWKUserScript(lua_State* L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    if (lua_type(L, idx) == LUA_TTABLE) {
        BOOL                      mainFrame = YES ;
        NSString                  *source ;
        WKUserScriptInjectionTime injectionTime = WKUserScriptInjectionTimeAtDocumentStart ;

        if (lua_getfield(L, idx, "mainFrame") == LUA_TBOOLEAN)
            mainFrame = (BOOL)lua_toboolean(L, -1) ;
        lua_pop(L, 1) ;

        if (lua_getfield(L, idx, "source") == LUA_TSTRING) {
            source = [skin toNSObjectAtIndex:-1] ;
            lua_pop(L, 1) ;
        } else {
            lua_pop(L, 1) ;
            [skin logWarn:@"source is required and must be a string"] ;
            return nil ;
        }

        if (lua_getfield(L, idx, "injectionTime") == LUA_TSTRING) {
            NSString *label = [skin toNSObjectAtIndex:-1] ;
            if ([label isEqualToString:@"documentStart"])      { injectionTime = WKUserScriptInjectionTimeAtDocumentStart ;
            } else if ([label isEqualToString:@"documentEnd"]) { injectionTime = WKUserScriptInjectionTimeAtDocumentEnd ;
            } else {
                [skin logWarn:[NSString stringWithFormat:@"invalid injectionTime, %@, defaulting to `documentStart`", label]] ;
            }
        }
        lua_pop(L, 1) ;

        WKUserScript *script = [[WKUserScript alloc] initWithSource:source
                                                      injectionTime:injectionTime
                                                   forMainFrameOnly:mainFrame] ;
        return script ;
    } else {
        [skin logWarn:[NSString stringWithFormat:@"%s:invalid type for userscript, expected table, found %s", USERDATA_UCC_TAG, lua_typename(L, lua_type(L, idx))]] ;
        return nil ;
    }
}

#pragma mark - Lua infrastructure support

static int userdata_tostring(lua_State* L) {
    HSUserContentController *ucc = get_objectFromUserdata(__bridge HSUserContentController, L, 1, USERDATA_UCC_TAG) ;
    NSString *name ;

    if (ucc) { name = ucc.name ; } else { name = @"<deleted>" ; }
    if (!name) { name = @"" ; }

    lua_pushstring(L, [[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_UCC_TAG, name, lua_topointer(L, 1)] UTF8String]) ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
    HSUserContentController *ucc1 = get_objectFromUserdata(__bridge_transfer HSUserContentController, L, 1, USERDATA_UCC_TAG) ;
    HSUserContentController *ucc2 = get_objectFromUserdata(__bridge_transfer HSUserContentController, L, 1, USERDATA_UCC_TAG) ;

    lua_pushboolean(L, ucc1.udRef == ucc2.udRef) ;
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSUserContentController *ucc = get_objectFromUserdata(__bridge_transfer HSUserContentController, L, 1, USERDATA_UCC_TAG) ;

    if (ucc) {
        ucc.udRef = [skin luaUnref:refTable ref:ucc.udRef] ;

        [ucc removeAllUserScripts] ;
        [ucc removeScriptMessageHandlerForName:ucc.name] ;
        ucc = nil ;
    }

// I think this may be too aggressive... removing the metatable is sufficient to make sure lua doesn't use it again
// // Clear the pointer so it's no longer dangling
//     void** uccPtr = lua_touserdata(L, 1);
//     *uccPtr = nil ;

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L) ;
    lua_setmetatable(L, 1) ;

    return 0 ;
}

// static int meta_gc(lua_State* __unused L) {
//     [hsimageReferences removeAllIndexes];
//     hsimageReferences = nil;
//     return 0 ;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"injectScript",     ucc_inject},
    {"userScripts",      ucc_userScripts},
    {"removeAllScripts", ucc_removeAllScripts},
    {"setCallback",      ucc_setCallback},
//     {"delete",           userdata_gc},  // bad juju happens when this disappears and the webview is still present

    {"__tostring",       userdata_tostring},
    {"__eq",             userdata_eq},
    {"__gc",             userdata_gc},
    {NULL,               NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", ucc_new},
    {NULL,  NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

// NOTE: ** Make sure to change luaopen_..._internal **
int luaopen_hs_webview_usercontent(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    if (!NSClassFromString(@"WKWebView")) {
        [skin logError:[NSString stringWithFormat:@"%s requires WKWebView support, found in OS X 10.10 or newer", USERDATA_UCC_TAG]] ;
        // nil gets interpreted as "nothing" and thus "true" by require...
        lua_pushboolean(L, NO) ;
    } else {
        refTable = [skin registerLibraryWithObject:USERDATA_UCC_TAG
                                         functions:moduleLib
                                     metaFunctions:nil    // or module_metaLib
                                   objectFunctions:userdata_metaLib];

        [skin registerPushNSHelper:HSUserContentController_toLua forClass:"HSUserContentController"] ;
        [skin registerPushNSHelper:WKUserScript_toLua            forClass:"WKUserScript"] ;
        [skin registerPushNSHelper:WKScriptMessage_toLua         forClass:"WKScriptMessage"] ;

        [skin registerLuaObjectHelper:table_toWKUserScript       forClass:"WKUserScript"] ;
    }
    return 1;
}
