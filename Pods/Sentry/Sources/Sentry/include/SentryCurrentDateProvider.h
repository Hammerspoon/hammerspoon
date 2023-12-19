#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(CurrentDateProvider)
@interface SentryCurrentDateProvider : NSObject

- (NSDate *)date;

- (dispatch_time_t)dispatchTimeNow;

- (NSInteger)timezoneOffset;

- (uint64_t)systemTime;

@end

NS_ASSUME_NONNULL_END
