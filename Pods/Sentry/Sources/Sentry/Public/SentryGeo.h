#import "SentryDefines.h"
#import "SentrySerializable.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Approximate geographical location of the end user or device.
///
/// Example of serialized data:
/// {
///   "geo": {
///     "country_code": "US",
///     "city": "Ashburn",
///     "region": "San Francisco"
///   }
/// }
NS_SWIFT_NAME(Geo)
@interface SentryGeo : NSObject <SentrySerializable, NSCopying>

/**
 * Optional: Human readable city name.
 */
@property (nullable, atomic, copy) NSString *city;

/**
 * Optional: Two-letter country code (ISO 3166-1 alpha-2).
 */
@property (nullable, atomic, copy) NSString *countryCode;

/**
 * Optional: Human readable region name or code.
 */
@property (nullable, atomic, copy) NSString *region;

- (BOOL)isEqual:(id _Nullable)other;

- (BOOL)isEqualToGeo:(SentryGeo *)geo;

- (NSUInteger)hash;

@end

NS_ASSUME_NONNULL_END
