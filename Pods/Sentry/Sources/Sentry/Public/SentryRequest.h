#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif
#import SENTRY_HEADER(SentrySerializable)

NS_ASSUME_NONNULL_BEGIN

@interface SentryRequest : NSObject <SentrySerializable>

/**
 * Optional: HTTP response body size.
 */
@property (nonatomic, copy, nullable) NSNumber *bodySize;

/**
 * Optional: The cookie values.
 */
@property (nonatomic, copy, nullable) NSString *cookies;

/**
 * Optional: A dictionary of submitted headers.
 */
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *headers;

/**
 * Optional: The fragment of the request URL.
 */
@property (nonatomic, copy, nullable) NSString *fragment;

/**
 * Optional: HTTP request method.
 */
@property (nonatomic, copy, nullable) NSString *method;

/**
 * Optional: The query string component of the URL.
 */
@property (nonatomic, copy, nullable) NSString *queryString;

/**
 * Optional: The URL of the request if available.
 */
@property (nonatomic, copy, nullable) NSString *url;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
