#import "MJConfigManager.h"
#include <CommonCrypto/CommonDigest.h>
void PKLoadModule(NSString* fullname);

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

+ (NSString*) dirForExt:(MJExtension*)ext {
    NSString* nameWithDashes = [ext.name stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    return [[MJConfigManager configPath] stringByAppendingPathComponent:[NSString stringWithFormat:@"ext/%@/", nameWithDashes]];
}

+ (void) installExtension:(MJExtension*)ext {
    NSURL* url = [NSURL URLWithString:ext.tarfile];
    NSURLRequest* req = [NSURLRequest requestWithURL:url];
    NSURLResponse* __autoreleasing response;
    NSError* __autoreleasing error;
    NSData* tgz_data = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&error];
    // yes, we just did a sync call. worst case scenario, the app freezes up for a second or two. we can change it later if it proves to be seriously annoying.
    
    const char* tempFileTemplate = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"ext.XXXXXX.tgz"] fileSystemRepresentation];
    char* tempFileName = malloc(strlen(tempFileTemplate) + 1);
    strcpy(tempFileName, tempFileTemplate);
    int fd = mkstemps(tempFileName, 4);
    if (fd == -1) perror(NULL);
    NSString* tempFilePath = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:tempFileName length:strlen(tempFileName)];
    free(tempFileName);
    NSFileHandle* tempFileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd];
    [tempFileHandle writeData:tgz_data];
    [tempFileHandle closeFile];
    
    // if it doesnt work? well then, we just like, stop i guess...?
    if (![self verifyFile:tempFilePath sha:ext.tarsha]) {
        NSLog(@"sha1 doesn't match; bailing."); // TODO: lol
        return;
    }
    
    NSString* untarDestDir = [self dirForExt:ext];
    [[NSFileManager defaultManager] createDirectoryAtPath:untarDestDir withIntermediateDirectories:YES attributes:nil error:NULL];
    
    NSTask* untar = [[NSTask alloc] init];
    [untar setLaunchPath:@"/usr/bin/tar"];
    [untar setArguments:@[@"-xzf", tempFilePath, @"-C", untarDestDir]];
    [untar launch];
    [untar waitUntilExit];
    
    PKLoadModule(ext.name);
}

+ (void) uninstallExtension:(MJExtension*)ext {
    // TODO: tear down Lua module stuff
    [[NSFileManager defaultManager] removeItemAtPath:[self dirForExt:ext] error:NULL];
}

+ (BOOL) verifyFile:(NSString*)path sha:(NSString*)sha {
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

@end
