#import <Foundation/Foundation.h>
#import "PKExtension.h"

@interface PKDocsManager : NSObject

+ (NSURL*) docsFile;
+ (void) copyDocsIfNeeded;

+ (void) installExtension:(PKExtension*)ext;
+ (void) uninstallExtension:(PKExtension*)ext;

@end
