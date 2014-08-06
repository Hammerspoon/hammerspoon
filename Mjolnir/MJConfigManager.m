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

+ (NSString*) saveDataToTempFile:(NSData*)tgz_data error:(NSError*__autoreleasing*)error {
    const char* tempFileTemplate = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"ext.XXXXXX.tgz"] fileSystemRepresentation];
    char* tempFileName = malloc(strlen(tempFileTemplate) + 1);
    strcpy(tempFileName, tempFileTemplate);
    int fd = mkstemps(tempFileName, 4);
    if (fd == -1) {
        *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        return nil;
    }
    NSString* tempFilePath = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:tempFileName length:strlen(tempFileName)];
    free(tempFileName);
    NSFileHandle* tempFileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd];
    [tempFileHandle writeData:tgz_data];
    [tempFileHandle closeFile];
    return tempFilePath;
}

+ (void) untarFile:(NSString*)tarfile intoDirectory:(NSString*)dir {
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    NSTask* untar = [[NSTask alloc] init];
    [untar setLaunchPath:@"/usr/bin/tar"];
    [untar setArguments:@[@"-xzf", tarfile, @"-C", dir]];
    [untar launch];
    [untar waitUntilExit];
}

+ (BOOL) verifyFile:(NSString*)path sha:(NSString*)sha {
    // TODO: check for more errors
    SecGroupTransformRef group = SecTransformCreateGroupTransform();
    NSInputStream* inputStream = [NSInputStream inputStreamWithFileAtPath:path];
    SecTransformRef readTransform = SecTransformCreateReadTransformWithReadStream((__bridge CFReadStreamRef)inputStream);
    SecTransformRef digestTransform = SecDigestTransformCreate(kSecDigestSHA1, CC_SHA1_DIGEST_LENGTH, NULL);
    SecTransformConnectTransforms(readTransform, kSecTransformOutputAttributeName, digestTransform, kSecTransformInputAttributeName, group, NULL);
    NSData* data = (__bridge_transfer NSData*)SecTransformExecute(group, NULL);
    
    const unsigned char *buf = (const unsigned char *)[data bytes];
    NSMutableString *gotsha = [NSMutableString stringWithCapacity:([data length] * 2)];
    for (int i = 0; i < [data length]; ++i)
        [gotsha appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)buf[i]]];
    
    return [[sha lowercaseString] isEqualToString: [gotsha lowercaseString]];
}

+ (void) reload {
    // TODO
}

@end
