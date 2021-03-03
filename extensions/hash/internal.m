#import <Cocoa/Cocoa.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonHMAC.h>
#import <LuaSkin/LuaSkin.h>

static int doHash(lua_State *L, CC_LONG length, unsigned char *(*hashFunc)(const void *, CC_LONG, unsigned char *)) {
    unsigned char digest[length + 1];
    size_t sourceLength;
    const char *source = luaL_checklstring(L, 1, &sourceLength);
    NSMutableString *conversionSink = [NSMutableString string];

    hashFunc(source, (CC_LONG)sourceLength, digest);
    digest[length] = 0;

    for (unsigned int i = 0; i < length; i++) {
        [conversionSink appendFormat:@"%02x", digest[i]];
    }

    //NSLog(@"Hashed '%s' into '%@'", source, conversionSink);

    lua_pushstring(L, [conversionSink UTF8String]);

    return 1;
}

static int doHashHMAC(lua_State *L, CCHmacAlgorithm algorithm, CC_LONG resultLength) {
    unsigned char digest[resultLength + 1];
    size_t keyLength;
    size_t dataLength;
    const char *key = luaL_checklstring(L, 1, &keyLength);
    const char *data = luaL_checklstring(L, 2, &dataLength);
    NSMutableString *conversionSink = [NSMutableString string];

    CCHmac(algorithm, key, keyLength, data, dataLength, digest);
    digest[resultLength] = 0;

    for (unsigned int i = 0; i < resultLength; i++) {
        [conversionSink appendFormat:@"%02x", digest[i]];
    }

    //NSLog(@"HMAC Hashed '%s' with key '%s' into '%@'", data, key, conversionSink);

    lua_pushstring(L, [conversionSink UTF8String]);

    return 1;
}

/// hs.hash.SHA1(data) -> string
/// Function
/// Calculates an SHA1 hash
///
/// Parameters:
///  * data - A string containing some data to hash
///
/// Returns:
///  * A string containing the hash of the supplied data
static int hash_sha1(lua_State *L) {
    return doHash(L, CC_SHA1_DIGEST_LENGTH, CC_SHA1);
}

/// hs.hash.SHA256(data) -> string
/// Function
/// Calculates an SHA256 hash
///
/// Parameters:
///  * data - A string containing some data to hash
///
/// Returns:
///  * A string containing the hash of the supplied data
static int hash_sha256(lua_State *L) {
    return doHash(L, CC_SHA256_DIGEST_LENGTH, CC_SHA256);
}

/// hs.hash.SHA512(data) -> string
/// Function
/// Calculates an SHA512 hash
///
/// Parameters:
///  * data - A string containing some data to hash
///
/// Returns:
///  * A string containing the hash of the supplied data
static int hash_sha512(lua_State *L) {
    return doHash(L, CC_SHA512_DIGEST_LENGTH, CC_SHA512);
}

/// hs.hash.MD5(data) -> string
/// Function
/// Calculates an MD5 hash
///
/// Parameters:
///  * data - A string containing some data to hash
///
/// Returns:
///  * A string containing the hash of the supplied data
static int hash_md5(lua_State *L) {
    return doHash(L, CC_MD5_DIGEST_LENGTH, CC_MD5);
}

/// hs.hash.hmacSHA1(key, data) -> string
/// Function
/// Calculates an HMAC using a key and a SHA1 hash
///
/// Parameters:
///  * key - A string containing a secret key to use
///  * data - A string containing the data to hash
///
/// Returns:
///  * A string containing the hash of the supplied data
static int hash_sha1_hmac(lua_State *L) {
    return doHashHMAC(L, kCCHmacAlgSHA1, CC_SHA1_DIGEST_LENGTH);
}

/// hs.hash.hmacSHA256(key, data) -> string
/// Function
/// Calculates an HMAC using a key and a SHA256 hash
///
/// Parameters:
///  * key - A string containing a secret key to use
///  * data - A string containing the data to hash
///
/// Returns:
///  * A string containing the hash of the supplied data
static int hash_sha256_hmac(lua_State *L) {
    return doHashHMAC(L, kCCHmacAlgSHA256, CC_SHA256_DIGEST_LENGTH);
}

/// hs.hash.hmacSHA512(key, data) -> string
/// Function
/// Calculates an HMAC using a key and a SHA512 hash
///
/// Parameters:
///  * key - A string containing a secret key to use
///  * data - A string containing the data to hash
///
/// Returns:
///  * A string containing the hash of the supplied data
static int hash_sha512_hmac(lua_State *L) {
    return doHashHMAC(L, kCCHmacAlgSHA512, CC_SHA512_DIGEST_LENGTH);
}

/// hs.hash.hmacMD5(key, data) -> string
/// Function
/// Calculates an HMAC using a key and an MD5 hash
///
/// Parameters:
///  * key - A string containing a secret key to use
///  * data - A string containing the data to hash
///
/// Returns:
///  * A string containing the hash of the supplied data
static int hash_md5_hmac(lua_State *L) {
    return doHashHMAC(L, kCCHmacAlgMD5, CC_MD5_DIGEST_LENGTH);
}

static const luaL_Reg hashlib[] = {
    {"SHA1", hash_sha1},
    {"SHA256", hash_sha256},
    {"SHA512", hash_sha512},
    {"MD5", hash_md5},

    {"hmacSHA1", hash_sha1_hmac},
    {"hmacSHA256", hash_sha256_hmac},
    {"hmacSHA512", hash_sha512_hmac},
    {"hmacMD5", hash_md5_hmac},

    {NULL, NULL}
};

/* NOTE: The substring "hs_hash_internal" in the following function's name
         must match the require-path of this file, i.e. "hs.hash.internal". */

int luaopen_hs_hash_internal(lua_State *L) {
    // Table for luaopen
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibrary:"hs.hash" functions:hashlib metaFunctions:nil];

    return 1;
}
