#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * The unit of measurement of a metric value.
 * @discussion Units augment metric values by giving them a magnitude and semantics. There are
 * certain types of units that are subdivided in their precision, such as the
 * @c SentryMeasurementUnitDuration for time measurements. The following unit types are available:
 * @c SentryMeasurementUnitDuration ,
 * @c SentryMeasurementUnitInformation ,  and @c SentryMeasurementUnitFraction .
 * @note When using the units to custom measurements, Sentry will apply formatting to display
 * measurement values in the UI.
 */
NS_SWIFT_NAME(MeasurementUnit)
@interface SentryMeasurementUnit : NSObject <NSCopying>
SENTRY_NO_INIT

/**
 * Returns an initialized SentryMeasurementUnit with a custom measurement unit.
 * @param unit Your own custom unit without built-in conversion in Sentry.
 */
- (instancetype)initWithUnit:(NSString *)unit;

/**
 * The @c NSString representation of the measurement unit.
 */
@property (readonly, copy) NSString *unit;

/**
 * Untyped value without a unit.
 */
@property (class, readonly, copy) SentryMeasurementUnit *none;

@end

/**
 * Time duration units.
 */
NS_SWIFT_NAME(MeasurementUnitDuration)
@interface SentryMeasurementUnitDuration : SentryMeasurementUnit
SENTRY_NO_INIT

/**
 * Nanosecond, 10^-9 seconds.
 */
@property (class, readonly, copy) SentryMeasurementUnitDuration *nanosecond;

/**
 * Microsecond , 10^-6 seconds.
 */
@property (class, readonly, copy) SentryMeasurementUnitDuration *microsecond;

/**
 * Millisecond, 10^-3 seconds.
 */
@property (class, readonly, copy) SentryMeasurementUnitDuration *millisecond;

/**
 * Full second.
 */
@property (class, readonly, copy) SentryMeasurementUnitDuration *second;

/**
 * Minute, 60 seconds.
 */
@property (class, readonly, copy) SentryMeasurementUnitDuration *minute;

/**
 * Hour, 3600 seconds.
 */
@property (class, readonly, copy) SentryMeasurementUnitDuration *hour;

/**
 * Day, 86,400 seconds.
 */
@property (class, readonly, copy) SentryMeasurementUnitDuration *day;

/**
 * Week, 604,800 seconds.
 */
@property (class, readonly, copy) SentryMeasurementUnitDuration *week;

@end

/**
 * Size of information units derived from bytes.
 * @see https://en.wikipedia.org/wiki/Units_of_information
 */
NS_SWIFT_NAME(MeasurementUnitInformation)
@interface SentryMeasurementUnitInformation : SentryMeasurementUnit
SENTRY_NO_INIT

/**
 * Bit, corresponding to 1/8 of a byte
 */
@property (class, readonly, copy) SentryMeasurementUnitInformation *bit;

/**
 * Byte.
 */
@property (class, readonly, copy) SentryMeasurementUnitInformation *byte;

/**
 * Kilobyte, 10^3 bytes
 */
@property (class, readonly, copy) SentryMeasurementUnitInformation *kilobyte;

/**
 * Kibibyte, 2^10 bytes.
 */
@property (class, readonly, copy) SentryMeasurementUnitInformation *kibibyte;

/**
 * Megabyte, 10^6 bytes
 */
@property (class, readonly, copy) SentryMeasurementUnitInformation *megabyte;

/**
 * Mebibyte, 2^20 bytes.
 */
@property (class, readonly, copy) SentryMeasurementUnitInformation *mebibyte;

/**
 * Gigabyte, 10^9 bytes
 */
@property (class, readonly, copy) SentryMeasurementUnitInformation *gigabyte;

/**
 * Gibibyte, 2^30 bytes.
 */
@property (class, readonly, copy) SentryMeasurementUnitInformation *gibibyte;

/**
 * Terabyte, 10^12 bytes
 */
@property (class, readonly, copy) SentryMeasurementUnitInformation *terabyte;

/**
 * Tebibyte, 2^40 bytes.
 */
@property (class, readonly, copy) SentryMeasurementUnitInformation *tebibyte;

/**
 * Petabyte, 10^15 bytes
 */
@property (class, readonly, copy) SentryMeasurementUnitInformation *petabyte;

/**
 * Pebibyte, 2^50 bytes.
 */
@property (class, readonly, copy) SentryMeasurementUnitInformation *pebibyte;

/**
 * Exabyte, 10^18 bytes
 */
@property (class, readonly, copy) SentryMeasurementUnitInformation *exabyte;

/**
 * Exbibyte, 2^60 bytes.
 */
@property (class, readonly, copy) SentryMeasurementUnitInformation *exbibyte;

@end

/**
 * Units of fraction.
 */
NS_SWIFT_NAME(MeasurementUnitFraction) @interface SentryMeasurementUnitFraction
    : SentryMeasurementUnit
SENTRY_NO_INIT

/**
 * Floating point fraction of @c 1 . g
 */
@property (class, readonly, copy) SentryMeasurementUnitFraction *ratio;

/**
 * Ratio expressed as a fraction of @c 100  @c 100% equals a ratio of @c 1.0
 */
@property (class, readonly, copy) SentryMeasurementUnitFraction *percent;

@end

NS_ASSUME_NONNULL_END
