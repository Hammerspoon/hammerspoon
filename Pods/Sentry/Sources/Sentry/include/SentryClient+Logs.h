#import "SentryClient.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryClient ()

/**
 * Helper to capture encoded logs, as SentryEnvelope can't be used in the Swift SDK.
 */
- (void)captureLogsData:(NSData *)data with:(NSNumber *)itemCount;

@end

NS_ASSUME_NONNULL_END
