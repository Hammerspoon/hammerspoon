@import Cocoa ;
@import CommonCrypto.CommonDigest ;
@import CommonCrypto.CommonHMAC ;
@import zlib ;
@import LuaSkin ;

// When adding a new hash type, you should only need to update a couple of areas...
// they are labeled with ADD_NEW_HASH_HERE

// uncomment to include deprecated/less-common hash types (see hashLookupTable below)
// #define INCLUDE_HISTORICAL

#include "algorithms.h"
#include "sha3.h"
// ADD_NEW_HASH_HERE -- assuming new hash code is in its own .m and .h files

static const char * const USERDATA_TAG = "hs.hash" ;
static LSRefTable         refTable     = LUA_NOREF ;

#define get_objectFromUserdata(objType, L, idx, tag) (objType*)*((void**)luaL_checkudata(L, idx, tag))

#pragma mark - Support Functions and Classes

static const hashEntry_t hashLookupTable[] = {
#ifdef INCLUDE_HISTORICAL
    { "MD2",        init_MD2,        append_MD2,        finish_MD2        },
    { "MD4",        init_MD4,        append_MD4,        finish_MD4        },
    { "SHA224",     init_SHA224,     append_SHA224,     finish_SHA224     },
    { "SHA384",     init_SHA384,     append_SHA384,     finish_SHA384     },
    { "hmacSHA224", init_hmacSHA224, append_hmac,       finish_hmacSHA224 },
    { "hmacSHA384", init_hmacSHA384, append_hmac,       finish_hmacSHA384 },
#endif

    { "CRC32",      init_CRC32,      append_CRC32,      finish_CRC32      },
    { "MD5",        init_MD5,        append_MD5,        finish_MD5        },
    { "SHA1",       init_SHA1,       append_SHA1,       finish_SHA1       },
    { "SHA256",     init_SHA256,     append_SHA256,     finish_SHA256     },
    { "SHA512",     init_SHA512,     append_SHA512,     finish_SHA512     },
    { "hmacMD5",    init_hmacMD5,    append_hmac,       finish_hmacMD5    },
    { "hmacSHA1",   init_hmacSHA1,   append_hmac,       finish_hmacSHA1   },
    { "hmacSHA256", init_hmacSHA256, append_hmac,       finish_hmacSHA256 },
    { "hmacSHA512", init_hmacSHA512, append_hmac,       finish_hmacSHA512 },

    { "SHA3_224",   init_SHA3_224,   append_SHA3,       finish_SHA3_224   },
    { "SHA3_256",   init_SHA3_256,   append_SHA3,       finish_SHA3_256   },
    { "SHA3_384",   init_SHA3_384,   append_SHA3,       finish_SHA3_384   },
    { "SHA3_512",   init_SHA3_512,   append_SHA3,       finish_SHA3_512   },
// ADD_NEW_HASH_HERE -- label(s) for Hammerspoon and functions for initializing, appending to, and finishing
} ;

static const NSUInteger knownHashCount = sizeof(hashLookupTable) / sizeof(hashEntry_t) ;

@interface HSHashObject : NSObject
@property int        selfRefCount ;
@property NSUInteger hashType ;
@property NSData     *secret ;
@property void       *context ;
@property NSData     *value ;
@end

@implementation HSHashObject
- (instancetype)initHashType:(NSUInteger)hashType withSecret:(NSData *)secret {
    self = [super init] ;
    if (self) {
        _selfRefCount = 0 ;
        _hashType     = hashType ;
        _secret       = secret ;
        _context      = (hashLookupTable[_hashType].initFn)(secret) ;
        _value        = nil ;
    }
    return self ;
}

- (void)append:(NSData *)data {
    (hashLookupTable[_hashType].appendFn)(_context, data) ;
}

- (void)finish {
    _value = (hashLookupTable[_hashType].finishFn)(_context) ;
    _context = NULL ; // it was freed in the finish function
}
@end

#pragma mark - Module Functions

/// hs.hash.new(hash, [secret]) -> hashObject
/// Constructor
/// Creates a new context for the specified hash function.
///
/// Parameters:
///  * `hash`    - a string specifying the name of the hash function to use. This must be one of the string values found in the [hs.hash.types](#types) constant.
///  * `secret`  - an optional string specifying the shared secret to prepare the hmac hash function with. For all other hash types this field is ignored. Leaving this parameter off when specifying an hmac hash function is equivalent to specifying an empty secret or a secret composed solely of null values.
///
/// Returns:
///  * the new hash object
static int hash_new(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TSTRING, LS_TSTRING | LS_TOPTIONAL, LS_TBREAK] ;
    NSString *hashName = [skin toNSObjectAtIndex:1] ;
    NSData   *secret   = nil ;
    if (lua_gettop(L) == 2) secret = [skin toNSObjectAtIndex:2 withOptions:LS_NSLuaStringAsDataOnly] ;

    NSUInteger hashType  = 0 ;
    BOOL       hashFound = NO ;

    for (NSUInteger i = 0 ; i < knownHashCount ; i++) {
        NSString *label = @(hashLookupTable[i].hashName) ;
        if ([hashName caseInsensitiveCompare:label] == NSOrderedSame) {
            hashFound = YES ;
            hashType = i ;
            break ;
        }
    }
    if (hashFound) {
        HSHashObject *object = [[HSHashObject alloc] initHashType:hashType
                                                          withSecret:secret] ;
        [skin pushNSObject:object] ;
    } else {
        return luaL_argerror(L, 1, "unrecognized hash type") ;
    }
    return 1 ;
}

#pragma mark - Module Methods

/// hs.hash:append(data) -> hashObject | nil, error
/// Method
/// Adds the provided data to the input of the hash function currently in progress for the hashObject.
///
/// Parameters:
///  * `data` - a string containing the data to add to the hash functions input.
///
/// Returns:
///  * the hash object, or if the hash has already been calculated (finished), nil and an error string
static int hash_append(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    HSHashObject *object = [skin toNSObjectAtIndex:1] ;
    NSData       *data   = [skin toNSObjectAtIndex:2 withOptions:LS_NSLuaStringAsDataOnly] ;

    if (!object.value) {
        [object append:data] ;
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "hash calculation completed") ;
        return 2 ;
    }

    lua_pushvalue(L, 1) ;
    return 1 ;
}


/// hs.hash:appendFile(path) -> hashObject | nil, error
/// Method
/// Adds the contents of the file at the specified path to the input of the hash function currently in progress for the hashObject.
///
/// Parameters:
///  * `path` - a string containing the path of the file to add to the hash functions input.
///
/// Returns:
///  * the hash object
static int hash_appendFile(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TSTRING, LS_TBREAK] ;
    HSHashObject *object = [skin toNSObjectAtIndex:1] ;
    NSString     *path   = [skin toNSObjectAtIndex:2] ;

    if (!object.value) {
        path = path.stringByExpandingTildeInPath.stringByResolvingSymlinksInPath ;
        NSError *error = nil ;
        NSData  *data  = [NSData dataWithContentsOfFile:path options:NSDataReadingUncached error:&error] ;
        if (!error) {
            [object append:data] ;
        } else {
            lua_pushnil(L) ;
            lua_pushfstring(L, "error reading contents of %s: %s", path.UTF8String, error.localizedDescription.UTF8String) ;
            return 2 ;
        }
    } else {
        lua_pushnil(L) ;
        lua_pushstring(L, "hash calculation completed") ;
        return 2 ;
    }

    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.hash:finish() -> hashObject
/// Method
/// Finalizes the hash and computes the resulting value.
///
/// Parameters:
///  * None
///
/// Returns:
///  * the hash object
///
/// Notes:
///  * a hash that has been finished can no longer have data appended to it.
static int hash_finish(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSHashObject *object = [skin toNSObjectAtIndex:1] ;

    if (!object.value) [object finish] ;

    lua_pushvalue(L, 1) ;
    return 1 ;
}

/// hs.hash:value([binary]) -> string | nil
/// Method
/// Returns the value of a completed hash, or nil if it is still in progress.
///
/// Parameters:
///  * `binary` - an optional boolean, default false, specifying whether or not the value should be provided as raw binary bytes (true) or as a string of hexadecimal numbers (false).
///
/// Returns:
///  * a string containing the hash value or nil if the hash has not been finished.
static int hash_value(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBOOLEAN | LS_TOPTIONAL, LS_TBREAK] ;
    HSHashObject *object  = [skin toNSObjectAtIndex:1] ;
    BOOL         inBinary = (lua_gettop(L) == 2) ? (BOOL)(lua_toboolean(L, 2)) : NO ;

    if (object.value) {
        if (inBinary) {
            [skin pushNSObject:object.value] ;
        } else {
            NSMutableString* asHex = [NSMutableString stringWithCapacity:(object.value.length * 2)] ;
            [object.value enumerateByteRangesUsingBlock:^(const void *bytes, NSRange range, __unused BOOL *stop) {
                for (NSUInteger i = 0; i < range.length; ++i) {
                    [asHex appendFormat:@"%02x", ((const uint8_t*)bytes)[i]];
                }
            }];
            [skin pushNSObject:asHex] ;
        }
    } else {
        lua_pushnil(L) ;
    }
    return 1 ;
}

/// hs.hash:type() -> string
/// Method
/// Returns the name of the hash type the object refers to
///
/// Parameters:
///  * None
///
/// Returns:
///  * a string containing the hash type name.
static int hash_type(lua_State *L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    [skin checkArgs:LS_TUSERDATA, USERDATA_TAG, LS_TBREAK] ;
    HSHashObject *object = [skin toNSObjectAtIndex:1] ;
    lua_pushstring(L, hashLookupTable[object.hashType].hashName) ;
    return 1 ;
}

#pragma mark - Module Constants

// documented in hash.lua
static int hash_types(lua_State *L) {
    lua_newtable(L) ;
    for (NSUInteger i = 0 ; i < knownHashCount ; i++) {
        lua_pushstring(L, hashLookupTable[i].hashName) ;
        lua_rawseti(L, -2, luaL_len(L, -2) + 1) ;
    }
    return 1 ;
}

#pragma mark - Lua<->NSObject Conversion Functions
// These must not throw a lua error to ensure LuaSkin can safely be used from Objective-C
// delegates and blocks.

static int pushHSHashObject(lua_State *L, id obj) {
    HSHashObject *value = obj;
    value.selfRefCount++ ;
    void** valuePtr = lua_newuserdata(L, sizeof(HSHashObject *));
    *valuePtr = (__bridge_retained void *)value;
    luaL_getmetatable(L, USERDATA_TAG);
    lua_setmetatable(L, -2);
    return 1;
}

static id toHSHashObjectFromLua(lua_State *L, int idx) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSHashObject *value ;
    if (luaL_testudata(L, idx, USERDATA_TAG)) {
        value = get_objectFromUserdata(__bridge HSHashObject, L, idx, USERDATA_TAG) ;
    } else {
        [skin logError:[NSString stringWithFormat:@"expected %s object, found %s", USERDATA_TAG,
                                                   lua_typename(L, lua_type(L, idx))]] ;
    }
    return value ;
}

#pragma mark - Hammerspoon/Lua Infrastructure

static int userdata_tostring(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    HSHashObject *obj = [skin luaObjectAtIndex:1 toClass:"HSHashObject"] ;
    NSString *title = [NSString stringWithFormat:@"%s", hashLookupTable[obj.hashType].hashName] ;
    if (!obj.value) {
        title = [NSString stringWithFormat:@"%@ <in-progress>", title];
    }
    [skin pushNSObject:[NSString stringWithFormat:@"%s: %@ (%p)", USERDATA_TAG, title, lua_topointer(L, 1)]] ;
    return 1 ;
}

static int userdata_eq(lua_State* L) {
// can't get here if at least one of us isn't a userdata type, and we only care if both types are ours,
// so use luaL_testudata before the macro causes a lua error
    if (luaL_testudata(L, 1, USERDATA_TAG) && luaL_testudata(L, 2, USERDATA_TAG)) {
        LuaSkin *skin = [LuaSkin sharedWithState:L] ;
        HSHashObject *obj1 = [skin luaObjectAtIndex:1 toClass:"HSHashObject"] ;
        HSHashObject *obj2 = [skin luaObjectAtIndex:2 toClass:"HSHashObject"] ;
        lua_pushboolean(L, [obj1 isEqualTo:obj2]) ;
    } else {
        lua_pushboolean(L, NO) ;
    }
    return 1 ;
}

static int userdata_gc(lua_State* L) {
    HSHashObject *obj = get_objectFromUserdata(__bridge_transfer HSHashObject, L, 1, USERDATA_TAG) ;
    if (obj) {
        obj. selfRefCount-- ;
        if (obj.selfRefCount == 0) {
            if (obj.context) [obj finish] ;
            obj = nil ;
        }
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
    {"append",     hash_append},
    {"appendFile", hash_appendFile},
    {"finish",     hash_finish},
    {"value",      hash_value},
    {"type",       hash_type},

    {"__tostring", userdata_tostring},
    {"__eq",       userdata_eq},
    {"__gc",       userdata_gc},
    {NULL,         NULL}
};

// Functions for returned object when module loads
static luaL_Reg moduleLib[] = {
    {"new",         hash_new},
    {NULL,          NULL}
};

// // Metatable for module, if needed
// static const luaL_Reg module_metaLib[] = {
//     {"__gc", meta_gc},
//     {NULL,   NULL}
// };

int luaopen_hs_libhash(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L] ;
    refTable = [skin registerLibraryWithObject:USERDATA_TAG
                                     functions:moduleLib
                                 metaFunctions:nil    // or module_metaLib
                               objectFunctions:userdata_metaLib];

    hash_types(L) ; lua_setfield(L, -2, "types") ;

    [skin registerPushNSHelper:pushHSHashObject         forClass:"HSHashObject"];
    [skin registerLuaObjectHelper:toHSHashObjectFromLua forClass:"HSHashObject"
                                             withUserdataMapping:USERDATA_TAG];

    return 1;
}
