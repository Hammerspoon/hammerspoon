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

/**
 * This distribution of the application.
 */
@property (atomic, copy) NSString *_Nullable distString;

/**
 * Set global extra -> these will be sent with every event
 */
@property (atomic, strong) NSMutableDictionary<NSString *, id> *extraDictionary;

/**
 * Set the fingerprint of an event to determine the grouping
 */
@property (atomic, strong) NSMutableArray<NSString *> *fingerprintArray;

/**
 * SentryLevel of the event
 */
@property (atomic) enum SentryLevel levelEnum;

@property (nonatomic, nullable, copy) NSString *currentScreen;

- (NSArray<SentryBreadcrumb *> *)breadcrumbs;

/**
 * used to add values in event context.
 */
@property (atomic, strong)
    NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *contextDictionary;

/**
 * Set global tags -> these will be sent with every event
 */
@property (atomic, strong) NSMutableDictionary<NSString *, NSString *> *tagDictionary;

- (void)addObserver:(id<SentryScopeObserver>)observer;

- (nullable SentryEvent *)applyToEvent:(SentryEvent *)event
                         maxBreadcrumb:(NSUInteger)maxBreadcrumbs
    NS_SWIFT_NAME(applyTo(event:maxBreadcrumbs:));

- (void)applyToSession:(SentrySession *)session NS_SWIFT_NAME(applyTo(session:));

- (void)addCrashReportAttachmentInPath:(NSString *)filePath;

@end

NS_ASSUME_NONNULL_END
