#import "MJConfigManager.h"
#include <CommonCrypto/CommonDigest.h>

@implementation MJConfigManager

+ (NSString*) configPath {
    return [@"~/.mjolnir/" stringByStandardizingPath];
}

+ (void) setupConfigDir {
    [[NSFileManager defaultManager] createDirectoryAtPath:[MJConfigManager configPath]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
}

+ (NSString*) dirForExtensionName:(NSString*)extname {
    NSString* nameWithDashes = [extname stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    return [[MJConfigManager configPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"ext/%@/", nameWithDashes]];
}

+ (void) downloadExtension:(NSString*)url handler:(void(^)(NSError* err, NSData* data))handler {
    NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               handler(connectionError, data);
                           }];
}

+ (BOOL) untarData:(NSData*)tardata intoDirectory:(NSString*)dir error:(NSError*__autoreleasing*)error {
    BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:error];
    if (!success) return NO;
    
    NSPipe* pipe = [NSPipe pipe];
    NSTask* untar = [[NSTask alloc] init];
    [untar setLaunchPath:@"/usr/bin/tar"];
    [untar setArguments:@[@"-xzf-", @"-C", dir]];
    [untar setStandardInput:pipe];
    [untar launch];
    [[pipe fileHandleForWriting] writeData:tardata];
    [[pipe fileHandleForWriting] closeFile];
    [untar waitUntilExit];
    if ([untar terminationStatus]) {
        *error = [NSError errorWithDomain:@"tar" code:[untar terminationStatus] userInfo:@{NSLocalizedDescriptionKey: @"could not extract the extension archive"}];
        return NO;
    }
    
    return YES;
}

NSString* MJDataToHexString(NSData* shadata) {
    const unsigned char* shabuf = [shadata bytes];
    NSMutableString *newsha = [NSMutableString stringWithCapacity:([shadata length] * 2)];
    for (int i = 0; i < [shadata length]; ++i)
        [newsha appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)shabuf[i]]];
    return newsha;
}

+ (BOOL) verifyData:(NSData*)tgzdata sha:(NSString*)sha error:(NSError*__autoreleasing*)error {
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

+ (void) reload {
    // TODO
}

@end
