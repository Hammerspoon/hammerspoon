#import "SentryOptions.h"
#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryLog.h"
#import "SentrySDK.h"

@implementation SentryOptions

+ (NSArray<NSString *>*)defaultIntegrations {
    return @[
        @"SentryCrashIntegration",
        @"SentryUIKitMemoryWarningIntegration",
        @"SentryAutoBreadcrumbTrackingIntegration",
        @"SentryAutoSessionTrackingIntegration"
    ];
}

- (_Nullable instancetype)initWithDict:(NSDictionary<NSString *, id> *)options
                      didFailWithError:(NSError *_Nullable *_Nullable)error {
    self = [super init];
    if (self) {
        [self validateOptions:options didFailWithError:error];
        if (nil != error && nil != *error) {
            [SentryLog logWithMessage:[NSString stringWithFormat:@"Failed to initialize: %@", *error] andLevel:kSentryLogLevelError];
            return nil;
        }

        // If no user-defined release, use default.
        if (nil == self.releaseName) {
            NSDictionary *infoDict = [[NSBundle mainBundle] infoDictionary];
            if (nil != infoDict) {
                self.releaseName = [NSString stringWithFormat:@"%@@%@+%@",
                                    infoDict[@"CFBundleIdentifier"],
                                    infoDict[@"CFBundleShortVersionString"],
                                    infoDict[@"CFBundleVersion"]];
            }
        }
    }
    return self;
}

/**
 populates all `SentryOptions` values from `options` dict using fallbacks/defaults if needed.
 */
- (void)validateOptions:(NSDictionary<NSString *, id> *)options
       didFailWithError:(NSError *_Nullable *_Nullable)error {
    
    if (nil != [options objectForKey:@"debug"]) {
        self.debug = [NSNumber numberWithBool:[[options objectForKey:@"debug"] boolValue]];
    } else {
        self.debug = @NO;
    }

    if ([self.debug isEqual:@YES])  {
        // In other SDKs there's debug=true + diagnosticLevel where we can control how chatty the SDK is.
        // Ideally we'd support all the levels here, and perhaps name it `diagnosticLevel` to align more.
        if ([@"verbose" isEqual:[options objectForKey:@"logLevel"]]) {
            SentrySDK.logLevel = kSentryLogLevelVerbose;
            _logLevel = kSentryLogLevelVerbose;
        } else {
            SentrySDK.logLevel = kSentryLogLevelDebug;
            _logLevel = kSentryLogLevelDebug;
        }
    } else {
        SentrySDK.logLevel = kSentryLogLevelError;
        _logLevel = kSentryLogLevelError;
    }
    
    if (nil == [options valueForKey:@"dsn"] || ![[options valueForKey:@"dsn"] isKindOfClass:[NSString class]]) {
        self.enabled = @NO;
        [SentryLog logWithMessage:@"DSN is empty, will disable the SDK" andLevel:kSentryLogLevelDebug];
        return;
    }
    
    self.dsn = [[SentryDsn alloc] initWithString:[options valueForKey:@"dsn"] didFailWithError:error];
    if (nil != error && nil != *error) {
        self.enabled = @NO;
    }
    
    if ([[options objectForKey:@"release"] isKindOfClass:[NSString class]]) {
        self.releaseName = [options objectForKey:@"release"];
    }
    
    if ([[options objectForKey:@"environment"] isKindOfClass:[NSString class]]) {
        self.environment = [options objectForKey:@"environment"];
    }
    
    if ([[options objectForKey:@"dist"] isKindOfClass:[NSString class]]) {
        self.dist = [options objectForKey:@"dist"];
    }
    
    if (nil != [options objectForKey:@"enabled"]) {
        self.enabled = [NSNumber numberWithBool:[[options objectForKey:@"enabled"] boolValue]];
    } else {
        self.enabled = @YES;
    }

    if (nil != [options objectForKey:@"maxBreadcrumbs"]) {
        self.maxBreadcrumbs = [[options objectForKey:@"maxBreadcrumbs"] unsignedIntValue];
    } else {
        // fallback value
        self.maxBreadcrumbs = defaultMaxBreadcrumbs;
    }

    if (nil != [options objectForKey:@"beforeSend"]) {
        self.beforeSend = [options objectForKey:@"beforeSend"];
    }

    if (nil != [options objectForKey:@"beforeBreadcrumb"]) {
        self.beforeBreadcrumb = [options objectForKey:@"beforeBreadcrumb"];
    }

    if (nil != [options objectForKey:@"integrations"]) {
        self.integrations = [options objectForKey:@"integrations"];
    } else {
        // fallback to defaultIntegrations
        self.integrations = [SentryOptions defaultIntegrations];
    }

    NSNumber *sampleRate = [options objectForKey:@"sampleRate"];
    if (nil == sampleRate || [sampleRate floatValue] < 0 || [sampleRate floatValue] > 1.0) {
        self.sampleRate = @1;
    } else {
        self.sampleRate = sampleRate;
    }

    if (nil != [options objectForKey:@"enableAutoSessionTracking"]) {
        self.enableAutoSessionTracking = [NSNumber numberWithBool:[[options objectForKey:@"enableAutoSessionTracking"] boolValue]];
    } else {
        self.enableAutoSessionTracking = @NO; // TODO: Opt-out?
    }

    if (nil != [options objectForKey:@"sessionTrackingIntervalMillis"]) {
        self.sessionTrackingIntervalMillis = [[options objectForKey:@"sessionTrackingIntervalMillis"] unsignedIntValue];
    } else {
        self.sessionTrackingIntervalMillis = [@30000 unsignedIntValue];
    }
}

@end
