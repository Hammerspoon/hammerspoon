#import <Foundation/Foundation.h>
#import "MJExtension.h"

@interface MJDocsManager : NSObject

+ (NSURL*) docsFile;
+ (void) copyDocsIfNeeded;

+ (void) installExtension:(MJExtension*)ext;
+ (void) uninstallExtension:(MJExtension*)ext;

@end
