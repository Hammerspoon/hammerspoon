#import "SentryNSURLRequest.h"
#import "NSData+SentryCompression.h"
#import "SentryClient.h"
#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryEvent.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentryMeta.h"
#import "SentrySDK+Private.h"
#import "SentrySerialization.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const SentryServerVersionString = @"7";
NSTimeInterval const SentryRequestTimeout = 15;

@interface
SentryNSURLRequest ()

@property (nonatomic, strong) SentryDsn *dsn;

@end

@implementation SentryNSURLRequest

- (_Nullable instancetype)initStoreRequestWithDsn:(SentryDsn *)dsn
                                         andEvent:(SentryEvent *)event
                                 didFailWithError:(NSError *_Nullable *_Nullable)error
{
    NSDictionary *serialized = [event serialize];
    NSData *jsonData = [SentrySerialization dataWithJSONObject:serialized];
    if (nil == jsonData) {
        SENTRY_LOG_ERROR(@"Event cannot be converted to JSON");
        return nil;
    }

    if ([SentrySDK.currentHub getClient].options.debug == YES) {
        SENTRY_LOG_DEBUG(@"Sending JSON -------------------------------");
        SENTRY_LOG_DEBUG(
            @"%@", [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]);
        SENTRY_LOG_DEBUG(@"--------------------------------------------");
    }
    return [self initStoreRequestWithDsn:dsn andData:jsonData didFailWithError:error];
}

- (_Nullable instancetype)initStoreRequestWithDsn:(SentryDsn *)dsn
                                          andData:(NSData *)data
                                 didFailWithError:(NSError *_Nullable *_Nullable)error
{
    NSURL *apiURL = [dsn getStoreEndpoint];
    self = [super initWithURL:apiURL
                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
              timeoutInterval:SentryRequestTimeout];
    if (self) {
        NSString *authHeader = newAuthHeader(dsn.url);

        self.HTTPMethod = @"POST";
        [self setValue:authHeader forHTTPHeaderField:@"X-Sentry-Auth"];
        [self setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [self setValue:SentryMeta.sdkName forHTTPHeaderField:@"User-Agent"];
        [self setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
        self.HTTPBody = [data sentry_gzippedWithCompressionLevel:-1 error:error];
    }
    return self;
}

- (_Nullable instancetype)initEnvelopeRequestWithDsn:(SentryDsn *)dsn
                                             andData:(NSData *)data
                                    didFailWithError:(NSError *_Nullable *_Nullable)error
{
    NSURL *apiURL = [dsn getEnvelopeEndpoint];
    self = [super initWithURL:apiURL
                  cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
              timeoutInterval:SentryRequestTimeout];
    if (self) {
        NSString *authHeader = newAuthHeader(dsn.url);

        self.HTTPMethod = @"POST";
        [self setValue:authHeader forHTTPHeaderField:@"X-Sentry-Auth"];
        [self setValue:@"application/x-sentry-envelope" forHTTPHeaderField:@"Content-Type"];
        [self setValue:SentryMeta.sdkName forHTTPHeaderField:@"User-Agent"];
        [self setValue:@"gzip" forHTTPHeaderField:@"Content-Encoding"];
        self.HTTPBody = [data sentry_gzippedWithCompressionLevel:-1 error:error];
    }

    return self;
}

static NSString *
newHeaderPart(NSString *key, id value)
{
    return [NSString stringWithFormat:@"%@=%@", key, value];
}

static NSString *
newAuthHeader(NSURL *url)
{
    NSMutableString *string = [NSMutableString stringWithString:@"Sentry "];
    [string appendFormat:@"%@,", newHeaderPart(@"sentry_version", SentryServerVersionString)];
    [string
        appendFormat:@"%@,",
        newHeaderPart(@"sentry_client",
            [NSString stringWithFormat:@"%@/%@", SentryMeta.sdkName, SentryMeta.versionString])];
    [string appendFormat:@"%@", newHeaderPart(@"sentry_key", url.user)];
    if (nil != url.password) {
        [string appendFormat:@",%@", newHeaderPart(@"sentry_secret", url.password)];
    }
    return string;
}

@end

NS_ASSUME_NONNULL_END
