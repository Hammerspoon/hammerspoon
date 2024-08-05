#import "SentryBreadcrumb.h"
#import "SentryDateUtils.h"
#import "SentryLevelMapper.h"
#import "SentryNSDictionarySanitize.h"
#import "SentrySwift.h"

@interface
SentryBreadcrumb ()
@property (atomic, strong) NSDictionary<NSString *, id> *_Nullable unknown;
@end

@implementation SentryBreadcrumb

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    if (self = [super init]) {
        NSMutableDictionary *unknown = [NSMutableDictionary dictionary];
        for (id key in dictionary) {
            id value = [dictionary valueForKey:key];
            if (value == nil) {
                continue;
            }
            BOOL isString = [value isKindOfClass:[NSString class]];
            BOOL isDictionary = [value isKindOfClass:[NSDictionary class]];

            if ([key isEqualToString:@"level"] && isString) {
                self.level = sentryLevelForString(value);
            } else if ([key isEqualToString:@"timestamp"] && isString) {
                self.timestamp = sentry_fromIso8601String(value);
            } else if ([key isEqualToString:@"category"] && isString) {
                self.category = value;
            } else if ([key isEqualToString:@"type"] && isString) {
                self.type = value;
            } else if ([key isEqualToString:@"message"] && isString) {
                self.message = value;
            } else if ([key isEqualToString:@"data"] && isDictionary) {
                self.data = value;
            } else {
                unknown[key] = value;
            }
        }
        if (unknown.count > 0) {
            self.unknown = [unknown copy];
        }
    }
    return self;
}

- (instancetype)initWithLevel:(enum SentryLevel)level category:(NSString *)category
{
    self = [super init];
    if (self) {
        self.level = level;
        self.category = category;
        self.timestamp = [NSDate date];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithLevel:kSentryLevelInfo category:@"default"];
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [NSMutableDictionary new];

    [serializedData setValue:nameForSentryLevel(self.level) forKey:@"level"];
    [serializedData setValue:sentry_toIso8601String(self.timestamp) forKey:@"timestamp"];
    [serializedData setValue:self.category forKey:@"category"];
    [serializedData setValue:self.type forKey:@"type"];
    [serializedData setValue:self.message forKey:@"message"];
    [serializedData setValue:sentry_sanitize(self.data) forKey:@"data"];
    NSDictionary<NSString *, id> *unknown = self.unknown;
    if (unknown != nil) {
        for (id key in unknown) {
            [serializedData setValue:unknown[key] forKey:key];
        }
    }
    return serializedData;
}

- (BOOL)isEqual:(id _Nullable)other
{
    if (other == self)
        return YES;
    if (!other || ![[other class] isEqual:[self class]])
        return NO;

    return [self isEqualToBreadcrumb:other];
}

- (BOOL)isEqualToBreadcrumb:(SentryBreadcrumb *)breadcrumb
{
    if (self == breadcrumb)
        return YES;
    if (breadcrumb == nil)
        return NO;
    if (self.level != breadcrumb.level)
        return NO;
    if (self.category != breadcrumb.category
        && ![self.category isEqualToString:breadcrumb.category])
        return NO;
    if (self.timestamp != breadcrumb.timestamp
        && ![self.timestamp isEqualToDate:breadcrumb.timestamp])
        return NO;
    if (self.type != breadcrumb.type && ![self.type isEqualToString:breadcrumb.type])
        return NO;
    if (self.message != breadcrumb.message && ![self.message isEqualToString:breadcrumb.message])
        return NO;
    if (self.data != breadcrumb.data && ![self.data isEqualToDictionary:breadcrumb.data])
        return NO;
    if (self.unknown != breadcrumb.unknown
        && ![self.unknown isEqualToDictionary:breadcrumb.unknown])
        return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = 17;
    hash = hash * 23 + (NSUInteger)self.level;
    hash = hash * 23 + [self.category hash];
    hash = hash * 23 + [self.timestamp hash];
    hash = hash * 23 + [self.type hash];
    hash = hash * 23 + [self.message hash];
    hash = hash * 23 + [self.data hash];
    hash = hash * 23 + [self.unknown hash];
    return hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, %@>", [self class], self, [self serialize]];
}

@end
