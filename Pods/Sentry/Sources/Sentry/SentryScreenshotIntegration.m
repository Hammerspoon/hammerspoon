#import "SentryScreenshotIntegration.h"
#import "SentryAttachment.h"
#import "SentryCrashC.h"
#import "SentryDependencyContainer.h"
#import "SentryEvent+Private.h"
#import "SentryHub+Private.h"
#import "SentryMetricKitIntegration.h"
#import "SentrySDK+Private.h"

#if SENTRY_HAS_UIKIT

void
saveScreenShot(const char *path)
{
    NSString *reportPath = [NSString stringWithUTF8String:path];
    [SentryDependencyContainer.sharedInstance.screenshot saveScreenShots:reportPath];
}

@implementation SentryScreenshotIntegration

- (BOOL)installWithOptions:(nonnull SentryOptions *)options
{
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
    // We don't take screenshots if the event is a crash or metric kit event.
    if ((event.exceptions == nil && event.error == nil) || event.isCrashEvent
        || event.isMetricKitEvent) {
        return attachments;
    }

    NSArray *screenshot = [SentryDependencyContainer.sharedInstance.screenshot appScreenshots];

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
#endif
