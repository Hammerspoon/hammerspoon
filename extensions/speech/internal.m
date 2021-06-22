#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

// This module does not include some of the code I used during testing... the setPropertyForObject and
// getPropertyForObject methods of NSSpeechSynthesizer are somewhat broken, in my opinion, and rather
// than include a lot of code to wrap them or leave it to the user to *not* do anything which would
// cause a crash, i opted instead for the version in Core to wrap the specific properties which could
// be reliably counted upon to work every time, or at least when they don't for newer voices, fail in
// a way we can use (i.e. they just return NIL) -- see :phoneticSymbols
//
// At any rate, if you think I may have missed something (very possible), or are just curious, the
// full version can be found at https://github.com/asmagill/hammerspoon_asm/tree/master/speech

#define USERDATA_TAG "hs.speech"
static LSRefTable refTable = LUA_NOREF;

#define get_objectFromUserdata(objType, L, idx) (objType*)*((void**)luaL_checkudata(L, idx, USERDATA_TAG))
// #define get_structFromUserdata(objType, L, idx) ((objType *)luaL_checkudata(L, idx, USERDATA_TAG))

#pragma mark - Support Functions

// Lua treats strings (and therefore indexs within strings) as a sequence of bytes.  Objective-C's
// NSString and NSAttributedString treat them as a sequence of characters.  This works fine until
// Unicode characters are involved.
//
// This function creates a dictionary mapping of this where the keys are the byte positions in the
// Lua string and the values are the corresponding character positions in the NSString.
NSDictionary *luaByteToObjCharMap(NSString *theString) {
    NSMutableDictionary *luaByteToObjChar = [[NSMutableDictionary alloc] init];
    NSData *rawString                     = [theString dataUsingEncoding:NSUTF8StringEncoding];

    if (rawString) {
        NSUInteger luaPos  = 1; // for testing purposes, match what the lua equiv generates
        NSUInteger objCPos = 0; // may switch back to 0 if ends up easier when using for real...

        while ((luaPos - 1) < [rawString length]) {
            Byte thisByte;
            [rawString getBytes:&thisByte range:NSMakeRange(luaPos - 1, 1)];
            // we're taking some liberties and making assumptions here because the above conversion
            // to NSData should make sure that what we have is valid UTF8, i.e. one of:
            //    00..7F
            //    C2..DF 80..BF
            //    E0     A0..BF 80..BF
            //    E1..EC 80..BF 80..BF
            //    ED     80..9F 80..BF
            //    EE..EF 80..BF 80..BF
            //    F0     90..BF 80..BF 80..BF
            //    F1..F3 80..BF 80..BF 80..BF
            //    F4     80..8F 80..BF 80..BF
            [luaByteToObjChar setObject:[NSNumber numberWithUnsignedInteger:objCPos]
                                 forKey:[NSNumber numberWithUnsignedInteger:luaPos]];
            if ((thisByte >= 0x00 && thisByte <= 0x7F) || (thisByte >= 0xC0)) {
                objCPos++;
            }
            luaPos++;
        }
    }
    return luaByteToObjChar;
}

// All (that I've seen) voices start with "com.apple.speech.synthesis.voice."... this is annoying to type,
// so this allows us to leave it off and will add it if necessary.
static NSString * const appleVoicePrefix = @"com.apple.speech.synthesis.voice.";

static NSString *correctForVoiceShortCut(NSString *theVoice) {
    if (theVoice && ![theVoice hasPrefix:appleVoicePrefix])
        return [appleVoicePrefix stringByAppendingString:theVoice];
    else
        return theVoice;
}
static NSString *getVoiceShortCut(NSString *theVoice) {
    if (theVoice && [theVoice hasPrefix:appleVoicePrefix])
        return [theVoice substringFromIndex:NSMaxRange([theVoice rangeOfString:appleVoicePrefix])];
    else
        return theVoice;
}

#pragma mark - HSSpeechSynthesizer Definition

@interface HSSpeechSynthesizer : NSSpeechSynthesizer <NSSpeechSynthesizerDelegate>
@property int callbackRef;
@property int selfRef;
@property int UDreferenceCount; // used to know when to clear the functionRef from the registry
@end

@implementation HSSpeechSynthesizer
- (id)initWithVoice:(NSString *)theVoice {
    self = [super initWithVoice:theVoice];
    if (self) {
        self.callbackRef      = LUA_NOREF;
        self.selfRef          = LUA_NOREF;
        self.UDreferenceCount = 0;
        self.delegate         = self;
    }
    return self;
}

#pragma mark - HSSpeechSynthesizer Delegate Methods

- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender willSpeakWord:(NSRange)wordToSpeak
                                                             ofString:(NSString *)text {
    if (((HSSpeechSynthesizer *)sender).callbackRef != LUA_NOREF) {
        LuaSkin      *skin    = [LuaSkin sharedWithState:NULL];
        lua_State    *_L      = [skin L];
        _lua_stackguard_entry(_L);
        NSDictionary *charMap = luaByteToObjCharMap(text);

        [skin pushLuaRef:refTable ref:((HSSpeechSynthesizer *)sender).callbackRef];
        [skin pushNSObject:(HSSpeechSynthesizer *)sender];
        lua_pushstring(_L, "willSpeakWord");

        NSArray *luaStart = [[charMap allKeysForObject:[NSNumber numberWithUnsignedInteger:wordToSpeak.location]]
                            sortedArrayUsingSelector: @selector(compare:)];
        NSArray *luaEnd   = [[charMap allKeysForObject:[NSNumber numberWithUnsignedInteger:NSMaxRange(wordToSpeak)]]
                            sortedArrayUsingSelector: @selector(compare:)];
        lua_pushinteger(_L, (lua_Integer)[[luaStart lastObject] unsignedIntegerValue]);
        lua_pushinteger(_L, (lua_Integer)[[luaEnd lastObject] unsignedIntegerValue] - 1);

        [skin pushNSObject:text];
        [skin protectedCallAndError:@"hs.speech:willSpeakWord callback" nargs:5 nresults:0];
        _lua_stackguard_exit(_L);
    }
}

- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender willSpeakPhoneme:(short)phonemeOpcode {
    if (((HSSpeechSynthesizer *)sender).callbackRef != LUA_NOREF) {
        LuaSkin      *skin    = [LuaSkin sharedWithState:NULL];
        lua_State    *_L      = [skin L];
        _lua_stackguard_entry(_L);

        [skin pushLuaRef:refTable ref:((HSSpeechSynthesizer *)sender).callbackRef];
        [skin pushNSObject:(HSSpeechSynthesizer *)sender];
        lua_pushstring(_L, "willSpeakPhoneme");
        lua_pushinteger(_L, phonemeOpcode);
        [skin protectedCallAndError:@"hs.speech:willSpeakPhoneme callback" nargs:3 nresults:0];
        _lua_stackguard_exit(_L);
    }
}

- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender didEncounterErrorAtIndex:(NSUInteger)characterIndex
                                                                        ofString:(NSString *)text
                                                                         message:(NSString *)errorMessage {
    NSLog(@"In error delegate");
    if (((HSSpeechSynthesizer *)sender).callbackRef != LUA_NOREF) {
        LuaSkin      *skin    = [LuaSkin sharedWithState:NULL];
        lua_State    *_L      = [skin L];
        _lua_stackguard_entry(_L);
        NSDictionary *charMap = luaByteToObjCharMap(text);

        [skin pushLuaRef:refTable ref:((HSSpeechSynthesizer *)sender).callbackRef];
        [skin pushNSObject:(HSSpeechSynthesizer *)sender];
        lua_pushstring(_L, "didEncounterError");

        NSArray *index = [[charMap allKeysForObject:[NSNumber numberWithUnsignedInteger:characterIndex]]
                         sortedArrayUsingSelector: @selector(compare:)];
        lua_pushinteger(_L, (lua_Integer)[[index lastObject] unsignedIntegerValue]);

        [skin pushNSObject:text];
        [skin pushNSObject:errorMessage];
        [skin protectedCallAndError:@"hs.speech:didEncounterError callback" nargs:5 nresults:0];
        _lua_stackguard_exit(_L);
    }
}

- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender didEncounterSyncMessage:(__unused NSString *)errorMessage {
    if (((HSSpeechSynthesizer *)sender).callbackRef != LUA_NOREF) {
        LuaSkin      *skin    = [LuaSkin sharedWithState:NULL];
        lua_State    *_L      = [skin L];
        _lua_stackguard_entry(_L);
        NSError      *getError = nil ;
        [skin pushLuaRef:refTable ref:((HSSpeechSynthesizer *)sender).callbackRef];
        [skin pushNSObject:(HSSpeechSynthesizer *)sender];
        lua_pushstring(_L, "didEncounterSync");
// "errorMessage" as a string seems to be broken or at least odd since at least as far back as 10.5:
//      see https://openradar.appspot.com/6524554
// We'll use "recentSync" property instead, though it does introduce the possibility of an error being generated.
//         [skin pushNSObject:errorMessage];
        [skin pushNSObject:[sender objectForProperty:NSSpeechRecentSyncProperty error:&getError]] ;
        if (getError) {
            [skin logWarn:[NSString stringWithFormat:@"Error getting sync # for callback -> %@", [getError localizedDescription]]];
       }
        [skin protectedCallAndError:@"hs.speech:didEncounterSync callback" nargs:3 nresults:0];
        _lua_stackguard_exit(_L);
    }
}

- (void)speechSynthesizer:(NSSpeechSynthesizer *)sender didFinishSpeaking:(BOOL)success {
    LuaSkin             *skin  = [LuaSkin sharedWithState:NULL];
    _lua_stackguard_entry(skin.L);
    HSSpeechSynthesizer *synth = (HSSpeechSynthesizer *)sender ;

    if (synth.callbackRef != LUA_NOREF) {
        lua_State *_L = [skin L];

        [skin pushLuaRef:refTable ref:synth.callbackRef];
        [skin pushNSObject:synth];
        lua_pushstring(_L, "didFinish");
        lua_pushboolean(_L, success);
        [skin protectedCallAndError:@"hs.speech:didFinish callback" nargs:3 nresults:0];
    }
    if (synth.selfRef != LUA_NOREF) {
        synth.UDreferenceCount-- ;
        synth.selfRef = [skin luaUnref:refTable ref:synth.selfRef] ;
    }
    _lua_stackguard_exit(skin.L);
}

@end

#pragma mark - Module Functions

// static int test(lua_State *L) {
//     LuaSkin *skin = [LuaSkin sharedWithState:L];
//     [skin checkArgs:LS_TSTRING, LS_TBREAK];
//     [skin pushNSObject:luaByteToObjCharMap([skin toNSObjectAtIndex:1])];
//     return 1;
// }

/// hs.speech.availableVoices([full]) -> array
/// Function
/// Returns a list of the currently installed voices for speech synthesis.
///
/// Parameters:
///  * full - an optional boolean flag indicating whether or not the full internal names should be returned, or if the shorter versions should be returned.  Defaults to false.
///
/// Returns:
///  * an array of the available voice names.
///
/// Notes:
///  * All of the names that have been encountered thus far follow this pattern for their full name:  `com.apple.speech.synthesis.voice.*name*`.  This prefix is normally suppressed unless you pass in true.
static int availableVoices(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];

    BOOL displayFullName = NO;
    if (lua_isboolean(L, 1)) displayFullName = (BOOL)lua_toboolean(L, 1);

    lua_newtable(L);
    for(NSString *aVoice in [NSSpeechSynthesizer availableVoices]) {
        if (displayFullName)
            [skin pushNSObject:aVoice];
        else
            [skin pushNSObject:getVoiceShortCut(aVoice)];
        lua_rawseti(L, -2, luaL_len(L, -2) + 1);
    }
    return 1;
}

/// hs.speech.attributesForVoice(voice) -> table
/// Function
/// Returns a table containing a variety of properties describing and defining the specified voice.
///
/// Parameters:
///  * voice - the name of the voice to look up attributes for
///
/// Returns:
///  * a table containing key-value pairs which describe the voice specified.  These attributes may include (but is not limited to) information about specific characters recognized, sample text, gender, etc.
///
/// Notes:
///  * All of the names that have been encountered thus far follow this pattern for their full name:  `com.apple.speech.synthesis.voice.*name*`.  You can provide this suffix or not as you prefer when specifying a voice name.
static int attributesForVoice(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING | LS_TNUMBER | LS_TNIL, LS_TBREAK];

    if (lua_type(L, 1) != LUA_TNIL) luaL_checkstring(L, 1); // force number to be a string
    [skin pushNSObject:[NSSpeechSynthesizer attributesForVoice:correctForVoiceShortCut([skin toNSObjectAtIndex:1])]];
    return 1;
}

/// hs.speech.defaultVoice([full]) -> string
/// Function
/// Returns the name of the currently selected default voice for the user.  This voice is the voice selected in the System Preferences for Dictation & Speech as the System Voice.
///
/// Parameters:
///  * full - an optional boolean flag indicating whether or not the full internal name should be returned, or if the shorter version should be returned.  Defaults to false.
///
/// Returns:
///  * the name of the system voice.
///
/// Notes:
///  * All of the names that have been encountered thus far follow this pattern for their full name:  `com.apple.speech.synthesis.voice.*name*`.  This prefix is normally suppressed unless you pass in true.
static int defaultVoice(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];
    BOOL displayFullName = NO;

    if (lua_isboolean(L, 1)) displayFullName = (BOOL)lua_toboolean(L, 1);
    if (displayFullName)
        [skin pushNSObject:[NSSpeechSynthesizer defaultVoice]];
    else
        [skin pushNSObject:getVoiceShortCut([NSSpeechSynthesizer defaultVoice])];
    return 1;
}

/// hs.speech.isAnyApplicationSpeaking() -> boolean
/// Function
/// Returns whether or not the system is currently using a speech synthesizer in any application to generate speech.
///
/// Parameters:
///  * None
///
/// Returns:
///  * a boolean value indicating whether or not any application is currently generating speech with a synthesizer.
///
/// Notes:
///  * See also `hs.speech:speaking`.
static int isAnyApplicationSpeaking(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TBREAK];

    lua_pushboolean(L, [NSSpeechSynthesizer isAnyApplicationSpeaking]);
    return 1;
}

/// hs.speech.new([voice]) -> synthesizerObject
/// Constructor
/// Creates a new speech synthesizer object for use by Hammerspoon.
///
/// Parameters:
///  * voice - an optional string specifying the voice the synthesizer should use for generating speech.  Defaults to the system voice.
///
/// Returns:
///  * a speech synthesizer object or nil, if the system was unable to create a new synthesizer.
///
/// Notes:
///  * All of the names that have been encountered thus far follow this pattern for their full name:  `com.apple.speech.synthesis.voice.*name*`.  You can provide this suffix or not as you prefer when specifying a voice name.
///  * You can change the voice later with the `hs.speech:voice` method.
static int newSpeechSynthesizer(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TSTRING | LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];

    NSString *theVoice = nil;
    if (lua_gettop(L) == 1) {
        luaL_checkstring(L, 1); // force number to be a string
        theVoice = correctForVoiceShortCut([skin toNSObjectAtIndex:1]);
        if (!theVoice) [skin logWarn:@"unable to identify voice from string, defaulting to system voice"];
    }

    HSSpeechSynthesizer *synth = [[HSSpeechSynthesizer alloc] initWithVoice:theVoice];
    if (synth) {
        [skin pushNSObject:synth];
    } else {
        [skin logDebug:@"unable to create synthesizer, returning nil"];
        lua_pushnil(L);
    }
    return 1;
}

#pragma mark - Module Object Methods

/// hs.speech:usesFeedbackWindow([flag]) -> synthesizerObject | boolean
/// Method
/// Gets or sets whether or not the synthesizer uses the speech feedback window.
///
/// Parameters:
///  * flag - an optional boolean indicating whether or not the synthesizer should user the speech feedback window or not.  Defaults to false.
///
/// Returns:
///  * If no parameter is provided, returns the current value; otherwise returns the synthesizer object.
///
/// Notes:
///  * *Special Note:* I am not sure where the visual feedback actually occurs -- I have not been able to locate a feedback window for synthesis in 10.11; however the method is defined and not marked deprecated, so I include it in the module.  If anyone has more information, please file an issue and the documentation will be updated.
static int usesFeedbackWindow(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK];
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);

    if (lua_gettop(L) == 2) {
        synth.usesFeedbackWindow = (BOOL)lua_toboolean(L, 2);
        lua_pushvalue(L, 1);
    } else {
        lua_pushboolean(L, synth.usesFeedbackWindow);
    }
    return 1;
}

/// hs.speech:voice([full] | [voice]) -> synthesizerObject | voice
/// Method
/// Gets or sets the active voice for a synthesizer.
///
/// Parameters:
///  * full  - an optional boolean indicating whether or not you wish the full internal voice name to be returned, or if you want the shorter version.  Defaults to false.
///  * voice - an optional string indicating the name of the voice to change the synthesizer to.
///
/// Returns:
///  * If no parameter is provided (or the parameter is a boolean value), returns the current value; otherwise returns the synthesizer object or nil if the voice could not be changed for some reason.
///
/// Notes:
///  * All of the names that have been encountered thus far follow this pattern for their full name:  `com.apple.speech.synthesis.voice.*name*`.  You can provide this suffix or not as you prefer when specifying a voice name.
///  * The voice cannot be changed while the synthesizer is currently producing output.
///  * If you change the voice while a synthesizer is paused, the current synthesis will be terminated and the voice will be changed.
static int voice(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TSTRING | LS_TNUMBER | LS_TNIL | LS_TOPTIONAL, LS_TBREAK];
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);

    if (lua_gettop(L) == 2 && lua_type(L, 2) != LUA_TBOOLEAN) {
        NSString *theVoice = nil;
        if (lua_type(L, 2) != LUA_TNIL) {
            luaL_checkstring(L, 2); // force number to be a string
            theVoice = correctForVoiceShortCut([skin toNSObjectAtIndex:2]);
            if (!theVoice) [skin logWarn:@"unable to identify voice from string, defaulting to system voice"];
        }
        if([synth setVoice:theVoice]) {
            lua_pushvalue(L, 1);
        } else {
            lua_pushnil(L);
        }
    } else {
        BOOL displayFullName = NO;
        if (lua_isboolean(L, 2)) displayFullName = (BOOL)lua_toboolean(L, 2);
        if (displayFullName)
            [skin pushNSObject:[synth voice]];
        else
            [skin pushNSObject:getVoiceShortCut([synth voice])];
    }
    return 1;
}

/// hs.speech:rate([rate]) -> synthesizerObject | rate
/// Method
/// Gets or sets the synthesizers speaking rate (words per minute).
///
/// Parameters:
///  * rate - an optional number indicating the speaking rate for the synthesizer.
///
/// Returns:
///  * If no parameter is provided, returns the current value; otherwise returns the synthesizer object.
///
/// Notes:
///  * The range of supported rates is not predefined by the Speech Synthesis framework; but the synthesizer may only respond to a limited range of speech rates. Average human speech occurs at a rate of 180.0 to 220.0 words per minute.
static int rate(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);

    if (lua_gettop(L) == 2) {
        synth.rate = (float)lua_tonumber(L, 2);
        lua_pushvalue(L, 1);
    } else {
        lua_pushnumber(L, synth.rate);
    }
    return 1;
}

/// hs.speech:volume([volume]) -> synthesizerObject | volume
/// Method
/// Gets or sets the synthesizers speaking volume.
///
/// Parameters:
///  * volume - an optional number between 0.0 and 1.0 indicating the speaking volume for the synthesizer.
///
/// Returns:
///  * If no parameter is provided, returns the current value; otherwise returns the synthesizer object.
///
/// Notes:
///  * Volume units lie on a scale that is linear with amplitude or voltage. A doubling of perceived loudness corresponds to a doubling of the volume.
static int volume(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);

    if (lua_gettop(L) == 2) {
        float vol = (float)lua_tonumber(L, 2);
        if (vol < 0.0 || vol > 1.0) {
            return luaL_argerror(L, 2, "must be between 0.0 and 1.0 inclusive");
        } else {
            synth.volume = vol;
        }
        lua_pushvalue(L, 1);
    } else {
        lua_pushnumber(L, synth.volume);
    }
    return 1;
}

/// hs.speech:speaking() -> boolean
/// Method
/// Returns whether or not this synthesizer is currently generating speech.
///
/// Parameters:
///  * None
///
/// Returns:
///  * A boolean value indicating whether or not this synthesizer is currently generating speech.
///
/// Notes:
///  * See also `hs.speech.isAnyApplicationSpeaking`.
static int speaking(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);

    lua_pushboolean(L, synth.speaking);
    return 1;
}

/// hs.speech:setCallback(fn) -> synthesizerObject
/// Method
/// Sets or removes a callback function for the synthesizer.
///
/// Parameters:
///  * fn - a function to set as the callback for this speech synthesizer.  If the value provided is nil, any currently existing callback function is removed.
///
/// Returns:
///  * the synthesizer object
///
/// Notes:
///  * The callback function should expect between 3 and 5 arguments and should not return anything.  The first two arguments will always be the synthesizer object itself and a string indicating the activity which has caused the callback.  The value of this string also dictates the remaining arguments as follows:
///
///    * "willSpeakWord"     - Sent just before a synthesized word is spoken through the sound output device.
///      * provides 3 additional arguments: startIndex, endIndex, and the full text being spoken.
///      * startIndex and endIndex can be used as `string.sub(text, startIndex, endIndex)` to get the specific word being spoken.
///
///    * "willSpeakPhoneme"  - Sent just before a synthesized phoneme is spoken through the sound output device.
///      * provides 1 additional argument: the opcode of the phoneme about to be spoken.
///      * this callback message will only occur when using Macintalk voices; modern higher quality voices are not phonetically based and will not generate this message.
///      * the opcode can be tied to a specific phoneme by looking it up in the table returned by `hs.speech:phoneticSymbols`.
///
///    * "didEncounterError" - Sent when the speech synthesizer encounters an error in text being synthesized.
///      * provides 3 additional arguments: the index in the original text where the error occurred, the text being spoken, and an error message.
///      * *Special Note:* I have never been able to trigger this callback message, even with malformed embedded command sequences, so... looking for validation of the code or fixes.  File an issue if you have suggestions.
///
///    * "didEncounterSync"  - Sent when the speech synthesizer encounters an embedded synchronization command.
///      * provides 1 additional argument: the synchronization number provided in the text.
///      * A synchronization number can be embedded in text to be spoken by including `[[sync #]]` in the text where you wish the callback to occur.  The number is limited to 32 bits and can be presented as a base 10 or base 16 number (prefix with 0x).
///
///    * "didFinish"         - Sent when the speech synthesizer finishes speaking through the sound output device.
///      * provides 1 additional argument: a boolean flag indicating whether or not the synthesizer finished because synthesis is complete (true) or was stopped early with `hs.speech:stop` (false).
static int setCallback(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TFUNCTION | LS_TNIL, LS_TBREAK];
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);

    // in either case, we need to remove an existing callback, so...
    synth.callbackRef = [skin luaUnref:refTable ref:synth.callbackRef];
    if (lua_type(L, 2) == LUA_TFUNCTION) {
        lua_pushvalue(L, 2);
        synth.callbackRef = [skin luaRef:refTable];
    }
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.speech:speak(textToSpeak) -> synthesizerObject
/// Method
/// Starts speaking the provided text through the system's current audio device.
///
/// Parameters:
///  * textToSpeak - the text to speak with the synthesizer.
///
/// Returns:
///  * the synthesizer object
static int startSpeakingString(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER, LS_TBREAK];
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);

    luaL_checkstring(L, 2); // force number to be a string
    NSString *theText = [skin toNSObjectAtIndex:2];
    if (!theText) return luaL_error(L, "invalid speech text, evaluates to nil");

    if ([synth startSpeakingString:theText]) {
        lua_pushvalue(L, 1);
        if (synth.selfRef == LUA_NOREF) {
            synth.UDreferenceCount++ ;
            synth.selfRef = [skin luaRef:refTable] ;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/// hs.speech:speakToFile(textToSpeak, destination) -> synthesizerObject
/// Method
/// Starts speaking the provided text and saves the audio as an AIFF file.
///
/// Parameters:
///  * textToSpeak - the text to speak with the synthesizer.
///  * destination - the path to the file to create and store the audio data in.
///
/// Returns:
///  * the synthesizer object
static int startSpeakingStringToURL(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER, LS_TSTRING | LS_TNUMBER, LS_TBREAK];
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);

    luaL_checkstring(L, 2); // force number to be a string
    luaL_checkstring(L, 3); // force number to be a string
    NSString *theText = [skin toNSObjectAtIndex:2];
    NSString *theFile = [skin toNSObjectAtIndex:3];
    if (!theText) return luaL_error(L, "invalid speech text, evaluates to nil");
    if (!theFile) return luaL_error(L, "invalid file name, evaluates to nil");

    if ([synth startSpeakingString:theText
                             toURL:[NSURL fileURLWithPath:[theFile stringByExpandingTildeInPath]
                                              isDirectory:NO]]) {
        lua_pushvalue(L, 1);
        if (synth.selfRef == LUA_NOREF) {
            synth.UDreferenceCount++ ;
            synth.selfRef = [skin luaRef:refTable] ;
        }
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/// hs.speech:pause([where]) -> synthesizerObject
/// Method
/// Pauses the output of the speech synthesizer.
///
/// Parameters:
///  * where - an optional string indicating when to pause the audio output (defaults to "immediate").  The string can be one of the following:
///    * "immediate" - pauses output immediately.  If in the middle of a word, when speech is resumed, the word will be repeated.
///    * "word"      - pauses at the end of the current word.
///    * "sentence"  - pauses at the end of the current sentence.
///
/// Returns:
///  * the synthesizer object
static int pauseSpeakingAtBoundary(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);

    NSSpeechBoundary stopWhere = NSSpeechImmediateBoundary;
    if (lua_gettop(L) == 2) {
        luaL_checkstring(L, 2); // force number to be a string
        NSString *where = [skin toNSObjectAtIndex:2];
        if ([where isEqualToString:@"immediate"]) {
            stopWhere = NSSpeechImmediateBoundary;
        } else if ([where isEqualToString:@"word"]) {
            stopWhere = NSSpeechWordBoundary;
        } else if ([where isEqualToString:@"sentence"]) {
            stopWhere = NSSpeechSentenceBoundary;
        } else {
            [skin logWarn:@"invalid boundary; pausing immediately"];
        }
    }
    [synth pauseSpeakingAtBoundary:stopWhere];
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.speech:stop([where]) -> synthesizerObject
/// Method
/// Stops the output of the speech synthesizer.
///
/// Parameters:
///  * where - an optional string indicating when to stop the audio output (defaults to "immediate").  The string can be one of the following:
///    * "immediate" - stops output immediately.
///    * "word"      - stops at the end of the current word.
///    * "sentence"  - stops at the end of the current sentence.
///
/// Returns:
///  * the synthesizer object
static int stopSpeakingAtBoundary(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);

    NSSpeechBoundary stopWhere = NSSpeechImmediateBoundary;
    if (lua_gettop(L) == 2) {
        luaL_checkstring(L, 2); // force number to be a string
        NSString *where = [skin toNSObjectAtIndex:2];
        if ([where isEqualToString:@"immediate"]) {
            stopWhere = NSSpeechImmediateBoundary;
        } else if ([where isEqualToString:@"word"]) {
            stopWhere = NSSpeechWordBoundary;
        } else if ([where isEqualToString:@"sentence"]) {
            stopWhere = NSSpeechSentenceBoundary;
        } else {
            [skin logWarn:@"invalid boundary; stopping immediately"];
        }
    }
    [synth stopSpeakingAtBoundary:stopWhere];
    if (synth.selfRef != LUA_NOREF) {
        synth.UDreferenceCount-- ;
        synth.selfRef = [skin luaUnref:refTable ref:synth.selfRef] ;
    }
    lua_pushvalue(L, 1);
    return 1;
}

/// hs.speech:continue() -> synthesizerObject
/// Method
/// Resumes a paused speech synthesizer.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the synthesizer object
static int continueSpeaking(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);

    [synth continueSpeaking];
    lua_pushvalue(L, 1);
    return 1;
}

// Really just stopAt with immediateBoundary set -- even gives same delegate results
//
// static int stopSpeaking(lua_State *L) {
//     HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);
//     LuaSkin *skin = [LuaSkin sharedWithState:L];
//     [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
//     [synth stopSpeaking];
//     lua_pushvalue(L, 1);
//     return 1;
// }

/// hs.speech:phonemes(text) -> string
/// Method
/// Returns the phonemes which would be spoken if the text were to be synthesized.
///
/// Parameters:
///  * text - the text to tokenize into phonemes.
///
/// Returns:
///  * the text converted into the series of phonemes the synthesizer would use for the provided text if it were to be synthesized.
///
/// Notes:
///  * This method only returns a phonetic representation of the text if a Macintalk voice has been selected.  The more modern higher quality voices do not use a phonetic representation and an empty string will be returned if this method is used.
///  * You can modify the phonetic representation and feed it into `hs.speech:speak` if you find that the default interpretation is not correct.  You will need to set the input mode to Phonetic by prefixing the text with "[[inpt PHON]]".
///  * The specific phonetic symbols recognized by a given voice can be queried by examining the array returned by `hs.speech:phoneticSymbols` after setting an appropriate voice.
static int phonemesFromText(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING | LS_TNUMBER, LS_TBREAK];
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);

    luaL_checkstring(L, 2); // force number to be a string
    NSString *theText = [skin toNSObjectAtIndex:2];
    if (!theText) return luaL_error(L, "invalid speech text, evaluates to nil");
    [skin pushNSObject:[synth phonemesFromText:theText]];
    return 1;
}

/// hs.speech:isSpeaking() -> boolean | nil
/// Method
/// Returns whether or not the synthesizer is currently speaking, either to an audio device or to a file.
///
/// Parameters:
///  * None
///
/// Returns:
///  * True or false indicating whether or not the synthesizer is currently producing speech.  If there is an error, returns nil.
///
/// Notes:
///  * If an error occurs retrieving this value, the details will be logged in the system logs which can be viewed with the Console application.  You can also have such messages logged to the Hammerspoon console by setting the module's log level to at least Information (This can be done with the following, or similar, command: `hs.speech.log.level = 3`.  See `hs.logger` for more information)
static int isSpeaking(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);

    NSError *theError = nil ;
    NSDictionary *status = [synth objectForProperty:NSSpeechStatusProperty error:&theError] ;
    if (theError) {
        [skin logInfo:[NSString stringWithFormat:@"Unable to query synthesizer status -> %@", [theError localizedDescription]]];
        lua_pushnil(L) ;
    } else {
        NSNumber *result = [status objectForKey:NSSpeechStatusOutputBusy] ;
        if (result) {
            lua_pushboolean(L, [result boolValue]) ;
        } else {
            [skin logInfo:[NSString stringWithFormat:@"Key \"%@\" missing from synthesizer status", NSSpeechStatusOutputBusy]];
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

/// hs.speech:isPaused() -> boolean | nil
/// Method
/// Returns whether or not the synthesizer is currently paused.
///
/// Parameters:
///  * None
///
/// Returns:
///  * True or false indicating whether or not the synthesizer is currently paused.  If there is an error, returns nil.
///
/// Notes:
///  * If an error occurs retrieving this value, the details will be logged in the system logs which can be viewed with the Console application.  You can also have such messages logged to the Hammerspoon console by setting the module's log level to at least Information (This can be done with the following, or similar, command: `hs.speech.log.level = 3`.  See `hs.logger` for more information)
static int isPaused(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);

    NSError *theError = nil ;
    NSDictionary *status = [synth objectForProperty:NSSpeechStatusProperty error:&theError] ;
    if (theError) {
        [skin logInfo:[NSString stringWithFormat:@"Unable to query synthesizer status -> %@", [theError localizedDescription]]];
        lua_pushnil(L) ;
    } else {
        NSNumber *result = [status objectForKey:NSSpeechStatusOutputPaused] ;
        if (result) {
            lua_pushboolean(L, [result boolValue]) ;
        } else {
            [skin logInfo:[NSString stringWithFormat:@"Key \"%@\" missing from synthesizer status", NSSpeechStatusOutputPaused]];
            lua_pushnil(L) ;
        }
    }
    return 1 ;
}

/// hs.speech:phoneticSymbols() -> array | nil
/// Method
/// Returns an array of the phonetic symbols recognized by the synthesizer for the current voice.
///
/// Parameters:
///  * None
///
/// Returns:
///  * For MacinTalk voices, this method will return an array of the recognized symbols for the currently selected voice.  For the modern higher quality voices, or if an error occurs, returns nil.
///
/// Notes:
///  * Each entry in the array of phonemes returned will contain the following keys:
///    * Symbol      - The textual representation of this phoneme when returned by `hs.speech:phonemes` or that you should use for this sound when crafting a phonetic string yourself.
///    * Opcode      - The numeric opcode passed to the callback for the "willSpeakPhoneme" message corresponding to this phoneme.
///    * Example     - An example word which contains the sound the phoneme represents
///    * HiliteEnd   - The character position in the Example where this phoneme's sound begins
///    * HiliteStart - The character position in the Example where this phoneme's sound ends
///
///  * Only the older, MacinTalk style voices support phonetic text.  The more modern, higher quality voices are not rendered phonetically and will return nil for this method.
///
///  * If an error occurs retrieving this value, the details will be logged in the system logs which can be viewed with the Console application.  You can also have such messages logged to the Hammerspoon console by setting the module's log level to at least Information (This can be done with the following, or similar, command: `hs.speech.log.level = 3`.  See `hs.logger` for more information)
static int phoneticSymbols(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);

    NSError *theError = nil ;
    NSArray *phoneticList = [synth objectForProperty:NSSpeechPhonemeSymbolsProperty error:&theError] ;
    if (theError) {
        [skin logInfo:[NSString stringWithFormat:@"Unable to query synthesizer for phonetic symbols -> %@", [theError localizedDescription]]];
        lua_pushnil(L) ;
    } else {
        [skin pushNSObject:phoneticList] ;
    }
    return 1 ;
}

/// hs.speech:pitch([pitch]) -> synthsizerObject | pitch | nil
/// Method
/// Gets or sets the base pitch for the synthesizer's voice.
///
/// Parameters:
///  * pitch - an optional number indicating the pitch base for the synthesizer.
///
/// Returns:
///  * If no parameter is provided, returns the current value; otherwise returns the synthesizer object.  Returns nil if an error occurs.
///
/// Notes:
///  * Typical voice frequencies range from around 90 hertz for a low-pitched male voice to perhaps 300 hertz for a high-pitched child’s voice. These frequencies correspond to approximate pitch values in the ranges of 30.000 to 40.000 and 55.000 to 65.000, respectively.
///
///  * If an error occurs retrieving or setting this value, the details will be logged in the system logs which can be viewed with the Console application.  You can also have such messages logged to the Hammerspoon console by setting the module's log level to at least Information (This can be done with the following, or similar, command: `hs.speech.log.level = 3`.  See `hs.logger` for more information)
static int pitchBase(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);

    NSError *theError = nil ;
    if (lua_gettop(L) == 2) {
        BOOL result = [synth setObject:[NSNumber numberWithDouble:lua_tonumber(L, 2)]
                           forProperty:NSSpeechPitchBaseProperty error:&theError];
        if (theError) {
            [skin logWarn:[NSString stringWithFormat:@"Error setting pitchBase -> %@", [theError localizedDescription]]];
            lua_pushnil(L);
        } else {
            if (result) {
                lua_pushvalue(L, 1);
            } else {
                lua_pushnil(L);
            }
        }
    } else {
        [skin pushNSObject:[synth objectForProperty:NSSpeechPitchBaseProperty error:&theError]];
        if (theError) {
            [skin logInfo:[NSString stringWithFormat:@"Error getting pitchBase -> %@", [theError localizedDescription]]];
        }
    }
    return 1;
}

/// hs.speech:modulation([modulation]) -> synthsizerObject | modulation | nil
/// Method
/// Gets or sets the pitch modulation for the synthesizer's voice.
///
/// Parameters:
///  * modulation - an optional number indicating the pitch modulation for the synthesizer.
///
/// Returns:
///  * If no parameter is provided, returns the current value; otherwise returns the synthesizer object.  Returns nil if an error occurs.
///
/// Notes:
///  * Pitch modulation is expressed as a floating-point value in the range of 0.000 to 127.000. These values correspond to MIDI note values, where 60.000 is equal to middle C on a piano scale. The most useful speech pitches fall in the range of 40.000 to 55.000. A pitch modulation value of 0.000 corresponds to a monotone in which all speech is generated at the frequency corresponding to the speech pitch. Given a speech pitch value of 46.000, a pitch modulation of 2.000 would mean that the widest possible range of pitches corresponding to the actual frequency of generated text would be 44.000 to 48.000.
///
///  * If an error occurs retrieving or setting this value, the details will be logged in the system logs which can be viewed with the Console application.  You can also have such messages logged to the Hammerspoon console by setting the module's log level to at least Information (This can be done with the following, or similar, command: `hs.speech.log.level = 3`.  See `hs.logger` for more information)
static int pitchMod(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TNUMBER | LS_TOPTIONAL, LS_TBREAK];
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);

    NSError *theError = nil ;
    if (lua_gettop(L) == 2) {
        BOOL result = [synth setObject:[NSNumber numberWithDouble:lua_tonumber(L, 2)]
                           forProperty:NSSpeechPitchModProperty error:&theError];
        if (theError) {
            [skin logWarn:[NSString stringWithFormat:@"Error setting pitchMod -> %@", [theError localizedDescription]]];
            lua_pushnil(L);
        } else {
            if (result) {
                lua_pushvalue(L, 1);
            } else {
                lua_pushnil(L);
            }
        }
    } else {
        [skin pushNSObject:[synth objectForProperty:NSSpeechPitchModProperty error:&theError]];
        if (theError) {
            [skin logInfo:[NSString stringWithFormat:@"Error getting pitchMod -> %@", [theError localizedDescription]]];
        }
    }
    return 1;
}

/// hs.speech:reset() -> synthsizerObject | nil
/// Method
/// Reset a synthesizer back to its default state.
///
/// Parameters:
///  * None
///
/// Returns:
///  * Returns the synthesizer object.  Returns nil if an error occurs.
///
/// Notes:
///  * This method will reset a synthesizer to its default state, including pitch, modulation, volume, rate, etc.
///  * The changes go into effect immediately, if queried, but will not affect a synthesis in progress.
///
///  * If an error occurs retrieving or setting this value, the details will be logged in the system logs which can be viewed with the Console application.  You can also have such messages logged to the Hammerspoon console by setting the module's log level to at least Information (This can be done with the following, or similar, command: `hs.speech.log.level = 3`.  See `hs.logger` for more information)
static int reset(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK];
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);

    NSError *theError = nil ;
    BOOL result = [synth setObject:nil forProperty:NSSpeechResetProperty error:&theError];
    if (theError) {
        [skin logWarn:[NSString stringWithFormat:@"Error resetting synthesizer -> %@", [theError localizedDescription]]];
        lua_pushnil(L);
    } else {
        if (result) {
            lua_pushvalue(L, 1);
        } else {
            lua_pushnil(L);
        }
    }
    return 1;
}

#pragma mark - Lua<->NSObject Conversion Functions

static int pushHSSpeechSynthesizer(lua_State *L, id obj) {
    HSSpeechSynthesizer *synth = obj;
    synth.UDreferenceCount++;
    void** synthPtr = lua_newuserdata(L, sizeof(HSSpeechSynthesizer *));
    *synthPtr = (__bridge_retained void *)synth;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

#pragma mark - Hammerspoon Infrastructure

static int userdata_tostring(lua_State* L) {
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, [synth voice], (void *)synth]];
    return 1;
}

static int userdata_eq(lua_State* L) {
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        HSSpeechSynthesizer *synth1 = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 1);
        HSSpeechSynthesizer *synth2 = get_objectFromUserdata(__bridge HSSpeechSynthesizer, L, 2);
        lua_pushboolean(L, [synth1 isEqualTo:synth2]);
    } else {
        lua_pushboolean(L, NO);
    }
    return 1;
}

static int userdata_gc(lua_State* L) {
    HSSpeechSynthesizer *synth = get_objectFromUserdata(__bridge_transfer HSSpeechSynthesizer, L, 1);
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    synth.UDreferenceCount--;

    if (synth.UDreferenceCount == 0) {
        synth.callbackRef = [skin luaUnref:refTable ref:synth.callbackRef];
        if (synth.selfRef != LUA_NOREF) {
            synth.selfRef = [skin luaUnref:refTable ref:synth.selfRef] ;
        }
        // If I'm reading the docs correctly, delegate isn't a weak assignment, so we'd better
        // clear it to make sure we don't create a self-retaining object...
        synth.delegate = nil;
    }

// Remove the Metatable so future use of the variable in Lua won't think its valid
    lua_pushnil(L);
    lua_setmetatable(L, 1);

    return 0;
}

// static int meta_gc(lua_State* __unused L) {
//     return 0;
// }

// Metatable for userdata objects
static const luaL_Reg userdata_metaLib[] = {
    {"usesFeedbackWindow", usesFeedbackWindow},
    {"voice", voice},
    {"rate", rate},
    {"volume", volume},
    {"speaking", speaking},
    {"setCallback", setCallback},
    {"speak", startSpeakingString},
    {"speakToFile", startSpeakingStringToURL},
    {"pause", pauseSpeakingAtBoundary},
    {"continue", continueSpeaking},
    {"stop", stopSpeakingAtBoundary},
    {"phonemes", phonemesFromText},
    {"isSpeaking", isSpeaking},
    {"isPaused", isPaused},
    {"phoneticSymbols", phoneticSymbols},
    {"pitch", pitchBase},
    {"modulation", pitchMod},
    {"reset", reset},

    {"__tostring", userdata_tostring},
    {"__eq", userdata_eq},
    {"__gc", userdata_gc},
    {NULL, NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"availableVoices", availableVoices},
    {"attributesForVoice", attributesForVoice},
    {"defaultVoice", defaultVoice},
    {"isAnyApplicationSpeaking", isAnyApplicationSpeaking},
    {"new", newSpeechSynthesizer},
    {NULL, NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs_speech_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    [skin registerPushNSHelper:pushHSSpeechSynthesizer forClass:"HSSpeechSynthesizer"];

    return 1;
}
