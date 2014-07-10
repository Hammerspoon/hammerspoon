#import "helpers.h"
#include <CommonCrypto/CommonDigest.h>

/// updates
///
/// Check for and install Hydra updates.



static SecKeyRef create_public_key(void) {
    NSString* pubkeypath = [[NSBundle mainBundle] pathForResource:@"dsa_pub" ofType:@"cer"];
    
    CFArrayRef items = NULL;
    SecKeyRef security_key = NULL;
    
    NSString* pubkey = [NSString stringWithContentsOfFile:pubkeypath encoding:NSUTF8StringEncoding error:NULL];
    NSData* pubkeyData = [pubkey dataUsingEncoding:NSUTF8StringEncoding];
    if ([pubkeyData length] == 0) goto cleanup;
    
    SecExternalFormat format = kSecFormatOpenSSL;
    SecExternalItemType itemType = kSecItemTypePublicKey;
    SecItemImportExportKeyParameters parameters = {};
    
    OSStatus status = SecItemImport((__bridge CFDataRef)pubkeyData, NULL, &format, &itemType, 0, &parameters, NULL, &items);
    
    if (status != noErr) { printf("invalid status: %d\n", status); goto cleanup; }
    if (items == NULL) { printf("items were unexpectedly null\n"); goto cleanup; }
    if (format != kSecFormatOpenSSL) { printf("format isn't kSecFormatOpenSSL: %d\n", format); goto cleanup; }
    if (itemType != kSecItemTypePublicKey) { printf("item type isn't kSecItemTypePublicKey: %d\n", itemType); goto cleanup; }
    if (CFArrayGetCount(items) != 1) { printf("items count isn't 1, it's: %ld\n", CFArrayGetCount(items)); goto cleanup; }
    
    security_key = (SecKeyRef)CFRetain(CFArrayGetValueAtIndex(items, 0));
    
cleanup:
    if (items) CFRelease(items);
    return security_key;
}

static BOOL updater_verify_file(NSString* sig, NSString* zipfilepath) {
    BOOL verified = NO;
    
    SecKeyRef security_key = NULL;
    
    NSData *signature = nil;
    NSInputStream *input_stream = nil;
    
    SecGroupTransformRef group = SecTransformCreateGroupTransform();
    SecTransformRef read_transform = NULL;
    SecTransformRef digest_transform = NULL;
    SecTransformRef verify_transform = NULL;
    CFErrorRef error = NULL;
    CFBooleanRef success = NULL;
    
    security_key = create_public_key();
    if (security_key == NULL) { printf("security key was null\n"); goto cleanup; }
    
    signature = [[NSData alloc] initWithBase64EncodedString:[sig stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (signature == nil) { printf("signature was null\n"); goto cleanup; }
    
    input_stream = [NSInputStream inputStreamWithFileAtPath:zipfilepath];
    if (input_stream == nil) { printf("input stream was null\n"); goto cleanup; }
    
    read_transform = SecTransformCreateReadTransformWithReadStream((__bridge CFReadStreamRef)input_stream);
    if (read_transform == NULL) { printf("read transform was null\n"); goto cleanup; }
    
    digest_transform = SecDigestTransformCreate(kSecDigestSHA1, CC_SHA1_DIGEST_LENGTH, NULL);
    if (digest_transform == NULL) { printf("digest transform was null\n"); goto cleanup; }
    
    verify_transform = SecVerifyTransformCreate(security_key, (__bridge CFDataRef)signature, NULL);
    if (verify_transform == NULL) { printf("verify transform was null\n"); goto cleanup; }
    
    SecTransformConnectTransforms(read_transform, kSecTransformOutputAttributeName, digest_transform, kSecTransformInputAttributeName, group, &error);
    if (error) { printf("read transform failed to connect to digest transform:\n"); CFShow(error); goto cleanup; }
    
    SecTransformConnectTransforms(digest_transform, kSecTransformOutputAttributeName, verify_transform, kSecTransformInputAttributeName, group, &error);
    if (error) { printf("digest transform failed to connect to verify transform:\n"); CFShow(error); goto cleanup; }
    
    success = SecTransformExecute(group, &error);
    if (error) { printf("executing transform failed: %ld\n", CFErrorGetCode(error)); CFShow(error); goto cleanup; }
    
    verified = CFBooleanGetValue(success);
    
cleanup:
    
    if (group) CFRelease(group);
    if (security_key) CFRelease(security_key);
    if (read_transform) CFRelease(read_transform);
    if (digest_transform) CFRelease(digest_transform);
    if (verify_transform) CFRelease(verify_transform);
    if (success) CFRelease(success);
    if (error) CFRelease(error);
    
    return verified;
}



static NSString* updates_url = @"https://api.github.com/repos/sdegutis/hydra/releases";

/// updates.getversions(fn(versions))
/// Low-level function to get list of available Hydra versions; used by updates.check; you probably want to use updates.check instead of using this directly.
static int updates_getversions(lua_State* L) {
    luaL_checktype(L, 1, LUA_TFUNCTION);
    int fnref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    NSURL* url = [NSURL URLWithString:updates_url];
    NSURLRequest* req = [[NSURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:5];
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError)
     {
         lua_rawgeti(L, LUA_REGISTRYINDEX, fnref);
         luaL_unref(L, LUA_REGISTRYINDEX, fnref);
         
         if ([(NSHTTPURLResponse*)response statusCode] != 200) {
             printf("checked for update but github's api seems broken\n");
             lua_pop(L, 1);
             return;
         }
         
         NSArray* releases = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
         
         lua_newtable(L);
         int i = 0;
         
         for (NSDictionary* release in releases) {
             lua_newtable(L);
             
             NSArray* assets = [release objectForKey:@"assets"];
             NSDictionary* asset = [assets objectAtIndex:0];
             
             lua_pushnumber(L, [[release objectForKey:@"id"] doubleValue]);
             lua_setfield(L, -2, "id");
             
             lua_pushstring(L, [[release objectForKey:@"tag_name"] UTF8String]);
             lua_setfield(L, -2, "version");
             
             lua_pushstring(L, [[release objectForKey:@"name"] UTF8String]);
             lua_setfield(L, -2, "name");
             
             lua_pushstring(L, [[release objectForKey:@"body"] UTF8String]);
             lua_setfield(L, -2, "changelog");
             
             lua_pushstring(L, [[release objectForKey:@"published_at"] UTF8String]);
             lua_setfield(L, -2, "date");
             
             lua_pushboolean(L, [[release objectForKey:@"prerelease"] boolValue]);
             lua_setfield(L, -2, "beta");
             
             lua_pushstring(L, [[release objectForKey:@"html_url"] UTF8String]);
             lua_setfield(L, -2, "html_url");
             
             lua_pushstring(L, [[asset objectForKey:@"browser_download_url"] UTF8String]);
             lua_setfield(L, -2, "download_url");
             
             lua_pushnumber(L, [[asset objectForKey:@"download_count"] doubleValue]);
             lua_setfield(L, -2, "download_count");
             
             lua_pushnumber(L, [[asset objectForKey:@"size"] doubleValue]);
             lua_setfield(L, -2, "download_size");
             
             lua_rawseti(L, -2, ++i);
         }
         
         if (lua_pcall(L, 1, 0, 0))
             hydra_handle_error(L);
     }];
    
    return 0;
}


/// updates.currentversion() -> string
/// Low-level function to get current Hydra version; used by updates.check; you probably want to use updates.check instead of using this directly.
static int updates_currentversion(lua_State* L) {
    lua_pushstring(L, [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] UTF8String]);
    return 1;
}


static const luaL_Reg updateslib[] = {
    {"getversions", updates_getversions},
    {"currentversion", updates_currentversion},
    {NULL, NULL}
};

int luaopen_updates(lua_State* L) {
    luaL_newlib(L, updateslib);
    return 1;
}
