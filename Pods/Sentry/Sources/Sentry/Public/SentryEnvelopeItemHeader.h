#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif
#import SENTRY_HEADER(SentrySerializable)

NS_ASSUME_NONNULL_BEGIN

@interface SentryEnvelopeItemHeader : NSObject <SentrySerializable>
SENTRY_NO_INIT

- (instancetype)initWithType:(NSString *)type length:(NSUInteger)length NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithType:(NSString *)type
                      length:(NSUInteger)length
                 contentType:(NSString *)contentType;

- (instancetype)initWithType:(NSString *)type
                      length:(NSUInteger)length
                   filenname:(NSString *)filename
                 contentType:(NSString *)contentType;

- (instancetype)initWithType:(NSString *)type
                      length:(NSUInteger)length
                 contentType:(NSString *)contentType
                   itemCount:(NSNumber *)itemCount;

/**
 * The type of the envelope item.
 */
@property (nonatomic, readonly, copy) NSString *type;
@property (nonatomic, readonly) NSUInteger length;
@property (nonatomic, readonly, copy, nullable) NSString *filename;
@property (nonatomic, readonly, copy, nullable) NSString *contentType;
@property (nonatomic, readonly, copy, nullable) NSNumber *itemCount;

/**
 * Some envelopes need to report the platform name for enhanced rate limiting functionality in
 * relay.
 */
@property (nonatomic, copy, nullable) NSString *platform;

@end

NS_ASSUME_NONNULL_END
