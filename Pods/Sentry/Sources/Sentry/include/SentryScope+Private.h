#import <Foundation/Foundation.h>

#import "SentryScope.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^SentryScopeListener)(SentryScope *scope);

@interface SentryScope (Private)

@property (nonatomic, retain) NSMutableArray<SentryScopeListener> *listeners;

- (void)addScopeListener:(SentryScopeListener)listener;
- (void)notifyListeners;

@end

NS_ASSUME_NONNULL_END
