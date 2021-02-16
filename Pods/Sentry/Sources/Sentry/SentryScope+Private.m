#import "SentryScope+Private.h"
#import <objc/runtime.h>

@implementation SentryScope (Private)

@dynamic listeners, attachments;

- (NSMutableArray<SentryScopeListener> *)listeners
{
    return objc_getAssociatedObject(self, @selector(listeners));
}

- (void)setListeners:(NSMutableArray<SentryScopeListener> *)listeners
{
    objc_setAssociatedObject(
        self, @selector(listeners), listeners, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)addScopeListener:(SentryScopeListener)listener;
{
    [self.listeners addObject:listener];
}

- (void)notifyListeners
{
    for (SentryScopeListener listener in self.listeners) {
        listener(self);
    }
}

@end
