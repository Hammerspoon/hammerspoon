#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryClient;

@interface SentryStatsdClient : NSObject
SENTRY_NO_INIT

- (instancetype)initWithClient:(SentryClient *)client;

- (void)captureStatsdEncodedData:(NSData *)statsdEncodedData;

@end

NS_ASSUME_NONNULL_END
