#import "SentryRateLimitParser.h"
#import "SentryCurrentDate.h"
#import "SentryDateUtil.h"
#import "SentryRateLimitCategoryMapper.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryRateLimitParser ()

@end

@implementation SentryRateLimitParser

- (NSDictionary<NSNumber *, NSDate *> *)parse:(NSString *)header
{
    if ([header length] == 0) {
        return @{};
    }

    NSMutableDictionary<NSNumber *, NSDate *> *rateLimits = [NSMutableDictionary new];

    // The header might contain whitespaces and they must be ignored.
    NSString *headerNoWhitespaces = [self removeAllWhitespaces:header];

    // Each quotaLimit exists of retryAfter:categories:scope. The scope is
    // ignored here as it can be ignored by SDKs.
    for (NSString *quota in [headerNoWhitespaces componentsSeparatedByString:@","]) {
        NSArray<NSString *> *parameters = [quota componentsSeparatedByString:@":"];

        NSNumber *rateLimitInSeconds = [self parseRateLimitSeconds:parameters[0]];
        if (nil == rateLimitInSeconds || [rateLimitInSeconds intValue] <= 0) {
            continue;
        }

        for (NSNumber *category in [self parseCategories:parameters[1]]) {
            rateLimits[category] = [self getLongerRateLimit:rateLimits[category]
                                      andRateLimitInSeconds:rateLimitInSeconds];
        }
    }

    return rateLimits;
}

- (NSString *)removeAllWhitespaces:(NSString *)string
{
    NSArray *words = [string
        componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return [words componentsJoinedByString:@""];
}

- (NSNumber *)parseRateLimitSeconds:(NSString *)string
{
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    numberFormatter.numberStyle = NSNumberFormatterNoStyle;
    return [numberFormatter numberFromString:string];
}

- (SentryRateLimitCategory)mapStringToCategory:(NSString *)category
{
    SentryRateLimitCategory result = kSentryRateLimitCategoryUnknown;
    if ([category isEqualToString:@""]) {
        result = kSentryRateLimitCategoryAll;
    }
    if ([category isEqualToString:@"default"]) {
        result = kSentryRateLimitCategoryDefault;
    }
    if ([category isEqualToString:@"error"]) {
        result = kSentryRateLimitCategoryError;
    }
    if ([category isEqualToString:@"session"]) {
        result = kSentryRateLimitCategorySession;
    }
    if ([category isEqualToString:@"transaction"]) {
        result = kSentryRateLimitCategoryTransaction;
    }
    if ([category isEqualToString:@"attachment"]) {
        result = kSentryRateLimitCategoryAttachment;
    }
    return result;
}

- (NSArray<NSNumber *> *)parseCategories:(NSString *)categoriesAsString
{
    // The categories are a semicolon separated list. If this parameter is empty
    // it stands for all categories. componentsSeparatedByString returns one
    // category even if this parameter is empty.
    NSMutableArray<NSNumber *> *categories = [NSMutableArray new];
    for (NSString *categoryAsString in [categoriesAsString componentsSeparatedByString:@";"]) {
        SentryRateLimitCategory category = [self mapStringToCategory:categoryAsString];

        // Unknown categories must be ignored
        if (category != kSentryRateLimitCategoryUnknown) {
            [categories addObject:@(category)];
        }
    }

    return categories;
}

- (NSDate *)getLongerRateLimit:(NSDate *)existingRateLimit
         andRateLimitInSeconds:(NSNumber *)newRateLimitInSeconds
{
    NSDate *newDate =
        [SentryCurrentDate.date dateByAddingTimeInterval:[newRateLimitInSeconds doubleValue]];
    return [SentryDateUtil getMaximumDate:newDate andOther:existingRateLimit];
}

@end

NS_ASSUME_NONNULL_END
