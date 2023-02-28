#import "UIView+Sentry.h"

#if SENTRY_HAS_UIKIT

@implementation
UIView (Sentry)

- (NSString *)sentry_recursiveViewHierarchyDescription
{
    NSMutableString *mutableString = @"".mutableCopy;

    [self sentry_recursiveViewHierarchyDescriptionWithLevel:0 into:mutableString];

    return mutableString.copy;
}

- (void)sentry_recursiveViewHierarchyDescriptionWithLevel:(NSInteger)level
                                                     into:(NSMutableString *)mutableString
{
    for (int i = 0; i < level; i++) {
        [mutableString appendString:@"   | "];
    }

    [mutableString appendString:[self description]];
    [mutableString appendString:@"\n"];

    for (UIView *subview in self.subviews) {
        [subview sentry_recursiveViewHierarchyDescriptionWithLevel:level + 1 into:mutableString];
    }
}

@end

#endif
