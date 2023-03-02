#import "SentryDateUtil.h"
#import "SentryCurrentDate.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryDateUtil ()

@end

@implementation SentryDateUtil

+ (BOOL)isInFuture:(NSDate *_Nullable)date
{
    if (nil == date)
        return NO;

    NSComparisonResult result = [[SentryCurrentDate date] compare:date];
    return result == NSOrderedAscending;
}

+ (NSDate *_Nullable)getMaximumDate:(NSDate *_Nullable)first andOther:(NSDate *_Nullable)second
{
    if (nil == first && nil == second)
        return nil;
    if (nil == first)
        return second;
    if (nil == second)
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
