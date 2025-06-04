#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryFileManager;

@interface SentryWatchdogTerminationBreadcrumbProcessor : NSObject

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs
                           fileManager:(SentryFileManager *)fileManager;

- (void)addSerializedBreadcrumb:(NSDictionary *)crumb;

- (void)clearBreadcrumbs;

- (void)clear;

@end

NS_ASSUME_NONNULL_END
