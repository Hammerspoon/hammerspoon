#import "SentryDefines.h"

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@interface SentryViewHierarchy : NSObject

- (nullable NSData *)fetchViewHierarchy;

- (BOOL)saveViewHierarchy:(NSString *)filePath;
@end

NS_ASSUME_NONNULL_END
#endif
