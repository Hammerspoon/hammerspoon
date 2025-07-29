#import "SentryWeakMap.h"

@interface SentryWeakBox : NSObject <NSCopying>

@property (nonatomic, weak, readonly) id key;

- (instancetype)initWithKey:(id)key;

@end

@implementation SentryWeakBox {
    __weak id _key;
    NSUInteger _hash;
}

- (instancetype)initWithKey:(id)key
{
    if (self = [super init]) {
        _key = key;
        // We need to cache the hash value because weak keys can be deallocated.
        // This hash is used to identify the weak box by the wrapped key in the storage.
        _hash = [key hash];
    }
    return self;
}

- (id)key
{
    return _key;
}

- (NSUInteger)hash
{
    return _hash;
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[SentryWeakBox class]]) {
        return NO;
    }
    id selfKey = self.key;
    id otherKey = ((SentryWeakBox *)object).key;
    return selfKey && otherKey && [selfKey isEqual:otherKey];
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone
{
    return [[[SentryWeakBox class] allocWithZone:zone] initWithKey:self.key];
}

@end

@interface SentryWeakMap <KeyType, ObjectType>()
@property (nonatomic, strong) NSMutableDictionary<SentryWeakBox *, id> *storage;
@end

@implementation SentryWeakMap

// This class was originally a wrapper around NSMapTable with weak keys.
// Due to undeterministic behavior of NSMapTable, we had to implement our own weak key storage.

- (instancetype)init
{
    if (self = [super init]) {
        _storage = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)setObject:(nullable id)anObject forKey:(nullable id)aKey
{
    if (!aKey || !anObject) {
        return;
    }

    [self prune];

    SentryWeakBox *box = [[SentryWeakBox alloc] initWithKey:aKey];
    self.storage[box] = anObject;
}

- (nullable id)objectForKey:(nullable id)aKey
{
    if (!aKey) {
        return nil;
    }

    [self prune];

    SentryWeakBox *box = [[SentryWeakBox alloc] initWithKey:aKey];
    return self.storage[box];
}

- (void)removeObjectForKey:(nullable id)aKey
{
    if (!aKey) {
        return;
    }

    [self prune];

    SentryWeakBox *box = [[SentryWeakBox alloc] initWithKey:aKey];
    [self.storage removeObjectForKey:box];
}

- (NSUInteger)count
{
    // Do not prune here, to make this method a direct proxy for the underlying dictionary.
    return self.storage.count;
}

- (void)prune
{
    NSMutableArray *keysToRemove = [NSMutableArray array];
    for (SentryWeakBox *box in self.storage.keyEnumerator) {
        if (box.key == nil) {
            [keysToRemove addObject:box];
        }
    }
    [self.storage removeObjectsForKeys:keysToRemove];
}

@end
