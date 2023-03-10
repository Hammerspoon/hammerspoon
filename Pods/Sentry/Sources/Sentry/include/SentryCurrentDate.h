#import "SentryCurrentDateProvider.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A static API to return the current date. This allows to change the current
 * date, especially useful for testing.
 */
NS_SWIFT_NAME(CurrentDate)
@interface SentryCurrentDate : NSObject

+ (NSDate *)date;

+ (dispatch_time_t)dispatchTimeNow;

+ (void)setCurrentDateProvider:(nullable id<SentryCurrentDateProvider>)currentDateProvider;

+ (nullable id<SentryCurrentDateProvider>)getCurrentDateProvider;

@end

NS_ASSUME_NONNULL_END
