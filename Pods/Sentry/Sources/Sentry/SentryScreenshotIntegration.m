#import "SentryScreenshotIntegration.h"

#if SENTRY_HAS_UIKIT

#    import "SentryAttachment.h"
#    import "SentryCrashC.h"
#    import "SentryDependencyContainer.h"
#    import "SentryEvent+Private.h"
#    import "SentryException.h"
#    import "SentryHub+Private.h"
#    import "SentryOptions.h"
#    import "SentrySDK+Private.h"

#    if SENTRY_HAS_METRIC_KIT
#        import "SentryMetricKitIntegration.h"
#    endif // SENTRY_HAS_METRIC_KIT

void
saveScreenShot(const char *path)
{
    NSString *reportPath = [NSString stringWithUTF8String:path];
    [SentryDependencyContainer.sharedInstance.screenshot saveScreenShots:reportPath];
}

@interface
SentryScreenshotIntegration ()

@property (nonatomic, strong) SentryOptions *options;

@end

@implementation SentryScreenshotIntegration

- (BOOL)installWithOptions:(nonnull SentryOptions *)options
{
    self.options = options;

    if (![super installWithOptions:options]) {
        return NO;
    }

    SentryClient *client = [SentrySDK.currentHub getClient];
    [client addAttachmentProcessor:self];

    sentrycrash_setSaveScreenshots(&saveScreenShot);

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionAttachScreenshot;
}

- (void)uninstall
{
    sentrycrash_setSaveScreenshots(NULL);

    SentryClient *client = [SentrySDK.currentHub getClient];
    [client removeAttachmentProcessor:self];
}

- (NSArray<SentryAttachment *> *)processAttachments:(NSArray<SentryAttachment *> *)attachments
                                           forEvent:(nonnull SentryEvent *)event
{

    // We don't take screenshots if there is no exception/error.
    // We don't take screenshots if the event is a metric kit event.
    // Screenshots are added via an alternate codepath for crashes, see
    // sentrycrash_setSaveScreenshots in SentryCrashC.c
    if ((event.exceptions == nil && event.error == nil) || event.isCrashEvent
#    if SENTRY_HAS_METRIC_KIT
        || [event isMetricKitEvent]
#    endif // SENTRY_HAS_METRIC_KIT
    ) {
        return attachments;
    }

    // If the event is an App hanging event, we cant take the
    // screenshot because the the main thread it's blocked.
    if (event.isAppHangEvent) {
        return attachments;
    }

    if (self.options.beforeCaptureScreenshot && !self.options.beforeCaptureScreenshot(event)) {
        return attachments;
    }

    NSArray *screenshot =
        [SentryDependencyContainer.sharedInstance.screenshot appScreenshotsFromMainThread];

    NSMutableArray *result =
        [NSMutableArray arrayWithCapacity:attachments.count + screenshot.count];
    [result addObjectsFromArray:attachments];

    for (int i = 0; i < screenshot.count; i++) {
        NSString *name
            = i == 0 ? @"screenshot.png" : [NSString stringWithFormat:@"screenshot-%i.png", i + 1];

        SentryAttachment *att = [[SentryAttachment alloc] initWithData:screenshot[i]
                                                              filename:name
                                                           contentType:@"image/png"];
        [result addObject:att];
    }

    return result;
}

@end

#endif // SENTRY_HAS_UIKIT
