#import <Foundation/Foundation.h>

@interface PKDocsManager : NSObject

+ (PKDocsManager*) sharedManager;

+ (NSURL*) docsFile;
+ (void) copyDocsIfNeeded;

@end
