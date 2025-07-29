#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions;

@protocol SentryIntegrationProtocol <NSObject>

/**
 * Installs the integration and returns YES if successful.
 */
- (BOOL)installWithOptions:(SentryOptions *)options NS_SWIFT_NAME(install(with:));

/**
 * Uninstalls the integration.
 */
- (void)uninstall;

@end

NS_ASSUME_NONNULL_END
