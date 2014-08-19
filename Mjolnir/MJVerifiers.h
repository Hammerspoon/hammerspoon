#import <Foundation/Foundation.h>

BOOL MJVerifyTgzData(NSData* tgzdata, NSString* sha, NSError*__autoreleasing* error);
BOOL MJVerifySignedData(NSData* sig, NSData* data);
