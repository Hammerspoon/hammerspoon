#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryBreadcrumb;

/**
 * This is a workaround to access SentryLevel value from swift
 */
NSUInteger sentry_breadcrumbLevel(SentryBreadcrumb *breadcrumb);

NS_ASSUME_NONNULL_END
