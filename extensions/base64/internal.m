#import <Cocoa/Cocoa.h>
#import <LuaSkin/LuaSkin.h>

// Source: https://gist.github.com/shpakovski/1902994

// NSString *TransformStringWithFunction(NSString *string, SecTransformRef (*function)(CFTypeRef, CFErrorRef *)) {
//     NSData *inputData = [string dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
//     SecTransformRef transformRef = function(kSecBase64Encoding, NULL);
//     SecTransformSetAttribute(transformRef, kSecTransformInputAttributeName, (CFTypeRef)inputData, NULL);
//     CFDataRef outputDataRef = SecTransformExecute(transformRef, NULL);
//     CFRelease(transformRef);
//     return [[[NSString alloc] initWithData:(NSData *)outputDataRef encoding:NSUTF8StringEncoding] autorelease];
// }

NSData *TransformDataWithFunction(NSData *inputData, SecTransformRef (*function)(CFTypeRef, CFErrorRef *)) {
    SecTransformRef transformRef = function(kSecBase64Encoding, NULL);
    SecTransformSetAttribute(transformRef, kSecTransformInputAttributeName, (__bridge_retained CFTypeRef)inputData, NULL);
    CFDataRef outputDataRef = SecTransformExecute(transformRef, NULL);
    CFRelease(transformRef);
    return [[NSData alloc] initWithData:(__bridge_transfer NSData *)outputDataRef];
}

// hs.base64.encode(val) -> str
// Function
// Returns the base64 encoding of the string provided.
static int base64_encode(lua_State* L) {
    [[LuaSkin sharedWithState:L] checkArgs:LS_TNUMBER | LS_TSTRING, LS_TBREAK] ;
    NSUInteger sz ;
    const char* data = luaL_tolstring(L, 1, &sz) ;
    NSData* decodedStr = [[NSData alloc] initWithBytes:data length:sz] ;

    NSData* encodedStr = TransformDataWithFunction(decodedStr, SecEncodeTransformCreate);
    lua_pushlstring(L, [encodedStr bytes], [encodedStr length]) ;
    return 1;
}

//  hs.base64.decode(str) -> val
// Function
// Returns a Lua string representing the given base64 string.
static int base64_decode(lua_State* L) {
    [[LuaSkin sharedWithState:L] checkArgs:LS_TNUMBER | LS_TSTRING, LS_TBREAK] ;
    NSUInteger sz ;
    const char* data = luaL_tolstring(L, 1, &sz) ;
    NSData* encodedStr = [[NSData alloc] initWithBytes:data length:sz] ;

    NSData* decodedStr = TransformDataWithFunction(encodedStr, SecDecodeTransformCreate);
    lua_pushlstring(L, [decodedStr bytes], [decodedStr length]) ;
    return 1;
}

static const luaL_Reg base64_lib[] = {
    {"_encode", base64_encode},
    {"_decode", base64_decode},
    {NULL,      NULL}
};

int luaopen_hs_base64_internal(lua_State* L) {
    LuaSkin *skin = [LuaSkin sharedWithState:L];
    [skin registerLibrary:"hs.base64" functions:base64_lib metaFunctions:nil];

    return 1;
}
