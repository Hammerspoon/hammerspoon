#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

#define USERDATA_TAG "hs.speech.listener"
static LSRefTable refTable = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Support Functions

#pragma mark - HSSpeechRecognizer Definition

@interface HSSpeechRecognizer : NSSpeechRecognizer <NSSpeechRecognizerDelegate>
@property int callbackRef ;
@property BOOL isListening ;
// We don't use the same trick as we do for synthesizer because a recognizer also exists in
// the dictation scope (it's visual components) and, if we opened it because we're the only
// listener, it will only go away when we explicitly remove *all* of our references to it.
// This means agressive garbage collection or making sure all possible lua references
// are in fact the same pointer to the reference, and not just pointers to the same reference.
//
// The positive is that it will actually remove the dictation displays when we "delete" it,
// (assuming we're the only listener) rather than mark it as "deletable" when lua gets
// around to garbage collection.  Visual immediacy over lazily allowing things to go out of
// scope when convenient.  The negative is that we *have* to delete it, or reload/restart
// Hammerspoon; otherwise the visible dictation stuff hangs around.
@property int selfRef ;
@end

@implementation HSSpeechRecognizer
- (id)init {
    self = [super init] ;
    if (self) {
        self.callbackRef = LUA_NOREF ;
        self.selfRef = LUA_NOREF ;
        self.isListening = NO ;
        self.delegate = self ;
    }
    return self ;
}

#pragma mark - HSSpeechRecognizer Delegate Methods

- (void)speechRecognizer:(NSSpeechRecognizer *)sender didRecognizeCommand:(NSString *)command {
    if (((HSSpeechRecognizer *)sender).callbackRef != LUA_NOREF) {
        LuaSkin      *skin    = [LuaSkin sharedWithState:NULL] ;
        _lua_stackguard_entry(skin.L);

        [skin pushLuaRef:refTable ref:((HSSpeechRecognizer *)sender).callbackRef] ;
        [skin pushNSObject:(HSSpeechRecognizer *)sender] ;
        [skin pushNSObject:command] ;
        [skin protectedCallAndError:@"hs.speech.listener callback" nargs:2 nresults:0];
        _lua_stackguard_exit(skin.L);
    }
}

@end

#pragma mark - Module Functions

/// hs.speech.listener.new([title]) -> recognizerObject
/// Constructor
/// Creates a new speech recognizer object for use by Hammerspoon.
///
/// Parameters:
///  * title - an optional parameter specifying the title under which commands assigned to this speech recognizer will be listed in the Dictation Commands display when it is visible.  Defaults to "Hammerspoon".
///
/// Returns:
///  * a speech recognizer object or nil, if the system was unable to create a new recognizer.
///
/// Notes:
///  * You can change the title later with the `hs.speech.listener:title` method.
static int newSpeechRecognizer(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING | LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *theTitle = nil ;
    if (lua_gettop(L) == 1) {
        luaL_checkstring(L, 1) ; // force number to be a string
        theTitle = [skin toNSObjectAtIndex:1] ;
        if (!theTitle) [skin logWarn:@"unable to identify title from string, defaulting to \"Hammerspoon\""] ;
    }

    HSSpeechRecognizer *recognizer = [[HSSpeechRecognizer alloc] init] ;
    if (recognizer) {
        if (theTitle) recognizer.displayedCommandsTitle = theTitle ;
        [skin pushNSObject:recognizer] ;
    } else {
        [skin logDebug:@"unable to create recognizer, returning nil"] ;
        lua_pushnil(L) ;
    }
    return 1 ;
}

#pragma mark - Module Object Methods

/// hs.speech.listener:commands([commandsArray]) -> recognizerObject | current value
/// Method
/// Get or set the commands this speech recognizer will listen for.
///
/// Parameters:
///  * commandsArray - an optional array of strings which specify the commands the recognizer will listen for.
///
/// Returns:
///  * If no parameter is provided, returns the current value; otherwise returns the recognizer object.
///
/// Notes:
///  * The list of commands will appear in the Dictation Commands window, if it is visible, under the title of this speech recognizer.  The text of each command is a possible value which may be sent as the second argument to a callback function for this speech recognizer, if one is defined.
///  * Setting this to an empty list does not disable the speech recognizer, but it does make it of limited use, other than to provide a title in the Dictation Commands window.  To disable the recognizer, use the `hs.speech.listener:stop` or `hs.speech.listener:delete` methods.
static int commands(lua_State *L) {
    HSSpeechRecognizer *recognizer = get_objectFromUserdata(__bridge HSSpeechRecognizer, L, 1) ;
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TTABLE | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        NSMutableArray *theCommands = [[NSMutableArray alloc] init] ;
        for (NSInteger i = 0 ; i < luaL_len(L, 2) ; i++) {
            int type = lua_rawgeti(L, 2, i + 1) ;
            if (type == LUA_TSTRING || type == LUA_TNUMBER) {
                luaL_checkstring(L, -1) ; // force number to be a string
                NSString *theCommand = [skin toNSObjectAtIndex: -1] ;
                if (theCommand) {
                    [theCommands addObject:theCommand] ;
                } else {
                    [skin logWarn:@"invalid string evaluates to nil, skipping"] ;
                }
            } else {
                [skin logWarn:@"not a string or number value, skipping"] ;
            }
        }
        recognizer.commands = theCommands ;
        lua_pushvalue(L, 1) ;
    } else {
        [skin pushNSObject:recognizer.commands] ;
    }
    return 1 ;
}

/// hs.speech.listener:title([title]) -> recognizerObject | current value
/// Method
/// Get or set the title for a speech recognizer.
///
/// Parameters:
///  * title - an optional parameter specifying the title under which commands assigned to this speech recognizer will be listed in the Dictation Commands display when it is visible.  If you provide an explicit `nil`, it will reset to the default of "Hammerspoon".
///
/// Returns:
///  * If no parameter is provided, returns the current value; otherwise returns the recognizer object.
static int displayedCommandsTitle(lua_State *L) {
    HSSpeechRecognizer *recognizer = get_objectFromUserdata(__bridge HSSpeechRecognizer, L, 1) ;
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        NSString *theTitle = nil ;
        if (lua_type(L, 2) != LUA_TNIL) {
            luaL_checkstring(L, 2) ; // force number to be a string
            theTitle = [skin toNSObjectAtIndex:2] ;
        }
        recognizer.displayedCommandsTitle = theTitle ;
        lua_pushvalue(L, 1) ;
    } else {
        [skin pushNSObject:recognizer.displayedCommandsTitle] ;
    }
    return 1 ;
}

/// hs.speech.listener:foregroundOnly([flag]) -> recognizerObject | current value
/// Method
/// Get or set whether or not the speech recognizer is active only when the Hammerspoon application is active.
///
/// Parameters:
///  * flag - an optional boolean indicating whether or not the speech recognizer should respond to commands only when Hammerspoon is the active application or not. Defaults to true.
///
/// Returns:
///  * If no parameter is provided, returns the current value; otherwise returns the recognizer object.
static int listensInForegroundOnly(lua_State *L) {
    HSSpeechRecognizer *recognizer = get_objectFromUserdata(__bridge HSSpeechRecognizer, L, 1) ;
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        recognizer.listensInForegroundOnly = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, recognizer.listensInForegroundOnly) ;
    }
    return 1 ;
}

/// hs.speech.listener:blocksOtherRecognizers([flag]) -> recognizerObject | current value
/// Method
/// Get or set whether or not the speech recognizer should block other recognizers when it is active.
///
/// Parameters:
///  * flag - an optional boolean indicating whether or not the speech recognizer should block other speech recognizers when it is active. Defaults to false.
///
/// Returns:
///  * If no parameter is provided, returns the current value; otherwise returns the recognizer object.
static int blocksOtherRecognizers(lua_State *L) {
    HSSpeechRecognizer *recognizer = get_objectFromUserdata(__bridge HSSpeechRecognizer, L, 1) ;
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    if (lua_gettop(L) == 2) {
        recognizer.blocksOtherRecognizers = (BOOL)lua_toboolean(L, 2) ;
        lua_pushvalue(L, 1) ;
    } else {
        lua_pushboolean(L, recognizer.blocksOtherRecognizers) ;
    }
    return 1 ;
}

/// hs.speech.listener:start() -> recognizerObject
/// Method
/// Make the speech recognizer active.
///
/// Parameters:
///  * None.
///
/// Returns:
///  * returns the recognizer object.
static int startListening(lua_State *L) {
    HSSpeechRecognizer *recognizer = get_objectFromUserdata(__bridge HSSpeechRecognizer, L, 1) ;
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    [recognizer startListening] ;
    recognizer.isListening = YES ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.speech.listener:stop() -> recognizerObject
/// Method
/// Disables the speech recognizer.
///
/// Parameters:
///  * None.
///
/// Returns:
///  * returns the recognizer object.
///
/// Notes:
///  * this only disables the speech recognizer.  To completely remove it from the list in the Dictation Commands window, use `hs.speech.listener:delete`.
static int stopListening(lua_State *L) {
    HSSpeechRecognizer *recognizer = get_objectFromUserdata(__bridge HSSpeechRecognizer, L, 1) ;
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    [recognizer stopListening] ;
    recognizer.isListening = NO ;
    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.speech.listener:isListening() -> boolean
/// Method
/// Returns a boolean value indicating whether or not the recognizer is currently enabled (started).
///
/// Parameters:
///  * None
///
/// Returns:
///  * true if the listener is listening (has been started) or false if it is not.
static int isListening(lua_State *L) {
    HSSpeechRecognizer *recognizer = get_objectFromUserdata(__bridge HSSpeechRecognizer, L, 1) ;
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    lua_pushboolean(L, recognizer.isListening) ;
    return 1 ;
}

/// hs.speech.listener:setCallback(fn) -> recognizerObject
/// Method
/// Sets or removes a callback function for the speech recognizer.
///
/// Parameters:
///  * fn - a function to set as the callback for this speech synthesizer.  If the value provided is nil, any currently existing callback function is removed.  The callback function should accept two arguments and return none.  The arguments will be the speech recognizer object itself and the string of the command which was spoken.
///
/// Returns:
///  * the recognizer object
///
/// Notes:
///  * Possible string values for the command spoken are set with the `hs.speech.listener:commands` method.
///  * Removing the callback does not disable the speech recognizer, but it does make it of limited use, other than to provide a list in the Dictation Commands window.  To disable the recognizer, use the `hs.speech.listener:stop` or `hs.speech.listener:delete` methods.
static int setCallback(lua_State *L) {
    HSSpeechRecognizer *recognizer = get_objectFromUserdata(__bridge HSSpeechRecognizer, L, 1) ;
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK] ;
    // in either case, we need to remove an existing callback, so...
    recognizer.callbackRef = [skin luaUnref:refTable ref:recognizer.callbackRef] ;
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2) ;
        recognizer.callbackRef = [skin luaRef:refTable] ;
    }
    lua_pushvalue(L, 1) ;
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions

static int pushHSSpeechRecognizer(lua_State *L, id obj) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSSpeechRecognizer *recognizer = obj ;

    if (recognizer.selfRef == LUA_NOREF) {
        void** recognizerPtr = lua_newuserdata(L, sizeof(HSSpeechRecognizer *)) ;
        *recognizerPtr = (__bridge_retained void *)recognizer ;
        luaL_getmetatable(L, USERDATA_TAG) ;
        lua_setmetatable(L, -2) ;
        recognizer.selfRef = [skin luaRef:refTable] ;
    }

    [skin pushLuaRef:refTable ref:recognizer.selfRef] ;
    return 1 ;
}

#pragma mark - Hammerspoon Infrastructure

static int userdata_tostring(lua_State* L) {
    HSSpeechRecognizer *recognizer = get_objectFromUserdata(__bridge HSSpeechRecognizer, L, 1) ;
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, recognizer.displayedCommandsTitle, (void *)recognizer]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// Actually not necessary for this specific module, as the creation function for the userdata object this module uses
// ensures that the userdata object returned for a specific recognizer is always the same and Lua can use pointer
// comparisons for this specific module.  However, it is good practice, since not all modules do this (specifically, the
// companion module, hs.speech, does not make this assurance for speech synthesizers).
//
// And anyways, this makes sure that only the same userdata types are compared.
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        HSSpeechRecognizer *recognizer1 = get_objectFromUserdata(__bridge HSSpeechRecognizer, L, 1) ;
        HSSpeechRecognizer *recognizer2 = get_objectFromUserdata(__bridge HSSpeechRecognizer, L, 2) ;
        lua_pushboolean(L, [recognizer1 isEqualTo:recognizer2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

/// hs.speech.listener:delete() -> recognizerObject
/// Method
/// Disables the speech recognizer and removes it from the possible available speech recognizers.
///
/// Parameters:
///  * None.
///
/// Returns:
///  * None
///
/// Notes:
///  * this disables the speech recognizer and removes it from the list in the Dictation Commands window.  The object is effectively destroyed, so you will need to create a new one with `hs.speech.listener.new` if you want to bring it back.
///  * if this was the only speech recognizer currently available, the Dictation Commands window and feedback display will be removed from the users display.
///  * this method is automatically called during a reload or restart of Hammerspoon.
static int userdata_gc(lua_State* L) {
    HSSpeechRecognizer *recognizer = get_objectFromUserdata(__bridge_transfer HSSpeechRecognizer, L, 1) ;
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;

    if (recognizer) {
        recognizer.callbackRef = [skin luaUnref:refTable ref:recognizer.callbackRef] ;
        recognizer.selfRef     = [skin luaUnref:refTable ref:recognizer.selfRef] ;
        [recognizer stopListening] ;
        // If I'm reading the docs correctly, delegate isn't a weak assignment, so we'd better
        // clear it to make sure we don't create a self-retaining object...
        recognizer.delegate = nil ;
        recognizer = nil ;
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
    {"commands", commands},
    {"title", displayedCommandsTitle},
    {"foregroundOnly", listensInForegroundOnly},
    {"blocksOtherRecognizers", blocksOtherRecognizers},
    {"start", startListening},
    {"stop", stopListening},
    {"isListening", isListening},
    {"setCallback", setCallback},
    {"delete", userdata_gc},
    {"__tostring", userdata_tostring},
    {"__eq", userdata_eq},
    {"__gc", userdata_gc},
    {NULL, NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new", newSpeechRecognizer},
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs_speech_listener(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSSpeechRecognizer forClass:"HSSpeechRecognizer"] ;

    return 1;
}
