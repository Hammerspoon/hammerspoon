#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/**
 * An HTTP status code range.
 */
NS_SWIFT_NAME(HttpStatusCodeRange)
@interface SentryHttpStatusCodeRange : NSObject
SENTRY_NO_INIT

@property (nonatomic, readonly) NSInteger min;

@property (nonatomic, readonly) NSInteger max;

/**
 * The HTTP status code min and max.
 * @discussion The range is inclusive so the min and max is considered part of the range.
 * @example For a range: 400 to 499; 500 to 599; 400 to 599.
 */
- (instancetype)initWithMin:(NSInteger)min max:(NSInteger)max;

/**
 * The HTTP status code.
 * @example For a single status code: 400; 500.
 */
- (instancetype)initWithStatusCode:(NSInteger)statusCode;

@end

NS_ASSUME_NONNULL_END
