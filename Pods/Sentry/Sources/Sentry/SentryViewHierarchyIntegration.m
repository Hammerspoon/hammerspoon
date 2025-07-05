#import "SentryViewHierarchyIntegration.h"

#if SENTRY_HAS_UIKIT
#    import "SentryAttachment+Private.h"
#    import "SentryCrashC.h"
#    import "SentryDependencyContainer.h"
#    import "SentryEvent+Private.h"
#    import "SentryException.h"
#    import "SentryHub+Private.h"
#    import "SentryOptions.h"
#    import "SentrySDK+Private.h"
#    import "SentryViewHierarchyProvider.h"
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
    [SentryDependencyContainer.sharedInstance.viewHierarchyProvider saveViewHierarchy:reportPath];
}

@interface SentryViewHierarchyIntegration ()

@property (nonatomic, strong) SentryOptions *options;

@end

@implementation SentryViewHierarchyIntegration

- (BOOL)installWithOptions:(nonnull SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    self.options = options;

    SentryClient *client = [SentrySDK.currentHub getClient];
    [client addAttachmentProcessor:self];

    sentrycrash_setSaveViewHierarchy(&saveViewHierarchy);

    SentryDependencyContainer.sharedInstance.viewHierarchyProvider.reportAccessibilityIdentifier
        = options.reportAccessibilityIdentifier;
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

- (nonnull NSArray<SentryAttachment *> *)processAttachments:
                                             (nonnull NSArray<SentryAttachment *> *)attachments
                                                   forEvent:(nonnull SentryEvent *)event
{
    // We don't attach the view hierarchy if there is no exception/error.
    // We don't attach the view hierarchy if the event is a crash or metric kit event.
    if ((event.exceptions == nil && event.error == nil) || event.isFatalEvent
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

    if (self.options.beforeCaptureViewHierarchy
        && !self.options.beforeCaptureViewHierarchy(event)) {
        return attachments;
    }

    NSMutableArray<SentryAttachment *> *result = [NSMutableArray arrayWithArray:attachments];

    NSData *viewHierarchy = [SentryDependencyContainer.sharedInstance
            .viewHierarchyProvider appViewHierarchyFromMainThread];

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
