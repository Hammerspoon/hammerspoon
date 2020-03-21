@import Cocoa ;
@import LuaSkin ;

#import <AVFoundation/AVFoundation.h>

static int refTable = LUA_NOREF;

#pragma mark - Module Functions

/// hs.audiounit.getAudioEffectNames() -> table
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
static int getAudioEffectNames(lua_State *L) {
    
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

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"getAudioEffectNames", getAudioEffectNames},
    {NULL, NULL}
};

int luaopen_hs_audiounit_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    refTable = [skin registerLibrary:moduleLib metaFunctions:nil] ;
    return 1;
}

