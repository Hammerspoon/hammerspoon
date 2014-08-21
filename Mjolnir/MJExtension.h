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
@property NSString* changelog;
@property NSArray* dependencies;
@property NSString* minosx;
@property MJExtension* previous;

+ (MJExtension*) extensionWithJSON:(NSDictionary*)json;

- (void) install:(void(^)(NSError*))done;
- (void) uninstall:(void(^)(NSError*))done;

- (BOOL) canInstall;

@end
