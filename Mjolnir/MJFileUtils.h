#import <Foundation/Foundation.h>

void MJDownloadFile(NSString* url, void(^handler)(NSError* err, NSData* data));
NSString* MJCreateEmptyTempDirectory(NSString* prefix, NSString* suffix, NSError* __autoreleasing* error);
NSString* MJWriteToTempFile(NSData* indata, NSString* prefix, NSString* suffix, NSError* __autoreleasing* error);
