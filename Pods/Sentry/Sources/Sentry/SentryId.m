#import "SentryId.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static NSString *const emptyUUIDString = @"00000000-0000-0000-0000-000000000000";

@interface
SentryId ()

@property (nonatomic, strong) NSUUID *uuid;

@end

@implementation SentryId

static SentryId *_empty = nil;

- (instancetype)init
{
    return [self initWithUUID:[NSUUID UUID]];
}

- (instancetype)initWithUUID:(NSUUID *)uuid
{
    if (self = [super init]) {
        self.uuid = uuid;
    }
    return self;
}

- (instancetype)initWithUUIDString:(NSString *)string
{
    NSUUID *uuid;
    if (string.length == 36) {
        uuid = [[NSUUID alloc] initWithUUIDString:string];
    } else if (string.length == 32) {
        NSMutableString *mutableString = [[NSMutableString alloc] initWithString:string];
        [mutableString insertString:@"-" atIndex:8];
        [mutableString insertString:@"-" atIndex:13];
        [mutableString insertString:@"-" atIndex:18];
        [mutableString insertString:@"-" atIndex:23];

        uuid = [[NSUUID alloc] initWithUUIDString:mutableString];
    }

    if (nil != uuid) {
        return [self initWithUUID:uuid];
    } else {
        return [self initWithUUIDString:emptyUUIDString];
    }
}

- (NSString *)sentryIdString;
{
    NSString *sentryIdString = [self.uuid.UUIDString stringByReplacingOccurrencesOfString:@"-"
                                                                               withString:@""];
    return [sentryIdString lowercaseString];
}

- (NSString *)description
{
    return [self sentryIdString];
}

- (BOOL)isEqual:(id _Nullable)object
{
    if (object == self) {
        return YES;
    }
    if ([self class] != [object class]) {
        return NO;
    }

    SentryId *otherSentryID = (SentryId *)object;

    return [self.uuid isEqual:otherSentryID.uuid];
}

- (NSUInteger)hash
{
    return [self.uuid hash];
}

+ (SentryId *)empty
{
    if (nil == _empty) {
        _empty = [[SentryId alloc] initWithUUIDString:emptyUUIDString];
    }
    return _empty;
}

@end

NS_ASSUME_NONNULL_END
