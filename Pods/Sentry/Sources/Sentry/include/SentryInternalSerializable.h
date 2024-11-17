#import "SentryDefines.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Use this protocol for internal ObjC classes that are exposed to Swift code by adding them to
 * SentryPrivate.h instead of SentrySerializable because CocoaPods throws duplicate header warnings
 * when running pod lib lint when using a public protocol on such classes.
 */
@protocol SentryInternalSerializable <NSObject>
SENTRY_NO_INIT

- (NSDictionary<NSString *, id> *)serialize;

@end

NS_ASSUME_NONNULL_END
