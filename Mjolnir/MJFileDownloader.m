#import "MJFileDownloader.h"

@implementation MJFileDownloader

+ (void) downloadFile:(NSString*)url handler:(void(^)(NSError* err, NSData* data))handler {
    NSURLRequest* req = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    [NSURLConnection sendAsynchronousRequest:req
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
                               handler(connectionError, data);
                           }];
}

+ (NSString*) writeToTempFile:(NSData*)indata error:(NSError* __autoreleasing*)error {
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
    [tempFileHandle writeData:indata];
    [tempFileHandle closeFile];
    
    return tempFilePath;
}

@end
