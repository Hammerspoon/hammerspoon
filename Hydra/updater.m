#import "hydra.h"
#include <CommonCrypto/CommonDigest.h>

static SecKeyRef transform_public_key(NSString* pubkeypath) {
	CFArrayRef items = NULL;
    SecKeyRef security_key = NULL;
    
    NSString* pubkey = [NSString stringWithContentsOfFile:pubkeypath encoding:NSUTF8StringEncoding error:NULL];
    NSData* pubkeyData = [pubkey dataUsingEncoding:NSUTF8StringEncoding];
    if ([pubkeyData length] == 0) goto cleanup;
    
	SecExternalFormat format = kSecFormatOpenSSL;
	SecExternalItemType itemType = kSecItemTypePublicKey;
	SecItemImportExportKeyParameters parameters = {};
    
	OSStatus status = SecItemImport((__bridge CFDataRef)pubkeyData, NULL, &format, &itemType, 0, &parameters, NULL, &items);
    if (status != noErr || items == NULL ||
        format != kSecFormatOpenSSL || itemType != kSecItemTypePublicKey ||
        CFArrayGetCount(items) != 1)
        goto cleanup;
    
    security_key = (SecKeyRef)CFRetain(CFArrayGetValueAtIndex(items, 0));
    
cleanup:
    if (items) CFRelease(items);
    return security_key;
}


static BOOL dostuff(NSString* sig, NSString* pubkeypath, NSString* zipfilepath) {
    BOOL verified = NO;
    
    SecKeyRef security_key = NULL;
    
    NSData *signature = nil;
    NSInputStream *input_stream = nil;
    
	SecGroupTransformRef group = SecTransformCreateGroupTransform();
	SecTransformRef read_transform = NULL;
	SecTransformRef digest_transform = NULL;
	SecTransformRef verify_transform = NULL;
	CFErrorRef error = NULL;
    
    security_key = transform_public_key(pubkeypath);
    if (security_key == NULL) goto cleanup;
    
	signature = [[NSData alloc] initWithBase64EncodedString:[sig stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (signature == nil) goto cleanup;
    
	input_stream = [NSInputStream inputStreamWithFileAtPath:zipfilepath];
    if (input_stream == nil) goto cleanup;
    
	read_transform = SecTransformCreateReadTransformWithReadStream((__bridge CFReadStreamRef)input_stream);
	if (read_transform == NULL) goto cleanup;
    
	digest_transform = SecDigestTransformCreate(kSecDigestSHA1, CC_SHA1_DIGEST_LENGTH, NULL);
	if (digest_transform == NULL) goto cleanup;
    
	verify_transform = SecVerifyTransformCreate(security_key, (__bridge CFDataRef)signature, NULL);
	if (verify_transform == NULL) goto cleanup;
    
	SecTransformConnectTransforms(read_transform, kSecTransformOutputAttributeName, digest_transform, kSecTransformInputAttributeName, group, &error);
	if (error) goto cleanup;
    
	SecTransformConnectTransforms(digest_transform, kSecTransformOutputAttributeName, verify_transform, kSecTransformInputAttributeName, group, &error);
	if (error) goto cleanup;
    
	verified = [CFBridgingRelease(SecTransformExecute(group, NULL)) boolValue];
    
cleanup:
    
    if (group) CFRelease(group);
    if (security_key) CFRelease(security_key);
    if (read_transform) CFRelease(read_transform);
    if (digest_transform) CFRelease(digest_transform);
    if (verify_transform) CFRelease(verify_transform);
    if (error) CFRelease(error);
    
    return verified;
}

int luaopen_updates(lua_State* L) {
//    BOOL result =
//    dostuff(@"MC0CFQCR5YCyNWgn3LrL0ZYbAdt3dkxfqQIUUk9fCV6Vr5KVDUuDUtQNwmdT7S0=",
//            @"/Users/sdegutis/Downloads/dsa_pub.cer",
//            @"/Users/sdegutis/Downloads/Zephyros-LATEST.app.tar.gz");
//    NSLog(@"%d", result);
    
    lua_newtable(L);
    return 1;
}
