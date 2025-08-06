#import <Foundation/Foundation.h>

#import "SentryScope.h"
#import "SentryScopeObserver.h"

@class SentryAttachment;
@class SentryPropagationContext;
@class SentrySession;

NS_ASSUME_NONNULL_BEGIN

@interface SentryScope ()

@property (atomic, copy, nullable) NSString *environmentString;

@property (atomic, strong, readonly) NSArray<SentryAttachment *> *attachments;

/**
 * Set global user -> thus will be sent with every event
 */
@property (atomic, strong) SentryUser *_Nullable userObject;

/**
 * The propagation context has a setter, requiring it to be nonatomic
 */
@property (nonatomic, strong) SentryPropagationContext *propagationContext;

@property (nonatomic, nullable, copy) NSString *currentScreen;

- (NSArray<SentryBreadcrumb *> *)breadcrumbs;

/**
 * used to add values in event context.
 */
@property (atomic, strong)
    NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *contextDictionary;

- (void)addObserver:(id<SentryScopeObserver>)observer;

- (nullable SentryEvent *)applyToEvent:(SentryEvent *)event
                         maxBreadcrumb:(NSUInteger)maxBreadcrumbs
    NS_SWIFT_NAME(applyTo(event:maxBreadcrumbs:));

- (void)applyToSession:(SentrySession *)session NS_SWIFT_NAME(applyTo(session:));

- (void)addCrashReportAttachmentInPath:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END
