#import <Foundation/Foundation.h>

void MJDownloadFile(NSString* url, void(^handler)(NSError* err, NSData* data));
NSString* MJCreateEmptyTempDirectory(NSString* prefix, NSError* __autoreleasing* error);
NSString* MJWriteToTempFile(NSData* indata, NSString* prefix, NSString* suffix, NSError* __autoreleasing* error);
BOOL MJUntar(NSData* tardata, NSString* intoDirectory, NSError*__autoreleasing* error);
