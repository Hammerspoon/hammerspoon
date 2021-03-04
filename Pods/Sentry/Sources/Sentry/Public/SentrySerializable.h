#import <Foundation/Foundation.h>

#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SentrySerializable <NSObject>
SENTRY_NO_INIT

/**
 * Serialize the contents of the object into an NSDictionary. Make to copy all properties of the
 * original object so modifications to it don't have an impact on the serialized NSDictionary.
 */
- (NSDictionary<NSString *, id> *)serialize;

@end

NS_ASSUME_NONNULL_END
