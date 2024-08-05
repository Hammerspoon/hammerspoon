#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryBreadcrumb;

/**
 * This is a workaround to access SentryLevel value from swift
 */
@interface SentryLevelHelper : NSObject

+ (NSUInteger)breadcrumbLevel:(SentryBreadcrumb *)breadcrumb;

+ (NSString *_Nonnull)getNameFor:(NSUInteger)level;

@end

NS_ASSUME_NONNULL_END
