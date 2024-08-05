#import "SentryViewHierarchyIntegration.h"

#if SENTRY_HAS_UIKIT
#    import "SentryAttachment+Private.h"
#    import "SentryCrashC.h"
#    import "SentryDependencyContainer.h"
#    import "SentryEvent+Private.h"
#    import "SentryException.h"
#    import "SentryHub+Private.h"
#    import "SentrySDK+Private.h"
#    import "SentryViewHierarchy.h"
#    if SENTRY_HAS_METRIC_KIT
#        import "SentryMetricKitIntegration.h"
#    endif // SENTRY_HAS_METRIC_KIT

/**
 * Function to call through to the ObjC method to save a view hierarchy, which can be passed around
 * as a function pointer in the C crash reporting code.
 * @param reportDirectoryPath The path to the directory containing crash reporting files, in which a
 * new file will be created to store the view hierarchy description.
 */
void
saveViewHierarchy(const char *reportDirectoryPath)
{
    NSString *reportPath = [[NSString stringWithUTF8String:reportDirectoryPath]
        stringByAppendingPathComponent:@"view-hierarchy.json"];
    [SentryDependencyContainer.sharedInstance.viewHierarchy saveViewHierarchy:reportPath];
}

@implementation SentryViewHierarchyIntegration

- (BOOL)installWithOptions:(nonnull SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    SentryClient *client = [SentrySDK.currentHub getClient];
    [client addAttachmentProcessor:self];

    sentrycrash_setSaveViewHierarchy(&saveViewHierarchy);

    return YES;
}

- (SentryIntegrationOption)integrationOptions
{
    return kIntegrationOptionAttachViewHierarchy;
}

- (void)uninstall
{
    sentrycrash_setSaveViewHierarchy(NULL);

    SentryClient *client = [SentrySDK.currentHub getClient];
    [client removeAttachmentProcessor:self];
}

- (NSArray<SentryAttachment *> *)processAttachments:(NSArray<SentryAttachment *> *)attachments
                                           forEvent:(nonnull SentryEvent *)event
{
    // We don't attach the view hierarchy if there is no exception/error.
    // We don't attach the view hierarchy if the event is a crash or metric kit event.
    if ((event.exceptions == nil && event.error == nil) || event.isCrashEvent
#    if SENTRY_HAS_METRIC_KIT
        || [event isMetricKitEvent]
#    endif // SENTRY_HAS_METRIC_KIT
    ) {
        return attachments;
    }

    // If the event is an App hanging event, we cant take the
    // view hierarchy because the main thread it's blocked.
    if (event.isAppHangEvent) {
        return attachments;
    }

    NSMutableArray<SentryAttachment *> *result = [NSMutableArray arrayWithArray:attachments];

    NSData *viewHierarchy =
        [SentryDependencyContainer.sharedInstance.viewHierarchy appViewHierarchyFromMainThread];

    SentryAttachment *attachment =
        [[SentryAttachment alloc] initWithData:viewHierarchy
                                      filename:@"view-hierarchy.json"
                                   contentType:@"application/json"
                                attachmentType:kSentryAttachmentTypeViewHierarchy];

    [result addObject:attachment];
    return result;
}

@end
#endif
