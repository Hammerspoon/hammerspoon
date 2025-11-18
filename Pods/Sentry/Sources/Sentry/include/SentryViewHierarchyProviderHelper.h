#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

@class UIWindow;

NS_ASSUME_NONNULL_BEGIN

@interface SentryViewHierarchyProviderHelper : NSObject

/**
 * Get the view hierarchy in a json format.
 *
 * @param windows The app windows.
 * @param reportAccessibilityIdentifier Whether or not to report accessibility identifiers.
 */
+ (nullable NSData *)appViewHierarchyFrom:(NSArray<UIWindow *> *)windows
            reportAccessibilityIdentifier:(BOOL)reportAccessibilityIdentifier;

/**
 * Save the current app view hierarchy in the given file path.
 *
 * @param filePath The full path where the view hierarchy should be saved.
 * @param windows The app windows.
 * @param reportAccessibilityIdentifier Whether or not to report accessibility identifiers.
 */
+ (BOOL)saveViewHierarchy:(NSString *)filePath
                          windows:(NSArray<UIWindow *> *)windows
    reportAccessibilityIdentifier:(BOOL)reportAccessibilityIdentifier;
@end

NS_ASSUME_NONNULL_END
#endif
