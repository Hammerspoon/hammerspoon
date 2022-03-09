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
@property (nonatomic, strong) NSMutableSet<NSString *> *disabledIntegrations;

@end

@implementation SentryOptions

+ (NSArray<NSString *> *)defaultIntegrations
{
    return @[
        @"SentryCrashIntegration", @"SentryFramesTrackingIntegration",
        @"SentryAutoBreadcrumbTrackingIntegration", @"SentryAutoSessionTrackingIntegration",
        @"SentryAppStartTrackingIntegration", @"SentryOutOfMemoryTrackingIntegration",
        @"SentryPerformanceTrackingIntegration", @"SentryNetworkTrackingIntegration",
        @"SentryFileIOTrackingIntegration"
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
        self.disabledIntegrations = [NSMutableSet new];
        _defaultSampleRate = @1;
        self.sampleRate = _defaultSampleRate;
        self.enableAutoSessionTracking = YES;
        self.enableOutOfMemoryTracking = YES;
        self.sessionTrackingIntervalMillis = [@30000 unsignedIntValue];
        self.attachStacktrace = YES;
        self.stitchAsyncCode = NO;
        self.maxAttachmentSize = 20 * 1024 * 1024;
        self.sendDefaultPii = NO;
        self.enableAutoPerformanceTracking = YES;
        self.enableNetworkTracking = YES;
        self.enableFileIOTracking = NO;
        self.enableNetworkBreadcrumbs = YES;
        _defaultTracesSampleRate = nil;
        self.tracesSampleRate = _defaultTracesSampleRate;
        _experimentalEnableTraceSampling = NO;
        _enableSwizzling = YES;

        // Use the name of the bundle’s executable file as inAppInclude, so SentryInAppLogic
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
        if (![self validateOptions:options didFailWithError:error]) {
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
- (BOOL)validateOptions:(NSDictionary<NSString *, id> *)options
       didFailWithError:(NSError *_Nullable *_Nullable)error
{
    NSPredicate *isNSString = [NSPredicate predicateWithBlock:^BOOL(
        id object, NSDictionary *bindings) { return [object isKindOfClass:[NSString class]]; }];

    [self setBool:options[@"debug"] block:^(BOOL value) { self->_debug = value; }];

    if ([options[@"diagnosticLevel"] isKindOfClass:[NSString class]]) {
        for (SentryLevel level = 0; level <= kSentryLevelFatal; level++) {
            if ([SentryLevelNames[level] isEqualToString:options[@"diagnosticLevel"]]) {
                self.diagnosticLevel = level;
                break;
            }
        }
    }

    NSString *dsn = @"";
    if (nil != options[@"dsn"] && [options[@"dsn"] isKindOfClass:[NSString class]]) {
        dsn = options[@"dsn"];
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

    [self setBool:options[@"enabled"] block:^(BOOL value) { self->_enabled = value; }];

    if ([options[@"maxBreadcrumbs"] isKindOfClass:[NSNumber class]]) {
        self.maxBreadcrumbs = [options[@"maxBreadcrumbs"] unsignedIntValue];
    }

    [self setBool:options[@"enableNetworkBreadcrumbs"]
            block:^(BOOL value) { self->_enableNetworkBreadcrumbs = value; }];

    if ([options[@"maxCacheItems"] isKindOfClass:[NSNumber class]]) {
        self.maxCacheItems = [options[@"maxCacheItems"] unsignedIntValue];
    }

    if ([self isBlock:options[@"beforeSend"]]) {
        self.beforeSend = options[@"beforeSend"];
    }

    if ([self isBlock:options[@"beforeBreadcrumb"]]) {
        self.beforeBreadcrumb = options[@"beforeBreadcrumb"];
    }

    if ([self isBlock:options[@"onCrashedLastRun"]]) {
        self.onCrashedLastRun = options[@"onCrashedLastRun"];
    }

    if ([options[@"integrations"] isKindOfClass:[NSArray class]]) {
        self.integrations = [options[@"integrations"] filteredArrayUsingPredicate:isNSString];
    }

    if ([options[@"sampleRate"] isKindOfClass:[NSNumber class]]) {
        self.sampleRate = options[@"sampleRate"];
    }

    [self setBool:options[@"enableAutoSessionTracking"]
            block:^(BOOL value) { self->_enableAutoSessionTracking = value; }];

    [self setBool:options[@"enableOutOfMemoryTracking"]
            block:^(BOOL value) { self->_enableOutOfMemoryTracking = value; }];

    if ([options[@"sessionTrackingIntervalMillis"] isKindOfClass:[NSNumber class]]) {
        self.sessionTrackingIntervalMillis =
            [options[@"sessionTrackingIntervalMillis"] unsignedIntValue];
    }

    [self setBool:options[@"attachStacktrace"]
            block:^(BOOL value) { self->_attachStacktrace = value; }];

    [self setBool:options[@"stitchAsyncCode"]
            block:^(BOOL value) { self->_stitchAsyncCode = value; }];

    if ([options[@"maxAttachmentSize"] isKindOfClass:[NSNumber class]]) {
        self.maxAttachmentSize = [options[@"maxAttachmentSize"] unsignedIntValue];
    }

    [self setBool:options[@"sendDefaultPii"]
            block:^(BOOL value) { self->_sendDefaultPii = value; }];

    [self setBool:options[@"enableAutoPerformanceTracking"]
            block:^(BOOL value) { self->_enableAutoPerformanceTracking = value; }];

    [self setBool:options[@"enableNetworkTracking"]
            block:^(BOOL value) { self->_enableNetworkTracking = value; }];

    [self setBool:options[@"enableFileIOTracking"]
            block:^(BOOL value) { self->_enableFileIOTracking = value; }];

    if ([options[@"tracesSampleRate"] isKindOfClass:[NSNumber class]]) {
        self.tracesSampleRate = options[@"tracesSampleRate"];
    }

    if ([self isBlock:options[@"tracesSampler"]]) {
        self.tracesSampler = options[@"tracesSampler"];
    }

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

    [self setBool:options[@"experimentalEnableTraceSampling"]
            block:^(BOOL value) { self->_experimentalEnableTraceSampling = value; }];

    [self setBool:options[@"enableSwizzling"]
            block:^(BOOL value) { self->_enableSwizzling = value; }];

    if (nil != error && nil != *error) {
        return NO;
    } else {
        return YES;
    }
}

- (void)setBool:(id)value block:(void (^)(BOOL))block
{
    // Entries in the dictionary can be NSNull. Especially, on React-Native, this can happen.
    if (value != nil && ![value isEqual:[NSNull null]]) {
        block([value boolValue]);
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

- (BOOL)isTracingEnabled
{
    return (_tracesSampleRate != nil && [_tracesSampleRate doubleValue] > 0)
        || _tracesSampler != nil;
}

/**
 * Checks if the passed in block is actually of type block. We can't check if the block matches a
 * specific block without some complex objc runtime method calls and therefore we only check if its
 * a block or not. Assigning a wrong block to the SentryOption blocks still could lead to crashes at
 * runtime, but when someone uses the initWithDict they should better know what they are doing.
 *
 * Taken from https://gist.github.com/steipete/6ee378bd7d87f276f6e0
 */
- (BOOL)isBlock:(nullable id)block
{
    static Class blockClass;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        blockClass = [^{} class];
        while ([blockClass superclass] != NSObject.class) {
            blockClass = [blockClass superclass];
        }
    });

    return [block isKindOfClass:blockClass];
}

- (NSSet<NSString *> *)enabledIntegrations
{
    NSMutableSet<NSString *> *enabledIntegrations =
        [[NSMutableSet alloc] initWithArray:self.integrations];
    for (NSString *integration in self.disabledIntegrations) {
        [enabledIntegrations removeObject:integration];
    }
    return enabledIntegrations;
}

- (void)removeEnabledIntegration:(NSString *)integration
{
    [self.disabledIntegrations addObject:integration];
}

@end
