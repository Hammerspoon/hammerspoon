#import "SentryBaseIntegration.h"
#import "SentryClient+Private.h"
#import "SentryIntegrationProtocol.h"
#import "SentryScreenshot.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
#if SENTRY_HAS_UIKIT

@interface SentryScreenshotIntegration
    : SentryBaseIntegration <SentryIntegrationProtocol, SentryClientAttachmentProcessor>

@end

#endif

NS_ASSUME_NONNULL_END
