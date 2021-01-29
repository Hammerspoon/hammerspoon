#import "SentryOptions.h"
#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryLog.h"
#import "SentryMeta.h"
#import "SentrySDK.h"
#import "SentrySdkInfo.h"

@implementation SentryOptions

+ (NSArray<NSString *> *)defaultIntegrations
{
    return @[
        @"SentryCrashIntegration", @"SentryAutoBreadcrumbTrackingIntegration",
        @"SentryAutoSessionTrackingIntegration"
    ];
}

- (instancetype)init
{
    if (self = [super init]) {
        self.enabled = YES;
        self.logLevel = kSentryLogLevelError;
        self.debug = NO;
        self.maxBreadcrumbs = defaultMaxBreadcrumbs;
        self.integrations = SentryOptions.defaultIntegrations;
        self.sampleRate = @1;
        self.enableAutoSessionTracking = YES;
        self.sessionTrackingIntervalMillis = [@30000 unsignedIntValue];
        self.attachStacktrace = YES;
        self.maxAttachmentSize = 20 * 1024 * 1024;
        _sdkInfo = [[SentrySdkInfo alloc] initWithName:SentryMeta.sdkName
                                            andVersion:SentryMeta.versionString];

        // Set default release name
        NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
        if (nil != infoDict) {
            self.releaseName =
                [NSString stringWithFormat:@"%@@%@+%@", infoDict[@"CFBundleIdentifier"],
                          infoDict[@"CFBundleShortVersionString"], infoDict[@"CFBundleVersion"]];
        }
    }
    return self;
}

- (_Nullable instancetype)initWithDict:(NSDictionary<NSString *, id> *)options
                      didFailWithError:(NSError *_Nullable *_Nullable)error
{
    if (self = [self init]) {
        [self validateOptions:options didFailWithError:error];
        if (nil != error && nil != *error) {
            [SentryLog
                logWithMessage:[NSString stringWithFormat:@"Failed to initialize: %@", *error]
                      andLevel:kSentryLogLevelError];
            return nil;
        }
    }
    return self;
}

- (void)setDsn:(NSString *)dsn
{
    NSError *error = nil;
    self.parsedDsn = [[SentryDsn alloc] initWithString:dsn didFailWithError:&error];

    if (nil == error) {
        _dsn = dsn;
    } else {
        NSString *errorMessage = [NSString stringWithFormat:@"Could not parse the DSN: %@.", error];
        [SentryLog logWithMessage:errorMessage andLevel:kSentryLogLevelError];
    }
}

/**
 populates all `SentryOptions` values from `options` dict using
 fallbacks/defaults if needed.
 */
- (void)validateOptions:(NSDictionary<NSString *, id> *)options
       didFailWithError:(NSError *_Nullable *_Nullable)error
{
    if (nil != options[@"debug"]) {
        self.debug = [options[@"debug"] boolValue];
    }

    if (self.debug) {
        // In other SDKs there's debug=true + diagnosticLevel where we can
        // control how chatty the SDK is. Ideally we'd support all the levels
        // here, and perhaps name it `diagnosticLevel` to align more.
        if ([@"verbose" isEqual:options[@"logLevel"]]) {
            _logLevel = kSentryLogLevelVerbose;
        } else {
            _logLevel = kSentryLogLevelDebug;
        }
    }

    NSString *dsn = @"";
    if (nil != [options valueForKey:@"dsn"] &&
        [[options valueForKey:@"dsn"] isKindOfClass:[NSString class]]) {
        dsn = [options valueForKey:@"dsn"];
    }

    self.parsedDsn = [[SentryDsn alloc] initWithString:dsn didFailWithError:error];

    if ([options[@"release"] isKindOfClass:[NSString class]]) {
        self.releaseName = options[@"release"];
    }

    if ([options[@"environment"] isKindOfClass:[NSString class]]) {
        self.environment = options[@"environment"];
    }

    if ([options[@"dist"] isKindOfClass:[NSString class]]) {
        self.dist = options[@"dist"];
    }

    if (nil != options[@"enabled"]) {
        self.enabled = [options[@"enabled"] boolValue];
    }

    if (nil != options[@"maxBreadcrumbs"]) {
        self.maxBreadcrumbs = [options[@"maxBreadcrumbs"] unsignedIntValue];
    }

    if (nil != options[@"beforeSend"]) {
        self.beforeSend = options[@"beforeSend"];
    }

    if (nil != options[@"beforeBreadcrumb"]) {
        self.beforeBreadcrumb = options[@"beforeBreadcrumb"];
    }

    if (nil != options[@"onCrashedLastRun"]) {
        self.onCrashedLastRun = options[@"onCrashedLastRun"];
    }

    if (nil != options[@"integrations"]) {
        self.integrations = options[@"integrations"];
    }

    NSNumber *sampleRate = options[@"sampleRate"];
    if (nil != sampleRate && [sampleRate floatValue] >= 0 && [sampleRate floatValue] <= 1.0) {
        self.sampleRate = sampleRate;
    }

    if (nil != options[@"enableAutoSessionTracking"]) {
        self.enableAutoSessionTracking = [options[@"enableAutoSessionTracking"] boolValue];
    }

    if (nil != options[@"sessionTrackingIntervalMillis"]) {
        self.sessionTrackingIntervalMillis =
            [options[@"sessionTrackingIntervalMillis"] unsignedIntValue];
    }

    if (nil != options[@"attachStacktrace"]) {
        self.attachStacktrace = [options[@"attachStacktrace"] boolValue];
    }

    if (nil != options[@"maxAttachmentSize"]) {
        self.maxAttachmentSize = [options[@"maxAttachmentSize"] unsignedIntValue];
    }
}

@end
