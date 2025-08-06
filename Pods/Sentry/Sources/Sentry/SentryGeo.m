#import "SentryGeo.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryGeo

- (id)copyWithZone:(nullable NSZone *)zone
{
    SentryGeo *copy = [[[self class] allocWithZone:zone] init];

    if (copy != nil) {
        copy.city = self.city;
        copy.countryCode = self.countryCode;
        copy.region = self.region;
    }

    return copy;
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [[NSMutableDictionary alloc] init];

    if (self.city) {
        [serializedData setValue:self.city forKey:@"city"];
    }

    if (self.countryCode) {
        [serializedData setValue:self.countryCode forKey:@"country_code"];
    }

    if (self.region) {
        [serializedData setValue:self.region forKey:@"region"];
    }

    return serializedData;
}

- (BOOL)isEqual:(id _Nullable)other
{
    if (other == self) {
        return YES;
    }
    if (!other || ![[other class] isEqual:[self class]]) {
        return NO;
    }

    return [self isEqualToGeo:other];
}

- (BOOL)isEqualToGeo:(SentryGeo *)geo
{
    if (self == geo) {
        return YES;
    }
    if (geo == nil) {
        return NO;
    }

    NSString *otherCity = geo.city;
    if (self.city != otherCity && ![self.city isEqualToString:otherCity]) {
        return NO;
    }

    NSString *otherCountryCode = geo.countryCode;
    if (self.countryCode != otherCountryCode
        && ![self.countryCode isEqualToString:otherCountryCode]) {
        return NO;
    }

    NSString *otherRegion = geo.region;
    if (self.region != otherRegion && ![self.region isEqualToString:otherRegion]) {
        return NO;
    }

    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = 17;

    hash = hash * 23 + [self.city hash];
    hash = hash * 23 + [self.countryCode hash];
    hash = hash * 23 + [self.region hash];

    return hash;
}

@end

NS_ASSUME_NONNULL_END
