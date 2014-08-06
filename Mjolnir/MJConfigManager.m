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

+ (BOOL) verifyData:(NSData*)tgzdata sha:(NSString*)sha {
    // TODO: check for more errors and don't leak memories
    NSInputStream* inputStream = [NSInputStream inputStreamWithData:tgzdata];
    
    SecTransformRef readTransform = SecTransformCreateReadTransformWithReadStream((__bridge CFReadStreamRef)inputStream);
    SecTransformRef digestTransform = SecDigestTransformCreate(kSecDigestSHA1, CC_SHA1_DIGEST_LENGTH, NULL);
    
    SecGroupTransformRef group = SecTransformCreateGroupTransform();
    SecTransformConnectTransforms(readTransform, kSecTransformOutputAttributeName, digestTransform, kSecTransformInputAttributeName, group, NULL);
    NSData* data = (__bridge_transfer NSData*)SecTransformExecute(group, NULL);
    
    const unsigned char *buf = [data bytes];
    NSMutableString *gotsha = [NSMutableString stringWithCapacity:([data length] * 2)];
    for (int i = 0; i < [data length]; ++i)
        [gotsha appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)buf[i]]];
    
    CFRelease(group);
    
    return [[sha lowercaseString] isEqualToString: [gotsha lowercaseString]];
}

+ (void) reload {
    // TODO
}

@end
