#import "MJArchiveManager.h"

@implementation MJArchiveManager

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

@end
