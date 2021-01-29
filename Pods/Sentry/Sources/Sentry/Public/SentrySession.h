#import "SentryDefines.h"
#import "SentrySerializable.h"

@class SentryUser;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SentrySessionStatus) {
    kSentrySessionStatusOk = 0,
    kSentrySessionStatusExited = 1,
    kSentrySessionStatusCrashed = 2,
    kSentrySessionStatusAbnormal = 3,
};

@interface SentrySession : NSObject <SentrySerializable, NSCopying>
SENTRY_NO_INIT

- (instancetype)initWithReleaseName:(NSString *)releaseName;
- (instancetype)initWithJSONObject:(NSDictionary *)jsonObject;

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
  We can't use init because it overlaps with NSObject.init
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
