#import "SentryLogOutput.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryLogOutput

- (void)log:(NSString *)message
{
    NSLog(@"%@", message);
}

@end

NS_ASSUME_NONNULL_END
