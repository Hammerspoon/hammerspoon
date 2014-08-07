#import "MJSHA1Verifier.h"
#include <CommonCrypto/CommonDigest.h>

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
