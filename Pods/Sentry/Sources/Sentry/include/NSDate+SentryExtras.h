#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
NSDate (SentryExtras)

+ (NSDate *)sentry_fromIso8601String:(NSString *)string;

- (NSString *)sentry_toIso8601String;

@end

NS_ASSUME_NONNULL_END
