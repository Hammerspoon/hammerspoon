#import <Foundation/Foundation.h>

#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SentrySerializable <NSObject>
SENTRY_NO_INIT

- (NSDictionary<NSString *, id> *)serialize;

@end

NS_ASSUME_NONNULL_END
