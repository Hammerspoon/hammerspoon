#import "SentrySpanId.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const emptyUUIDString = @"0000000000000000";

@interface
SentrySpanId ()

@property (nonatomic, strong) NSString *value;

@end

@implementation SentrySpanId

static SentrySpanId *_empty = nil;

- (instancetype)init
{
    return [self initWithUUID:[NSUUID UUID]];
}

- (instancetype)initWithUUID:(NSUUID *)uuid
{
    return [self initWithValue:[[uuid.UUIDString.lowercaseString
                                   stringByReplacingOccurrencesOfString:@"-"
                                                             withString:@""] substringToIndex:16]];
}

- (instancetype)initWithValue:(NSString *)value
{
    if (self = [super init]) {
        if (value.length != 16)
            return [SentrySpanId empty];
        value = value.lowercaseString;

        self.value = value;
    }

    return self;
}

- (NSString *)sentrySpanIdString;
{
    return self.value;
}

- (NSString *)description
{
    return [self sentrySpanIdString];
}

- (BOOL)isEqual:(id _Nullable)object
{
    if (object == self) {
        return YES;
    }
    if ([self class] != [object class]) {
        return NO;
    }

    SentrySpanId *otherSentryID = (SentrySpanId *)object;

    return [self.value isEqual:otherSentryID.value];
}

- (NSUInteger)hash
{
    return [self.value hash];
}

+ (SentrySpanId *)empty
{
    if (nil == _empty) {
        _empty = [[SentrySpanId alloc] initWithValue:emptyUUIDString];
    }
    return _empty;
}

- (id)copyWithZone:(nullable NSZone *)zone
{
    return [[SentrySpanId alloc] initWithValue:self.value];
}

@end

NS_ASSUME_NONNULL_END
