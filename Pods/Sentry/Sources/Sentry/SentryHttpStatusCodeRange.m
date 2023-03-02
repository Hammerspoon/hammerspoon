#import "SentryHttpStatusCodeRange.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryHttpStatusCodeRange

- (instancetype)initWithMin:(NSInteger)min max:(NSInteger)max
{
    if (self = [super init]) {
        _min = min;
        _max = max;
    }
    return self;
}

- (instancetype)initWithStatusCode:(NSInteger)statusCode
{
    if (self = [super init]) {
        _min = statusCode;
        _max = statusCode;
    }
    return self;
}

- (BOOL)isInRange:(NSInteger)statusCode
{
    return statusCode >= _min && statusCode <= _max;
}

@end

NS_ASSUME_NONNULL_END
