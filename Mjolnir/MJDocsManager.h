#import <Foundation/Foundation.h>
#import "MJExtension.h"

@interface MJDocsManager : NSObject

+ (NSURL*) docsFile;
+ (void) copyDocsIfNeeded;

+ (BOOL) installExtensionInDirectory:(NSString*)extdir error:(NSError* __autoreleasing*)error;
+ (BOOL) uninstallExtensionInDirectory:(NSString*)extdir error:(NSError* __autoreleasing*)error;

@end
