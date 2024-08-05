#import "SentryDefines.h"

@class SentryUser;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SentrySessionStatus) {
    kSentrySessionStatusOk = 0,
    kSentrySessionStatusExited = 1,
    kSentrySessionStatusCrashed = 2,
    kSentrySessionStatusAbnormal = 3,
};

/**
 * The SDK uses SentrySession to inform Sentry about release and project associated project health.
 */
@interface SentrySession : NSObject <NSCopying>
SENTRY_NO_INIT

- (instancetype)initWithReleaseName:(NSString *)releaseName distinctId:(NSString *)distinctId;

/**
 * Initializes @c SentrySession from a JSON object.
 * @param jsonObject The @c jsonObject containing the session.
 * @return The @c SentrySession or @c nil if @c jsonObject contains an error.
 */
- (nullable instancetype)initWithJSONObject:(NSDictionary *)jsonObject;

- (void)endSessionExitedWithTimestamp:(NSDate *)timestamp;
- (void)endSessionCrashedWithTimestamp:(NSDate *)timestamp;
- (void)endSessionAbnormalWithTimestamp:(NSDate *)timestamp;

- (void)incrementErrors;

@property (nonatomic, readonly, strong) NSUUID *sessionId;
@property (nonatomic, readonly, strong) NSDate *started;
@property (nonatomic, readonly) enum SentrySessionStatus status;
@property (nonatomic, readonly) NSUInteger errors;
@property (nonatomic, readonly) NSUInteger sequence;
@property (nonatomic, readonly, strong) NSString *distinctId;
/**
 * We can't use @c init because it overlaps with @c NSObject.init .
 */
@property (nonatomic, readonly, copy) NSNumber *_Nullable flagInit;
@property (nonatomic, readonly, strong) NSDate *_Nullable timestamp;
@property (nonatomic, readonly, strong) NSNumber *_Nullable duration;

@property (nonatomic, readonly, copy) NSString *_Nullable releaseName;
@property (nonatomic, copy) NSString *_Nullable environment;
@property (nonatomic, copy) SentryUser *_Nullable user;

- (NSDictionary<NSString *, id> *)serialize;

@end

NS_ASSUME_NONNULL_END
