#import "SentryViewHierarchyIntegration.h"
#import "SentryAttachment+Private.h"
#import "SentryCrashC.h"
#import "SentryDependencyContainer.h"
#import "SentryEvent+Private.h"
#import "SentryHub+Private.h"
#import "SentryMetricKitIntegration.h"
#import "SentrySDK+Private.h"
#import "SentryViewHierarchy.h"

#if SENTRY_HAS_UIKIT

void
saveViewHierarchy(const char *path)
{
    NSString *reportPath = [NSString stringWithUTF8String:path];
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
        || event.isMetricKitEvent) {
        return attachments;
    }

    NSMutableArray<SentryAttachment *> *result = [NSMutableArray arrayWithArray:attachments];

    NSData *viewHierarchy =
        [SentryDependencyContainer.sharedInstance.viewHierarchy fetchViewHierarchy];
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
