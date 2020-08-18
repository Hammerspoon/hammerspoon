#import "SentryDefaultCurrentDateProvider.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryDefaultCurrentDateProvider ()

@end

@implementation SentryDefaultCurrentDateProvider

- (NSDate *_Nonnull)date
{
    return [NSDate date];
}

@end

NS_ASSUME_NONNULL_END
