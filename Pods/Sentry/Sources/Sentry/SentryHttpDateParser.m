#import "SentryHttpDateParser.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryHttpDateParser ()

@property (nonatomic, strong) NSDateFormatter *dateFormatter;

@end

/**
 *  According to
 * https://developer.apple.com/documentation/foundation/nsdateformatter
 *  NSDateFormatter is not guaranteed to be thread safe on all macOS
 * applications yet. Therefore it must not be mutated from multiple threads. As
 * we only modify NSDateFormatter during init we don't need any locks.
 */
@implementation SentryHttpDateParser

- (instancetype)init
{
    if (self = [super init]) {
        self.dateFormatter = [[NSDateFormatter alloc] init];
        [self.dateFormatter setDateFormat:@"EEE',' dd' 'MMM' 'yyyy HH':'mm':'ss zzz"];
        // Http dates are always expressed in GMT, never in local time.
        [self.dateFormatter setTimeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
    }
    return self;
}

- (NSDate *_Nullable)dateFromString:(NSString *)string
{
    return [self.dateFormatter dateFromString:string];
}

@end

NS_ASSUME_NONNULL_END
