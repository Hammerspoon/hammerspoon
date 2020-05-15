#import "SentryEvent.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SentrySessionStatus) {
    kSentrySessionStatusOk = 0,
    kSentrySessionStatusExited = 1,
    kSentrySessionStatusCrashed = 2,
    kSentrySessionStatusAbnormal = 3,
};

@interface SentrySession : NSObject

- (instancetype)init;
- (instancetype)initWithJSONObject:(NSDictionary *)jsonObject;

- (void)endSessionExitedSessionWithTimestamp:(NSDate *)timestamp;
- (void)endSessionCrashedWithTimestamp:(NSDate *)timestamp;
- (void)endSessionAbnormalWithTimestamp:(NSDate *)timestamp;

- (void)incrementErrors;

@property(nonatomic, readonly, strong) NSUUID *sessionId;
@property(nonatomic, readonly, strong) NSDate *started;
@property(nonatomic, readonly) enum SentrySessionStatus status;
@property(nonatomic, readonly) NSInteger errors;
@property(nonatomic, readonly) NSInteger sequence;
@property(nonatomic, strong) NSString *distinctId;

@property(nonatomic, copy) NSNumber *_Nullable init;
@property(nonatomic, strong) NSDate *_Nullable timestamp;
@property(nonatomic, strong) NSNumber *_Nullable duration;
@property(nonatomic, copy) NSString *_Nullable releaseName;
@property(nonatomic, copy) NSString *_Nullable environment;
@property(nonatomic, copy) SentryUser *_Nullable user;

- (NSDictionary<NSString *, id> *)serialize;

@end

NS_ASSUME_NONNULL_END
