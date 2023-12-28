#import "SentryDateUtil.h"
#import "SentryCurrentDateProvider.h"
#import "SentryDependencyContainer.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryDateUtil ()

@end

@implementation SentryDateUtil

+ (BOOL)isInFuture:(NSDate *_Nullable)date
{
    if (date == nil)
        return NO;

    NSComparisonResult result =
        [[SentryDependencyContainer.sharedInstance.dateProvider date] compare:date];
    return result == NSOrderedAscending;
}

+ (NSDate *_Nullable)getMaximumDate:(NSDate *_Nullable)first andOther:(NSDate *_Nullable)second
{
    if (first == nil && second == nil)
        return nil;
    if (first == nil)
        return second;
    if (second == nil)
        return first;

    NSComparisonResult result = [first compare:second];
    if (result == NSOrderedDescending) {
        return first;
    } else {
        return second;
    }
}

@end

NS_ASSUME_NONNULL_END
