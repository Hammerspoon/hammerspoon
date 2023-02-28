#import <Foundation/Foundation.h>

#import "SentryScope.h"
#import "SentryScopeObserver.h"

@class SentryAttachment;

NS_ASSUME_NONNULL_BEGIN

@interface
SentryScope (Private)

@property (atomic, copy, readonly, nullable) NSString *environmentString;

@property (atomic, strong, readonly) NSArray<SentryAttachment *> *attachments;

@property (atomic, strong) SentryUser *_Nullable userObject;

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
