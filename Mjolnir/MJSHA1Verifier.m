#import "MJSHA1Verifier.h"
#import <CommonCrypto/CommonDigest.h>

static NSString* MJPublicKey = @""
"-----BEGIN PUBLIC KEY-----\n"
"MIIBtzCCASsGByqGSM44BAEwggEeAoGBAKI1LKQiFEWu6woOAzKPeVrvMoUFLv43\n"
"I2PYizYCAUkzdh8Rgos0qSwg6+qaStVB3SYHxXlwtyiuJwm9CZtiPJzXUFDESvha\n"
"hJckBRxL93zrUIW1gCIeXrvX89ZNzn9pgj6c72z+rkfV/SFYYXWNm375t6gZwoTy\n"
"rlZVNnUewetvAhUAhUtGFpd0rJmqhaMEuPRDDUQGlhkCgYBEm3G1/p058vDw8rKW\n"
"u0UKHN6syEATqditlyqcH0F28pxwVTXIt44o9nrygDdSgcZne2GQC6PJU1tSDliH\n"
"77nJGCvfJ6Uyj69ieAY3q7Enshk5M3rBub+Nq5Ec0YtpuDVUB6ytXnwpld/bbOQ3\n"
"WlMqy6lTidH72azA1+UVcSOLXQOBhQACgYEAmV6CvXE5N1gScnbD+5E4VM4JFyF8\n"
"xjA+0xzpoW2ctFKvgQxMswlmvvZvU7oTm/KHrJkK8arlWi3kV2qfNk1Ry7GKE9fW\n"
"jebNdfI+fWntQjd1bCIlACFGrH5ioucI0Hdzxarx/7Ie10UPveSRf8ifO9JU1bSH\n"
"cohzwU5/305uivg=\n"
"-----END PUBLIC KEY-----\n";


NSString* MJDataToHexString(NSData* shadata) {
    const unsigned char* shabuf = [shadata bytes];
    NSMutableString *newsha = [NSMutableString stringWithCapacity:([shadata length] * 2)];
    for (int i = 0; i < [shadata length]; ++i)
        [newsha appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)shabuf[i]]];
    return newsha;
}

@implementation MJSHA1Verifier

+ (BOOL) verifyTgzData:(NSData*)tgzdata sha:(NSString*)sha error:(NSError*__autoreleasing*)error {
    NSInputStream* inputStream = [NSInputStream inputStreamWithData:tgzdata];
    
    SecGroupTransformRef group = SecTransformCreateGroupTransform();
    SecTransformRef readTransform = SecTransformCreateReadTransformWithReadStream((__bridge CFReadStreamRef)inputStream);
    SecTransformRef digestTransform;
    CFErrorRef cferror = NULL;
    BOOL verified = NO;
    NSData* gotsha;
    
    digestTransform = SecDigestTransformCreate(kSecDigestSHA1, CC_SHA1_DIGEST_LENGTH, &cferror);
    if (!digestTransform) goto cleanup;
    
    cferror = NULL; // overkill? can't tell; docs are ambiguous
    SecTransformConnectTransforms(readTransform, kSecTransformOutputAttributeName, digestTransform, kSecTransformInputAttributeName, group, &cferror);
    if (cferror) goto cleanup;
    
    cferror = NULL; // overkill? can't tell; docs are ambiguous
    gotsha = (__bridge_transfer NSData*)SecTransformExecute(group, &cferror);
    if (cferror) goto cleanup;
    
    verified = [[sha lowercaseString] isEqualToString: [MJDataToHexString(gotsha) lowercaseString]];
    
cleanup:
    
    CFRelease(group);
    CFRelease(readTransform);
    if (digestTransform) CFRelease(digestTransform);
    if (cferror) *error = (__bridge_transfer NSError*)cferror;
    
    return verified;
}

@end


static SecKeyRef MJCreatePublicKey(void) {
    CFArrayRef items = NULL;
    SecKeyRef security_key = NULL;
    
    NSData* pubkeyData = [MJPublicKey dataUsingEncoding:NSUTF8StringEncoding];
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

static NSData* MJDataFromBase64String(NSData* indata, CFErrorRef* error) {
    CFDataRef result = NULL;
    
    SecTransformRef decoder = SecDecodeTransformCreate(kSecBase64Encoding, error);
    if (!decoder) goto cleanup;
    
    SecTransformSetAttribute(decoder, kSecTransformInputAttributeName, (__bridge CFTypeRef)indata, error);
    if (*error) goto cleanup;
    
    result = SecTransformExecute(decoder, error);
    
cleanup:
    
    if (decoder) CFRelease(decoder);
    return (__bridge_transfer NSData*)result;
}

BOOL MJVerifySignedData(NSData* sig, NSData* data) {
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
    
    security_key = MJCreatePublicKey();
    if (security_key == NULL) { printf("security key was null\n"); goto cleanup; }
    
    signature = MJDataFromBase64String(sig, &error);
    if (signature == nil) { printf("signature was null\n"); goto cleanup; }
    
    input_stream = [NSInputStream inputStreamWithData:data];
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
    printf("finished executing verification transforms for data...\n");
    
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
