#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentryOptions.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SentryIntegrationProtocol <NSObject>

/**
 * installs the integration and returns YES if successful.
 */
- (void)installWithOptions:(SentryOptions *)options;

@end

NS_ASSUME_NONNULL_END
