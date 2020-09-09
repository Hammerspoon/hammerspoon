#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(CurrentDateProvider)
@protocol SentryCurrentDateProvider <NSObject>

- (NSDate *)date;

@end

NS_ASSUME_NONNULL_END
