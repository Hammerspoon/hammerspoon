#import <Foundation/Foundation.h>

@interface MJFileDownloader : NSObject

+ (void) downloadExtension:(NSString*)url handler:(void(^)(NSError* err, NSData* data))handler;

@end
