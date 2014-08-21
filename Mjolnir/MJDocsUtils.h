#import <Foundation/Foundation.h>
#import "MJExtension.h"

NSURL* MJDocsFile(void);
void MJDocsCopyIfNeeded(void);
BOOL MJDocsInstall(NSString* extdir, NSError* __autoreleasing* error);
BOOL MJDocsUninstall(NSString* extdir, NSError* __autoreleasing* error);
