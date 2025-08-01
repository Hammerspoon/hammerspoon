#import <Foundation/Foundation.h>
#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif

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
