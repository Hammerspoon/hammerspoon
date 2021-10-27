#import <Foundation/Foundation.h>

#import "SentryScope.h"
#import "SentryScopeObserver.h"

@class SentryAttachment;

NS_ASSUME_NONNULL_BEGIN

@interface
SentryScope (Private)

@property (atomic, strong, readonly) NSArray<SentryAttachment *> *attachments;

@property (atomic, strong) SentryUser *_Nullable userObject;

- (void)addObserver:(id<SentryScopeObserver>)observer;

@end

NS_ASSUME_NONNULL_END
