@import Cocoa ;
@import CommonCrypto.CommonDigest ;
@import CommonCrypto.CommonHMAC ;
@import zlib ;

#include "algorithms.h"

#pragma mark - CRC32

void *init_CRC32(__unused NSData *_key) {
    uLong *_context = malloc(sizeof(uLong)) ;
    uLong crc = crc32_z(0L, Z_NULL, 0) ;
    memcpy(_context, &crc, sizeof(uLong)) ;
    return _context ;
}

void append_CRC32(void *_context, NSData *data) {
    uLong crc ;
    memcpy(&crc, _context, sizeof(uLong)) ;
    crc =  crc32_z(crc, data.bytes, data.length) ;
    memcpy(_context, &crc, sizeof(uLong)) ;
}

NSData *finish_CRC32(void *_context) {
    uLong crc ;
    memcpy(&crc, _context, sizeof(uLong)) ;

    unsigned char asBytes[4] = { 0 };
    asBytes[0] = (crc >> 24) & 0xff ;
    asBytes[1] = (crc >> 16) & 0xff ;
    asBytes[2] = (crc >>  8) & 0xff ;
    asBytes[3] = crc         & 0xff ;

    free(_context) ;
    _context = NULL ;
    return [NSData dataWithBytes:asBytes length:4] ;
}

#pragma mark - MD2

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

void *init_MD2(__unused NSData *_key) {
    CC_MD2_CTX *_context = malloc(sizeof(CC_MD2_CTX)) ;
    CC_MD2_Init(_context) ;
    return _context ;
}

void append_MD2(void *_context, NSData *data) {
    CC_MD2_Update((CC_MD2_CTX *)_context, data.bytes, (CC_LONG)data.length) ;
}

NSData *finish_MD2(void *_context) {
    unsigned char *md = malloc(CC_MD2_DIGEST_LENGTH) ;
    CC_MD2_Final(md, (CC_MD2_CTX *)_context) ;
    free(_context) ;
    _context = NULL ;
    return [NSData dataWithBytesNoCopy:md length:CC_MD2_DIGEST_LENGTH] ;
}

#pragma mark - MD4

void *init_MD4(__unused NSData *_key) {
    CC_MD4_CTX *_context = malloc(sizeof(CC_MD4_CTX)) ;
    CC_MD4_Init(_context) ;
    return _context ;
}

void append_MD4(void *_context, NSData *data) {
    CC_MD4_Update((CC_MD4_CTX *)_context, data.bytes, (CC_LONG)data.length) ;
}

NSData *finish_MD4(void *_context) {
    unsigned char *md = malloc(CC_MD4_DIGEST_LENGTH) ;
    CC_MD4_Final(md, (CC_MD4_CTX *)_context) ;
    free(_context) ;
    _context = NULL ;
    return [NSData dataWithBytesNoCopy:md length:CC_MD4_DIGEST_LENGTH] ;
}

#pragma mark - MD5

void *init_MD5(__unused NSData *_key) {
    CC_MD5_CTX *_context = malloc(sizeof(CC_MD5_CTX)) ;
    CC_MD5_Init(_context) ;
    return _context ;
}

void append_MD5(void *_context, NSData *data) {
    CC_MD5_Update((CC_MD5_CTX *)_context, data.bytes, (CC_LONG)data.length) ;
}

NSData *finish_MD5(void *_context) {
    unsigned char *md = malloc(CC_MD5_DIGEST_LENGTH) ;
    CC_MD5_Final(md, (CC_MD5_CTX *)_context) ;
    free(_context) ;
    _context = NULL ;
    return [NSData dataWithBytesNoCopy:md length:CC_MD5_DIGEST_LENGTH] ;
}

#pragma clang diagnostic pop

#pragma mark - SHA1

void *init_SHA1(__unused NSData *_key) {
    CC_SHA1_CTX *_context = malloc(sizeof(CC_SHA1_CTX)) ;
    CC_SHA1_Init(_context) ;
    return _context ;
}

void append_SHA1(void *_context, NSData *data) {
    CC_SHA1_Update((CC_SHA1_CTX *)_context, data.bytes, (CC_LONG)data.length) ;
}

NSData *finish_SHA1(void *_context) {
    unsigned char *md = malloc(CC_SHA1_DIGEST_LENGTH) ;
    CC_SHA1_Final(md, (CC_SHA1_CTX *)_context) ;
    free(_context) ;
    _context = NULL ;
    return [NSData dataWithBytesNoCopy:md length:CC_SHA1_DIGEST_LENGTH] ;
}

#pragma mark - SHA224

void *init_SHA224(__unused NSData *_key) {
    CC_SHA256_CTX *_context = malloc(sizeof(CC_SHA256_CTX)) ;
    CC_SHA224_Init(_context) ;
    return _context ;
}

void append_SHA224(void *_context, NSData *data) {
    CC_SHA224_Update((CC_SHA256_CTX *)_context, data.bytes, (CC_LONG)data.length) ;
}

NSData *finish_SHA224(void *_context) {
    unsigned char *md = malloc(CC_SHA224_DIGEST_LENGTH) ;
    CC_SHA224_Final(md, (CC_SHA256_CTX *)_context) ;
    free(_context) ;
    _context = NULL ;
    return [NSData dataWithBytesNoCopy:md length:CC_SHA224_DIGEST_LENGTH] ;
}

#pragma mark - SHA256

void *init_SHA256(__unused NSData *_key) {
    CC_SHA256_CTX *_context = malloc(sizeof(CC_SHA256_CTX)) ;
    CC_SHA256_Init(_context) ;
    return _context ;
}

void append_SHA256(void *_context, NSData *data) {
    CC_SHA256_Update((CC_SHA256_CTX *)_context, data.bytes, (CC_LONG)data.length) ;
}

NSData *finish_SHA256(void *_context) {
    unsigned char *md = malloc(CC_SHA256_DIGEST_LENGTH) ;
    CC_SHA256_Final(md, (CC_SHA256_CTX *)_context) ;
    free(_context) ;
    _context = NULL ;
    return [NSData dataWithBytesNoCopy:md length:CC_SHA256_DIGEST_LENGTH] ;
}

#pragma mark - SHA384

void *init_SHA384(__unused NSData *_key) {
    CC_SHA512_CTX *_context = malloc(sizeof(CC_SHA512_CTX)) ;
    CC_SHA384_Init(_context) ;
    return _context ;
}

void append_SHA384(void *_context, NSData *data) {
    CC_SHA384_Update((CC_SHA512_CTX *)_context, data.bytes, (CC_LONG)data.length) ;
}

NSData *finish_SHA384(void *_context) {
    unsigned char *md = malloc(CC_SHA384_DIGEST_LENGTH) ;
    CC_SHA384_Final(md, (CC_SHA512_CTX *)_context) ;
    free(_context) ;
    _context = NULL ;
    return [NSData dataWithBytesNoCopy:md length:CC_SHA384_DIGEST_LENGTH] ;
}

#pragma mark - SHA512

void *init_SHA512(__unused NSData *_key) {
    CC_SHA512_CTX *_context = malloc(sizeof(CC_SHA512_CTX)) ;
    CC_SHA512_Init(_context) ;
    return _context ;
}

void append_SHA512(void *_context, NSData *data) {
    CC_SHA512_Update((CC_SHA512_CTX *)_context, data.bytes, (CC_LONG)data.length) ;
}

NSData *finish_SHA512(void *_context) {
    unsigned char *md = malloc(CC_SHA512_DIGEST_LENGTH) ;
    CC_SHA512_Final(md, (CC_SHA512_CTX *)_context) ;
    free(_context) ;
    _context = NULL ;
    return [NSData dataWithBytesNoCopy:md length:CC_SHA512_DIGEST_LENGTH] ;
}

#pragma mark - hmacMD5

void *init_hmacMD5(NSData *_key) {
    CCHmacContext *_context = malloc(sizeof(CCHmacContext)) ;
    CCHmacInit(_context, kCCHmacAlgMD5, _key.bytes, _key.length) ;
    return _context ;
}

NSData *finish_hmacMD5(void *_context) {
    unsigned char *md = malloc(CC_MD5_DIGEST_LENGTH) ;
    CCHmacFinal((CCHmacContext *)_context, md) ;
    free(_context) ;
    _context = NULL ;
    return [NSData dataWithBytesNoCopy:md length:CC_MD5_DIGEST_LENGTH] ;
}

#pragma mark - hmacSHA1

void *init_hmacSHA1(NSData *_key) {
    CCHmacContext *_context = malloc(sizeof(CCHmacContext)) ;
    CCHmacInit(_context, kCCHmacAlgSHA1, _key.bytes, _key.length) ;
    return _context ;
}

NSData *finish_hmacSHA1(void *_context) {
    unsigned char *md = malloc(CC_SHA1_DIGEST_LENGTH) ;
    CCHmacFinal((CCHmacContext *)_context, md) ;
    free(_context) ;
    _context = NULL ;
    return [NSData dataWithBytesNoCopy:md length:CC_SHA1_DIGEST_LENGTH] ;
}

#pragma mark - hmacSHA224

void *init_hmacSHA224(NSData *_key) {
    CCHmacContext *_context = malloc(sizeof(CCHmacContext)) ;
    CCHmacInit(_context, kCCHmacAlgSHA224, _key.bytes, _key.length) ;
    return _context ;
}

NSData *finish_hmacSHA224(void *_context) {
    unsigned char *md = malloc(CC_SHA224_DIGEST_LENGTH) ;
    CCHmacFinal((CCHmacContext *)_context, md) ;
    free(_context) ;
    _context = NULL ;
    return [NSData dataWithBytesNoCopy:md length:CC_SHA224_DIGEST_LENGTH] ;
}

#pragma mark - hmacSHA256

void *init_hmacSHA256(NSData *_key) {
    CCHmacContext *_context = malloc(sizeof(CCHmacContext)) ;
    CCHmacInit(_context, kCCHmacAlgSHA256, _key.bytes, _key.length) ;
    return _context ;
}

NSData *finish_hmacSHA256(void *_context) {
    unsigned char *md = malloc(CC_SHA256_DIGEST_LENGTH) ;
    CCHmacFinal((CCHmacContext *)_context, md) ;
    free(_context) ;
    _context = NULL ;
    return [NSData dataWithBytesNoCopy:md length:CC_SHA256_DIGEST_LENGTH] ;
}

#pragma mark - hmacSHA384

void *init_hmacSHA384(NSData *_key) {
    CCHmacContext *_context = malloc(sizeof(CCHmacContext)) ;
    CCHmacInit(_context, kCCHmacAlgSHA384, _key.bytes, _key.length) ;
    return _context ;
}

NSData *finish_hmacSHA384(void *_context) {
    unsigned char *md = malloc(CC_SHA384_DIGEST_LENGTH) ;
    CCHmacFinal((CCHmacContext *)_context, md) ;
    free(_context) ;
    _context = NULL ;
    return [NSData dataWithBytesNoCopy:md length:CC_SHA384_DIGEST_LENGTH] ;
}

#pragma mark - hmacSHA512

void *init_hmacSHA512(NSData *_key) {
    CCHmacContext *_context = malloc(sizeof(CCHmacContext)) ;
    CCHmacInit(_context, kCCHmacAlgSHA512, _key.bytes, _key.length) ;
    return _context ;
}

NSData *finish_hmacSHA512(void *_context) {
    unsigned char *md = malloc(CC_SHA512_DIGEST_LENGTH) ;
    CCHmacFinal((CCHmacContext *)_context, md) ;
    free(_context) ;
    _context = NULL ;
    return [NSData dataWithBytesNoCopy:md length:CC_SHA512_DIGEST_LENGTH] ;
}

#pragma mark - hmac common

void append_hmac(void *_context, NSData *data) {
    CCHmacUpdate((CCHmacContext *)_context, data.bytes, data.length) ;
}

