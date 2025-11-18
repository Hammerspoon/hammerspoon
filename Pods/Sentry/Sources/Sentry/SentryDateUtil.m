#import "SentryDateUtil.h"
#import "SentryInternalDefines.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryDateUtil ()

@property (nonatomic, strong) id<SentryCurrentDateProvider> currentDateProvider;

@end

@implementation SentryDateUtil

- (instancetype)initWithCurrentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
{
    if (self = [super init]) {
        self.currentDateProvider = currentDateProvider;
    }
    return self;
}

- (BOOL)isInFuture:(NSDate *_Nullable)date
{
    if (date == nil)
        return NO;

    NSComparisonResult result =
        [[self.currentDateProvider date] compare:SENTRY_UNWRAP_NULLABLE(NSDate, date)];
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

    NSComparisonResult result =
        [SENTRY_UNWRAP_NULLABLE(NSDate, first) compare:SENTRY_UNWRAP_NULLABLE(NSDate, second)];
    if (result == NSOrderedDescending) {
        return first;
    } else {
        return second;
    }
}

+ (long)millisecondsSince1970:(NSDate *)date
{
    return (long)([date timeIntervalSince1970] * 1000);
}

@end

NS_ASSUME_NONNULL_END
