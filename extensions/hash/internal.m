#import <Cocoa/Cocoa.h>
#import <CommonCrypto/CommonDigest.h>
#import <LuaSkin/LuaSkin.h>
#import "../hammerspoon.h"

static int doHash(lua_State *L, CC_LONG length, unsigned char *(*hashFunc)(const void *, CC_LONG, unsigned char *)) {
    unsigned char digest[length + 1];
    size_t sourceLength;
    const char *source = luaL_checklstring(L, 1, &sourceLength);
    NSMutableString *conversionSink = [NSMutableString string];

    hashFunc(source, sourceLength, digest);
    digest[length] = 0;

    for (unsigned int i = 0; i < length; i++) {
        [conversionSink appendFormat:@"%02x", digest[i]];
    }

    //NSLog(@"Hashed '%s' into '%@'", source, conversionSink);

    lua_pushstring(L, [conversionSink UTF8String]);

    return 1;
}

/// hs.hash.sha1(data) -> string
/// Function
/// Calculates an SHA1 hash
///
/// Parameters:
///  * data - A string containing some data to hash
///
/// Returns:
///  * A string containing the SHA1 hash of the supplied data
static int hash_sha1(lua_State *L) {
    return doHash(L, CC_SHA1_DIGEST_LENGTH, CC_SHA1);
}

/// hs.hash.sha256(data) -> string
/// Function
/// Calculates an SHA256 hash
///
/// Parameters:
///  * data - A string containing some data to hash
///
/// Returns:
///  * A string containing the SHA256 hash of the supplied data
static int hash_sha256(lua_State *L) {
    return doHash(L, CC_SHA256_DIGEST_LENGTH, CC_SHA256);
}

/// hs.hash.sha512(data) -> string
/// Function
/// Calculates an SHA512 hash
///
/// Parameters:
///  * data - A string containing some data to hash
///
/// Returns:
///  * A string containing the SHA512 hash of the supplied data
static int hash_sha512(lua_State *L) {
    return doHash(L, CC_SHA512_DIGEST_LENGTH, CC_SHA512);
}

/// hs.hash.md5(data) -> string
/// Function
/// Calculates an MD5 hash
///
/// Parameters:
///  * data - A string containing some data to hash
///
/// Returns:
///  * A string containing the MD5 hash of the supplied data
static int hash_md5(lua_State *L) {
    return doHash(L, CC_MD5_DIGEST_LENGTH, CC_MD5);
}

static const luaL_Reg hashlib[] = {
    {"sha1", hash_sha1},
    {"sha256", hash_sha256},
    {"sha512", hash_sha512},
    {"md5", hash_md5},

    {}
};

/* NOTE: The substring "hs_hash_internal" in the following function's name
         must match the require-path of this file, i.e. "hs.hash.internal". */

int luaopen_hs_hash_internal(lua_State *L __unused) {
    // Table for luaopen
    LuaSkin *skin = [LuaSkin shared];
    [skin registerLibrary:hashlib metaFunctions:nil];

    return 1;
}
