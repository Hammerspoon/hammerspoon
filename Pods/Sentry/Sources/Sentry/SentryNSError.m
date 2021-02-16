#import "SentryNSError.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryNSError

- (instancetype)initWithDomain:(NSString *)domain code:(NSInteger)code
{
    if (self = [super init]) {
        _domain = domain;
        _code = code;
    }
    return self;
}

- (NSDictionary<NSString *, id> *)serialize
{
    return @{ @"domain" : self.domain, @"code" : @(self.code) };
}

@end

NS_ASSUME_NONNULL_END
