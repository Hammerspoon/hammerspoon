#import <Foundation/Foundation.h>
#import <Sentry/SentryDefines.h>

NS_ASSUME_NONNULL_BEGIN
#if SENTRY_UIKIT_AVAILABLE
@class SentryReplayOptions;

@protocol SentryViewScreenshotProvider;
@protocol SentryReplayBreadcrumbConverter;
@protocol SentryRRWebEvent;

@interface SentrySessionReplayIntegration : NSObject

- (void)startWithOptions:(SentryReplayOptions *)replayOptions
      screenshotProvider:(id<SentryViewScreenshotProvider>)screenshotProvider
     breadcrumbConverter:(id<SentryReplayBreadcrumbConverter>)breadcrumbConverter
             fullSession:(BOOL)shouldReplayFullSession;

@end

@interface
SentrySessionReplayIntegration ()

+ (id<SentryRRWebEvent>)createBreadcrumbwithTimestamp:(NSDate *)timestamp
                                             category:(NSString *)category
                                              message:(nullable NSString *)message
                                                level:(enum SentryLevel)level
                                                 data:(nullable NSDictionary<NSString *, id> *)data;

+ (id<SentryRRWebEvent>)createNetworkBreadcrumbWithTimestamp:(NSDate *)timestamp
                                                endTimestamp:(NSDate *)endTimestamp
                                                   operation:(NSString *)operation
                                                 description:(NSString *)description
                                                        data:(NSDictionary<NSString *, id> *)data;

+ (id<SentryReplayBreadcrumbConverter>)createDefaultBreadcrumbConverter;

@end

#endif
NS_ASSUME_NONNULL_END
