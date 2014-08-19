#import "MJFileUtils.h"

void MJDownloadFile(NSString* url, void(^handler)(NSError* err, NSData* data)) {
    NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               handler(connectionError, data);
                           }];
}

static char* mktemplate(NSString* prefix, NSString* suffix) {
    NSString* relativeTemplate = [NSString stringWithFormat:@"%@XXXXXX%@", prefix, suffix];
    const char* tempFileTemplate = [[NSTemporaryDirectory() stringByAppendingPathComponent:relativeTemplate] fileSystemRepresentation];
    char* tempFileName = malloc(strlen(tempFileTemplate) + 1);
    strcpy(tempFileName, tempFileTemplate);
    return tempFileName;
}

NSString* MJCreateEmptyTempDirectory(NSString* prefix, NSError* __autoreleasing* error) {
    char* tempFileName = mktemplate(prefix, @"");
    NSString* path = nil;
    
    if (mkdtemp(tempFileName))
        path = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:tempFileName length:strlen(tempFileName)];
    else
        *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
    
    free(tempFileName);
    return path;
}

NSString* MJWriteToTempFile(NSData* indata, NSString* prefix, NSString* suffix, NSError* __autoreleasing* error) {
    char* tempFileName = mktemplate(prefix, suffix);
    
    int fd = mkstemps(tempFileName, (int)[suffix length]);
    if (fd == -1) {
        *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        return nil;
    }
    NSString* tempFilePath = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:tempFileName length:strlen(tempFileName)];
    free(tempFileName);
    
    NSFileHandle* tempFileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fd];
    [tempFileHandle writeData:indata];
    [tempFileHandle closeFile];
    
    return tempFilePath;
}

BOOL MJUntar(NSData* tardata, NSString* intoDirectory, NSError*__autoreleasing* error) {
    BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:intoDirectory withIntermediateDirectories:YES attributes:nil error:error];
    if (!success) return NO;
    
    NSPipe* pipe = [NSPipe pipe];
    NSTask* untar = [[NSTask alloc] init];
    [untar setLaunchPath:@"/usr/bin/tar"];
    [untar setArguments:@[@"-xzf-", @"-C", intoDirectory]];
    [untar setStandardInput:pipe];
    [untar launch];
    [[pipe fileHandleForWriting] writeData:tardata];
    [[pipe fileHandleForWriting] closeFile];
    [untar waitUntilExit];
    if ([untar terminationStatus]) {
        *error = [NSError errorWithDomain:@"tar" code:[untar terminationStatus] userInfo:@{NSLocalizedDescriptionKey: @"could not extract the tgz archive"}];
        return NO;
    }
    
    return YES;
}
