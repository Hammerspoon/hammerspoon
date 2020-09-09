#import "SentryCurrentDateProvider.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * A static API to return the current date. This allows to change the current
 * date, especially useful for testing.
 */
NS_SWIFT_NAME(CurrentDate)
@interface SentryCurrentDate : NSObject

+ (NSDate *_Nonnull)date;

+ (void)setCurrentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider;

@end

NS_ASSUME_NONNULL_END
