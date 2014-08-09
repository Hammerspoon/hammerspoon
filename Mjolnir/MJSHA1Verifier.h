#import <Foundation/Foundation.h>

@interface MJSHA1Verifier : NSObject

+ (BOOL) verifyTgzData:(NSData*)tgzdata sha:(NSString*)sha error:(NSError*__autoreleasing*)error;

@end

BOOL MJVerifySignedData(NSData* sig, NSData* data);
