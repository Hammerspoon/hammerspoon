#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryBreadcrumb;
@class SentryEvent;

/**
 * This is a workaround to access SentryLevel value from swift
 */
@interface SentryLevelBridge : NSObject
+ (NSUInteger)breadcrumbLevel:(SentryBreadcrumb *)breadcrumb;
+ (void)setBreadcrumbLevel:(SentryBreadcrumb *)breadcrumb level:(NSUInteger)level;
+ (void)setBreadcrumbLevelOnEvent:(SentryEvent *)event level:(NSUInteger)level;
@end

NS_ASSUME_NONNULL_END
