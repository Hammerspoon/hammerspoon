#import "SentryMeasurementUnit.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryMeasurementUnit

- (instancetype)initWithUnit:(NSString *)unit
{
    if (self = [super init]) {
        _unit = unit;
    }
    return self;
}

+ (SentryMeasurementUnit *)none
{
    return [[SentryMeasurementUnitDuration alloc] initWithUnit:@""];
}

- (id)copyWithZone:(nullable NSZone *)zone
{
    return [[[self class] allocWithZone:zone] initWithUnit:self.unit];
}

@end

@implementation SentryMeasurementUnitDuration

+ (SentryMeasurementUnitDuration *)nanosecond
{
    return [[SentryMeasurementUnitDuration alloc] initWithUnit:@"nanosecond"];
}

+ (SentryMeasurementUnitDuration *)microsecond
{
    return [[SentryMeasurementUnitDuration alloc] initWithUnit:@"microsecond"];
}

+ (SentryMeasurementUnitDuration *)millisecond
{
    return [[SentryMeasurementUnitDuration alloc] initWithUnit:@"millisecond"];
}

+ (SentryMeasurementUnitDuration *)second
{
    return [[SentryMeasurementUnitDuration alloc] initWithUnit:@"second"];
}

+ (SentryMeasurementUnitDuration *)minute
{
    return [[SentryMeasurementUnitDuration alloc] initWithUnit:@"minute"];
}

+ (SentryMeasurementUnitDuration *)hour
{
    return [[SentryMeasurementUnitDuration alloc] initWithUnit:@"hour"];
}

+ (SentryMeasurementUnitDuration *)day
{
    return [[SentryMeasurementUnitDuration alloc] initWithUnit:@"day"];
}

+ (SentryMeasurementUnitDuration *)week
{
    return [[SentryMeasurementUnitDuration alloc] initWithUnit:@"week"];
}

@end

@implementation SentryMeasurementUnitInformation

+ (SentryMeasurementUnitInformation *)bit
{
    return [[SentryMeasurementUnitInformation alloc] initWithUnit:@"bit"];
}

+ (SentryMeasurementUnitInformation *)byte
{
    return [[SentryMeasurementUnitInformation alloc] initWithUnit:@"byte"];
}

+ (SentryMeasurementUnitInformation *)kilobyte
{
    return [[SentryMeasurementUnitInformation alloc] initWithUnit:@"kilobyte"];
}

+ (SentryMeasurementUnitInformation *)kibibyte
{
    return [[SentryMeasurementUnitInformation alloc] initWithUnit:@"kibibyte"];
}

+ (SentryMeasurementUnitInformation *)megabyte
{
    return [[SentryMeasurementUnitInformation alloc] initWithUnit:@"megabyte"];
}

+ (SentryMeasurementUnitInformation *)mebibyte
{
    return [[SentryMeasurementUnitInformation alloc] initWithUnit:@"mebibyte"];
}

+ (SentryMeasurementUnitInformation *)gigabyte
{
    return [[SentryMeasurementUnitInformation alloc] initWithUnit:@"gigabyte"];
}

+ (SentryMeasurementUnitInformation *)gibibyte
{
    return [[SentryMeasurementUnitInformation alloc] initWithUnit:@"gibibyte"];
}

+ (SentryMeasurementUnitInformation *)terabyte
{
    return [[SentryMeasurementUnitInformation alloc] initWithUnit:@"terabyte"];
}

+ (SentryMeasurementUnitInformation *)tebibyte
{
    return [[SentryMeasurementUnitInformation alloc] initWithUnit:@"tebibyte"];
}

+ (SentryMeasurementUnitInformation *)petabyte
{
    return [[SentryMeasurementUnitInformation alloc] initWithUnit:@"petabyte"];
}

+ (SentryMeasurementUnitInformation *)pebibyte
{
    return [[SentryMeasurementUnitInformation alloc] initWithUnit:@"pebibyte"];
}

+ (SentryMeasurementUnitInformation *)exabyte
{
    return [[SentryMeasurementUnitInformation alloc] initWithUnit:@"exabyte"];
}

+ (SentryMeasurementUnitInformation *)exbibyte
{
    return [[SentryMeasurementUnitInformation alloc] initWithUnit:@"exbibyte"];
}

@end

@implementation SentryMeasurementUnitFraction

+ (SentryMeasurementUnitFraction *)ratio
{
    return [[SentryMeasurementUnitFraction alloc] initWithUnit:@"ratio"];
}

+ (SentryMeasurementUnitFraction *)percent
{
    return [[SentryMeasurementUnitFraction alloc] initWithUnit:@"percent"];
}

@end

NS_ASSUME_NONNULL_END
