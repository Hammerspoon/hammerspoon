#import <Foundation/Foundation.h>
#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif
#import SENTRY_HEADER(SentrySerializable)

NS_ASSUME_NONNULL_BEGIN

@class SentryFrame;

@interface SentryStacktrace : NSObject <SentrySerializable>
SENTRY_NO_INIT

/**
 * Array of all SentryFrame in the stacktrace
 */
@property (nonatomic, strong) NSArray<SentryFrame *> *frames;

/**
 * Registers of the thread for additional information used on the server
 */
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *registers;

/**
 * Indicates that this stack trace is a snapshot triggered by an external signal.
 */
@property (nonatomic, copy, nullable) NSNumber *snapshot;

/**
 * Initialize a SentryStacktrace with frames and registers
 * @param frames NSArray
 * @param registers NSArray
 * @return SentryStacktrace
 */
- (instancetype)initWithFrames:(NSArray<SentryFrame *> *)frames
                     registers:(NSDictionary<NSString *, NSString *> *)registers;

/**
 * This will be called internally, is used to remove duplicated frames for
 * certain crashes.
 */
- (void)fixDuplicateFrames;

@end

NS_ASSUME_NONNULL_END
