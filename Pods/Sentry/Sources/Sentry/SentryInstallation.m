#import "SentryInstallation.h"
#import "SentryDefines.h"
#import "SentryDependencyContainer.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryLog.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryInstallation ()
@property (class, nonatomic, readonly)
    NSMutableDictionary<NSString *, NSString *> *installationStringsByCacheDirectoryPaths;

@end

@implementation SentryInstallation

+ (NSMutableDictionary<NSString *, NSString *> *)installationStringsByCacheDirectoryPaths
{
    static dispatch_once_t once;
    static NSMutableDictionary *dictionary;

    dispatch_once(&once, ^{ dictionary = [NSMutableDictionary dictionary]; });
    return dictionary;
}

+ (NSString *)idWithCacheDirectoryPath:(NSString *)cacheDirectoryPath
{
    @synchronized(self) {
        NSString *installationString
            = self.installationStringsByCacheDirectoryPaths[cacheDirectoryPath];

        if (nil != installationString) {
            return installationString;
        }

        installationString =
            [SentryInstallation idWithCacheDirectoryPathNonCached:cacheDirectoryPath];

        if (installationString == nil) {
            installationString = [NSUUID UUID].UUIDString;

            NSData *installationStringData =
                [installationString dataUsingEncoding:NSUTF8StringEncoding];
            NSFileManager *fileManager = [NSFileManager defaultManager];

            NSString *installationFilePath =
                [SentryInstallation installationFilePath:cacheDirectoryPath];

            if (![fileManager createFileAtPath:installationFilePath
                                      contents:installationStringData
                                    attributes:nil]) {
                SENTRY_LOG_ERROR(
                    @"Failed to store installationID file at path %@", installationFilePath);
            }
        }

        self.installationStringsByCacheDirectoryPaths[cacheDirectoryPath] = installationString;
        return installationString;
    }
}

+ (nullable NSString *)idWithCacheDirectoryPathNonCached:(NSString *)cacheDirectoryPath
{
    NSString *installationFilePath = [SentryInstallation installationFilePath:cacheDirectoryPath];

    NSData *installationData = [NSData dataWithContentsOfFile:installationFilePath];

    if (installationData != nil) {
        return [[NSString alloc] initWithData:installationData encoding:NSUTF8StringEncoding];
    } else {
        return nil;
    }
}

+ (void)cacheIDAsyncWithCacheDirectoryPath:(NSString *)cacheDirectoryPath
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchAsyncWithBlock:^{
        [SentryInstallation idWithCacheDirectoryPath:cacheDirectoryPath];
    }];
}

+ (NSString *)installationFilePath:(NSString *)cacheDirectoryPath
{
    return [cacheDirectoryPath stringByAppendingPathComponent:@"INSTALLATION"];
}

@end

NS_ASSUME_NONNULL_END
