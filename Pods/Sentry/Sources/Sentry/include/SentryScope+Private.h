#import <Foundation/Foundation.h>

#import "SentryScope.h"

@class SentryAttachment;

NS_ASSUME_NONNULL_BEGIN

typedef void (^SentryScopeListener)(SentryScope *scope);

@interface SentryScope (Private)

@property (nonatomic, retain) NSMutableArray<SentryScopeListener> *listeners;

- (void)addScopeListener:(SentryScopeListener)listener;
- (void)notifyListeners;

@property (atomic, strong, readonly) NSArray<SentryAttachment *> *attachments;

@end

NS_ASSUME_NONNULL_END
