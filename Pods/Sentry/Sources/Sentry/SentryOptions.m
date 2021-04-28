#import "SentryOptions.h"
#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryLog.h"
#import "SentryMeta.h"
#import "SentrySDK.h"
#import "SentrySdkInfo.h"

@interface
SentryOptions ()

@property (nullable, nonatomic, copy, readonly) NSNumber *defaultSampleRate;
@property (nullable, nonatomic, copy, readonly) NSNumber *defaultTracesSampleRate;

@end

@implementation SentryOptions

+ (NSArray<NSString *> *)defaultIntegrations
{
    return @[
        @"SentryCrashIntegration", @"SentryAutoBreadcrumbTrackingIntegration",
        @"SentryAutoSessionTrackingIntegration", @"SentryOutOfMemoryTrackingIntegration"
    ];
}

- (instancetype)init
{
    if (self = [super init]) {
        self.enabled = YES;
        self.diagnosticLevel = kSentryLevelDebug;
        self.debug = NO;
        self.maxBreadcrumbs = defaultMaxBreadcrumbs;
        self.maxCacheItems = 30;
        self.integrations = SentryOptions.defaultIntegrations;
        _defaultSampleRate = @1;
        self.sampleRate = _defaultSampleRate;
        self.enableAutoSessionTracking = YES;
        self.enableOutOfMemoryTracking = YES;
        self.sessionTrackingIntervalMillis = [@30000 unsignedIntValue];
        self.attachStacktrace = YES;
        self.maxAttachmentSize = 20 * 1024 * 1024;
        self.sendDefaultPii = NO;
        _defaultTracesSampleRate = nil;
        self.tracesSampleRate = _defaultTracesSampleRate;

        // Use the name of the bundle’s executable file as inAppInclude, so SentryFrameInAppLogic
        // marks frames coming from there as inApp. With this approach, the SDK marks public
        // frameworks such as UIKitCore, CoreFoundation, GraphicsServices, and so forth, as not
        // inApp. For private frameworks, such as Sentry, dynamic and static frameworks differ.
        // Suppose you use dynamic frameworks inside your app. In that case, the SDK marks these as
        // not inApp as these frameworks are located in the application bundle, but their location
        // is different from the main executable.  In case you have a private framework that should
        // be inApp you can add it to inAppInclude. When using static frameworks, the frameworks end
        // up in the main executable. Therefore, the SDK currently can't detect if a frame of the
        // main executable originates from the application or a private framework and marks all of
        // them as inApp. To fix this, the user can use stack trace rules on Sentry.
        NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
        NSString *bundleExecutable = infoDict[@"CFBundleExecutable"];
        if (nil == bundleExecutable) {
            _inAppIncludes = [NSArray new];
        } else {
            _inAppIncludes = @[ bundleExecutable ];
        }

        _inAppExcludes = [NSArray new];
        _sdkInfo = [[SentrySdkInfo alloc] initWithName:SentryMeta.sdkName
                                            andVersion:SentryMeta.versionString];

        // Set default release name
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
                      andLevel:kSentryLevelError];
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
        [SentryLog logWithMessage:errorMessage andLevel:kSentryLevelError];
    }
}

/**
 * Populates all `SentryOptions` values from `options` dict using fallbacks/defaults if needed.
 */
- (void)validateOptions:(NSDictionary<NSString *, id> *)options
       didFailWithError:(NSError *_Nullable *_Nullable)error
{
    if (nil != options[@"debug"]) {
        self.debug = [options[@"debug"] boolValue];
    }

    if ([options[@"diagnosticLevel"] isKindOfClass:[NSString class]]) {
        for (SentryLevel level = 0; level <= kSentryLevelFatal; level++) {
            if ([SentryLevelNames[level] isEqualToString:options[@"diagnosticLevel"]]) {
                self.diagnosticLevel = level;
                break;
            }
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

    if ([options[@"maxBreadcrumbs"] isKindOfClass:[NSNumber class]]) {
        self.maxBreadcrumbs = [options[@"maxBreadcrumbs"] unsignedIntValue];
    }

    if ([options[@"maxCacheItems"] isKindOfClass:[NSNumber class]]) {
        self.maxCacheItems = [options[@"maxCacheItems"] unsignedIntValue];
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
    if (nil != sampleRate) {
        self.sampleRate = sampleRate;
    }

    if (nil != options[@"enableAutoSessionTracking"]) {
        self.enableAutoSessionTracking = [options[@"enableAutoSessionTracking"] boolValue];
    }

    if (nil != options[@"enableOutOfMemoryTracking"]) {
        self.enableOutOfMemoryTracking = [options[@"enableOutOfMemoryTracking"] boolValue];
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

    if (nil != options[@"sendDefaultPii"]) {
        self.sendDefaultPii = [options[@"sendDefaultPii"] boolValue];
    }

    NSNumber *tracesSampleRate = options[@"tracesSampleRate"];
    if (nil != tracesSampleRate) {
        self.tracesSampleRate = tracesSampleRate;
    }

    if (nil != options[@"tracesSampler"]) {
        self.tracesSampler = options[@"tracesSampler"];
    }

    NSPredicate *isNSString = [NSPredicate predicateWithBlock:^BOOL(
        id object, NSDictionary *bindings) { return [object isKindOfClass:[NSString class]]; }];

    if ([options[@"inAppIncludes"] isKindOfClass:[NSArray class]]) {
        NSArray<NSString *> *inAppIncludes =
            [options[@"inAppIncludes"] filteredArrayUsingPredicate:isNSString];
        _inAppIncludes = [_inAppIncludes arrayByAddingObjectsFromArray:inAppIncludes];
    }

    if ([options[@"inAppExcludes"] isKindOfClass:[NSArray class]]) {
        _inAppExcludes = [options[@"inAppExcludes"] filteredArrayUsingPredicate:isNSString];
    }

    if ([options[@"urlSessionDelegate"] conformsToProtocol:@protocol(NSURLSessionDelegate)]) {
        self.urlSessionDelegate = options[@"urlSessionDelegate"];
    }
}

- (void)addInAppInclude:(NSString *)inAppInclude
{
    _inAppIncludes = [self.inAppIncludes arrayByAddingObject:inAppInclude];
}

- (void)addInAppExclude:(NSString *)inAppExclude
{
    _inAppExcludes = [self.inAppExcludes arrayByAddingObject:inAppExclude];
}

- (void)setSampleRate:(NSNumber *)sampleRate
{
    if (sampleRate == nil) {
        _sampleRate = nil;
    } else if ([self isValidSampleRate:sampleRate]) {
        _sampleRate = sampleRate;
    } else {
        _sampleRate = _defaultSampleRate;
    }
}

- (BOOL)isValidSampleRate:(NSNumber *)sampleRate
{
    // Same valid range, so we can reuse the logic.
    return [self isValidTracesSampleRate:sampleRate];
}

- (void)setTracesSampleRate:(NSNumber *)tracesSampleRate
{
    if (tracesSampleRate == nil) {
        _tracesSampleRate = nil;
    } else if ([self isValidTracesSampleRate:tracesSampleRate]) {
        _tracesSampleRate = tracesSampleRate;
    } else {
        _tracesSampleRate = _defaultTracesSampleRate;
    }
}

- (BOOL)isValidTracesSampleRate:(NSNumber *)tracesSampleRate
{
    double rate = [tracesSampleRate doubleValue];
    return rate >= 0 && rate <= 1.0;
}

@end
