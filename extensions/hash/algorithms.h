#pragma once

@import Cocoa ;

typedef void *(*hashInit_t)(NSData *);
typedef void (*hashAppend_t)(void *, NSData *);
typedef NSData *(*hashFinish_t)(void *);

typedef struct hashEntry_s {
    const char   *hashName ;
    hashInit_t   initFn ;
    hashAppend_t appendFn ;
    hashFinish_t finishFn ;
} hashEntry_t ;

extern void *init_CRC32(NSData *key) ;
extern void append_CRC32(void *_context, NSData *data) ;
extern NSData *finish_CRC32(void *_context) ;

extern void *init_MD2(NSData *key) ;
extern void append_MD2(void *_context, NSData *data) ;
extern NSData *finish_MD2(void *_context) ;

extern void *init_MD4(NSData *key) ;
extern void append_MD4(void *_context, NSData *data) ;
extern NSData *finish_MD4(void *_context) ;

extern void *init_MD5(NSData *key) ;
extern void append_MD5(void *_context, NSData *data) ;
extern NSData *finish_MD5(void *_context) ;

extern void *init_SHA1(NSData *key) ;
extern void append_SHA1(void *_context, NSData *data) ;
extern NSData *finish_SHA1(void *_context) ;

extern void *init_SHA224(NSData *key) ;
extern void append_SHA224(void *_context, NSData *data) ;
extern NSData *finish_SHA224(void *_context) ;

extern void *init_SHA256(NSData *key) ;
extern void append_SHA256(void *_context, NSData *data) ;
extern NSData *finish_SHA256(void *_context) ;

extern void *init_SHA384(NSData *key) ;
extern void append_SHA384(void *_context, NSData *data) ;
extern NSData *finish_SHA384(void *_context) ;

extern void *init_SHA512(NSData *key) ;
extern void append_SHA512(void *_context, NSData *data) ;
extern NSData *finish_SHA512(void *_context) ;

extern void *init_hmacMD5(NSData *key) ;
extern NSData *finish_hmacMD5(void *_context) ;

extern void *init_hmacSHA1(NSData *key) ;
extern NSData *finish_hmacSHA1(void *_context) ;

extern void *init_hmacSHA224(NSData *key) ;
extern NSData *finish_hmacSHA224(void *_context) ;

extern void *init_hmacSHA256(NSData *key) ;
extern NSData *finish_hmacSHA256(void *_context) ;

extern void *init_hmacSHA384(NSData *key) ;
extern NSData *finish_hmacSHA384(void *_context) ;

extern void *init_hmacSHA512(NSData *key) ;
extern NSData *finish_hmacSHA512(void *_context) ;

extern void append_hmac(void *_context, NSData *data) ;

