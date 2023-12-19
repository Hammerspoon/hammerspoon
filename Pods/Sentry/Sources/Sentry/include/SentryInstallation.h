#import <Foundation/Foundation.h>

#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryInstallation : NSObject

+ (NSString *)idWithCacheDirectoryPath:(NSString *)cacheDirectoryPath;

@end

NS_ASSUME_NONNULL_END
