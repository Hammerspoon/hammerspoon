#import "SentryDefines.h"
#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryStacktrace;

@interface SentryThread : NSObject <SentrySerializable>
SENTRY_NO_INIT

/**
 * Number of the thread
 */
@property (nonatomic, copy) NSNumber *threadId;

/**
 * Name (if available) of the thread
 */
@property (nullable, nonatomic, copy) NSString *name;

/**
 * SentryStacktrace of the SentryThread
 */
@property (nullable, nonatomic, strong) SentryStacktrace *stacktrace;

/**
 * Did this thread crash?
 */
@property (nullable, nonatomic, copy) NSNumber *crashed;

/**
 * Was it the current thread.
 */
@property (nullable, nonatomic, copy) NSNumber *current;

/**
 * Was it the main thread?
 */
@property (nullable, nonatomic, copy) NSNumber *isMain;

/**
 * Initializes a SentryThread with its id
 * @param threadId NSNumber
 * @return SentryThread
 */
- (instancetype)initWithThreadId:(NSNumber *)threadId;

@end

NS_ASSUME_NONNULL_END
