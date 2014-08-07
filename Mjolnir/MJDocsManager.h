#import <Foundation/Foundation.h>
#import "MJExtension.h"

@interface MJDocsManager : NSObject

+ (NSURL*) docsFile;
+ (void) copyDocsIfNeeded;

+ (void) installExtensionInDirectory:(NSString*)extdir;
+ (void) uninstallExtensionInDirectory:(NSString*)extdir;

@end
