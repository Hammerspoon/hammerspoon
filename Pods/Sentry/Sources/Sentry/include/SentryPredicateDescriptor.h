#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Used to transform an NSPredicate into a human-friendly string.
 * This class is used for CoreData and omits variable values
 * and doesn't convert CoreData unsupported instructions.
 */
@interface SentryPredicateDescriptor : NSObject

- (NSString *)predicateDescription:(NSPredicate *)predicate;

@end

NS_ASSUME_NONNULL_END
