#import "SentryBinaryImageCacheCallbacks.h"
#import "SentryDependencyContainer.h"
#import "SentryInternalDefines.h"
#import "SentrySwift.h"

// Used to call SentryDependencyContainer, since it isn't available to swift yet
void
binaryImageWasAdded(const SentryCrashBinaryImage *_Nullable image)
{
    if (image == NULL) {
        SENTRY_LOG_WARN(@"The image is NULL. Can't add NULL to cache.");
        return;
    }
    [SentryDependencyContainer.sharedInstance.binaryImageCache binaryImageAdded:image->name
                                                                      vmAddress:image->vmAddress
                                                                        address:image->address
                                                                           size:image->size
                                                                           uuid:image->uuid];
}

// Used to call SentryDependencyContainer, since it isn't available to swift yet
void
binaryImageWasRemoved(const SentryCrashBinaryImage *_Nullable image)
{
    if (image == NULL) {
        SENTRY_LOG_WARN(@"The image is NULL. Can't remove it from the cache.");
        return;
    }
    [SentryDependencyContainer.sharedInstance.binaryImageCache binaryImageRemoved:image->address];
}
