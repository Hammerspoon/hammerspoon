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
    NSData *jsonData = [SentrySerialization dataWithJSONObject:serialized error:error];
    if (nil == jsonData) {
        if (error) {
            // TODO: We're possibly overriding an error set by the actual
            // code that failed ^
            *error = NSErrorFromSentryError(
                kSentryErrorJsonConversionError, @"Event cannot be converted to JSON");
        }
        return nil;
    }

    if ([SentrySDK.currentHub getClient].options.debug == YES) {
        [SentryLog logWithMessage:@"Sending JSON -------------------------------"
                         andLevel:kSentryLevelDebug];
        [SentryLog logWithMessage:[NSString stringWithFormat:@"%@",
                                            [[NSString alloc] initWithData:jsonData
                                                                  encoding:NSUTF8StringEncoding]]
                         andLevel:kSentryLevelDebug];
        [SentryLog logWithMessage:@"--------------------------------------------"
                         andLevel:kSentryLevelDebug];
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

// TODO: Get refactored out to be a single init method
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

    // TODO: When the SDK inits, Client is created, then hub, then hub assigned
    // to SentrySDK. That means there's no hub set yet on SentrySDK when this
    // code runs (hub init closes pending sessions)
    if ([SentrySDK.currentHub getClient].options.debug == YES) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Envelope request with data: %@",
                                            [[NSString alloc] initWithData:data
                                                                  encoding:NSUTF8StringEncoding]]
                         andLevel:kSentryLevelDebug];
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
    [string
        appendFormat:@"%@,",
        newHeaderPart(@"sentry_timestamp", @((NSInteger)[[NSDate date] timeIntervalSince1970]))];
    [string appendFormat:@"%@", newHeaderPart(@"sentry_key", url.user)];
    if (nil != url.password) {
        [string appendFormat:@",%@", newHeaderPart(@"sentry_secret", url.password)];
    }
    return string;
}

@end

NS_ASSUME_NONNULL_END
