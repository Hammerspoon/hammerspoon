#import <Foundation/Foundation.h>

@interface MJExtension : NSObject <NSSecureCoding>

@property NSString* sha;
@property NSString* tarsha;
@property NSString* name;
@property NSString* author;
@property NSString* version;
@property NSString* tarfile;
@property NSString* website;
@property NSString* license;
@property NSString* desc;
@property NSArray* dependencies;

+ (MJExtension*) extensionWithShortJSON:(NSDictionary*)shortJSON longJSON:(NSDictionary*)longJSON;

@end
