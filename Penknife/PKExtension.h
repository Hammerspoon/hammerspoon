#import <Foundation/Foundation.h>

@interface PKExtension : NSObject <NSSecureCoding>

@property NSString* sha;
@property NSString* name;
@property NSString* author;
@property NSString* version;
@property NSString* tarfile;
@property NSString* website;
@property NSString* license;

@end
