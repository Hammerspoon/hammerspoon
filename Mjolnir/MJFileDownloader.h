#import <Foundation/Foundation.h>

@interface MJFileDownloader : NSObject

+ (void) downloadFile:(NSString*)url handler:(void(^)(NSError* err, NSData* data))handler;

+ (NSString*) writeToTempFile:(NSData*)indata error:(NSError* __autoreleasing*)error;

@end
