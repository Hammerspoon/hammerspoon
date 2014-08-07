#import <Foundation/Foundation.h>

@interface MJArchiveManager : NSObject

+ (BOOL) untarData:(NSData*)tardata intoDirectory:(NSString*)dir error:(NSError*__autoreleasing*)error;

@end
