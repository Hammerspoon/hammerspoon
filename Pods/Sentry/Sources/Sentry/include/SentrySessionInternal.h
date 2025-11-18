#import "SentryDefines.h"

@class SentryUser;

NS_ASSUME_NONNULL_BEGIN

NSString *nameForSentrySessionStatus(NSUInteger status);

typedef NS_ENUM(NSUInteger, InternalSentrySessionStatus) {
    kSentrySessionStatusOk = 0,
    kSentrySessionStatusExited = 1,
    kSentrySessionStatusCrashed = 2,
    kSentrySessionStatusAbnormal = 3,
};

/**
 * The SDK uses SentrySession to inform Sentry about release and project associated project health.
 */
@interface SentrySessionInternal : NSObject
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

- (void)setFlagInit;

@property (nonatomic, readonly, strong) NSUUID *sessionId;
@property (nonatomic, readonly, strong) NSDate *started;
@property (nonatomic, readonly) InternalSentrySessionStatus status;
@property (nonatomic) NSUInteger errors;
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

/**
 * The reason for session to become abnormal, for example an app hang.
 */
@property (nonatomic, copy) NSString *_Nullable abnormalMechanism;

- (NSDictionary<NSString *, id> *)serialize;

- (SentrySessionInternal *)safeCopyWithZone:(nullable NSZone *)zone;

@end

NS_ASSUME_NONNULL_END
