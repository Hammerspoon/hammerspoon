#import <CommonCrypto/CommonDigest.h>

#import "SentryDsn.h"
#import "SentryError.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryDsn ()

@end

@implementation SentryDsn {
    NSURL *_storeEndpoint;
    NSURL *_envelopeEndpoint;
}

- (_Nullable instancetype)initWithString:(NSString *)dsnString
                        didFailWithError:(NSError *_Nullable *_Nullable)error
{
    self = [super init];
    if (self) {
        _url = [self convertDsnString:dsnString didFailWithError:error];
        if (_url == nil) {
            return nil;
        }
    }
    return self;
}

- (NSString *)getHash
{
    NSData *data = [[self.url absoluteString] dataUsingEncoding:NSUTF8StringEncoding];
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) {
        [output appendFormat:@"%02x", digest[i]];
    }
    return output;
}

- (NSURL *)getStoreEndpoint
{
    if (nil == _storeEndpoint) {
        @synchronized(self) {
            if (nil == _storeEndpoint) {
                _storeEndpoint = [[self getBaseEndpoint] URLByAppendingPathComponent:@"store/"];
            }
        }
    }
    return _storeEndpoint;
}

- (NSURL *)getEnvelopeEndpoint
{
    if (nil == _envelopeEndpoint) {
        @synchronized(self) {
            if (nil == _envelopeEndpoint) {
                _envelopeEndpoint =
                    [[self getBaseEndpoint] URLByAppendingPathComponent:@"envelope/"];
            }
        }
    }
    return _envelopeEndpoint;
}

- (NSURL *)getBaseEndpoint
{
    NSURL *url = self.url;
    NSString *projectId = url.lastPathComponent;
    NSMutableArray *paths = [url.pathComponents mutableCopy];
    // [0] = /
    // [1] = projectId
    // If there are more than two, that means someone wants to have an
    // additional path ref: https://github.com/getsentry/sentry-cocoa/issues/236
    NSString *path = @"";
    if ([paths count] > 2) {
        [paths removeObjectAtIndex:0]; // We remove the leading /
        [paths removeLastObject]; // We remove projectId since we add it later
        path = [NSString stringWithFormat:@"/%@",
                         [paths componentsJoinedByString:@"/"]]; // We put together the path
    }
    NSURLComponents *components = [NSURLComponents new];
    components.scheme = url.scheme;
    components.host = url.host;
    components.port = url.port;
    components.path = [NSString stringWithFormat:@"%@/api/%@/", path, projectId];
    return components.URL;
}

- (NSURL *_Nullable)convertDsnString:(NSString *)dsnString
                    didFailWithError:(NSError *_Nullable *_Nullable)error
{
    NSString *trimmedDsnString = [dsnString
        stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSSet *allowedSchemes = [NSSet setWithObjects:@"http", @"https", nil];
    NSURL *url = [NSURL URLWithString:trimmedDsnString];
    NSString *errorMessage = nil;
    if (nil == url.scheme) {
        errorMessage = @"URL scheme of DSN is missing";
        url = nil;
    }
    if (![allowedSchemes containsObject:url.scheme]) {
        errorMessage = @"Unrecognized URL scheme in DSN";
        url = nil;
    }
    if (nil == url.host || url.host.length == 0) {
        errorMessage = @"Host component of DSN is missing";
        url = nil;
    }
    if (nil == url.user) {
        errorMessage = @"User component of DSN is missing";
        url = nil;
    }
    if (url.pathComponents.count < 2) {
        errorMessage = @"Project ID path component of DSN is missing";
        url = nil;
    }
    if (nil == url) {
        if (nil != error) {
            *error = NSErrorFromSentryError(kSentryErrorInvalidDsnError, errorMessage);
        }
        return nil;
    }
    return url;
}

@end

NS_ASSUME_NONNULL_END
