#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

#    import "SentryBaseIntegration.h"
#    import "SentryClient+Private.h"
#    import "SentryIntegrationProtocol.h"
#    import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryViewHierarchyIntegration
    : SentryBaseIntegration <SentryIntegrationProtocol, SentryClientAttachmentProcessor>

@end

NS_ASSUME_NONNULL_END

#endif // SENTRY_HAS_UIKIT
