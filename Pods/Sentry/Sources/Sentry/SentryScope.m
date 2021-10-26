#import "SentryScope.h"
#import "SentryAttachment.h"
#import "SentryBreadcrumb.h"
#import "SentryEnvelopeItemType.h"
#import "SentryEvent.h"
#import "SentryGlobalEventProcessor.h"
#import "SentryLog.h"
#import "SentryScopeObserver.h"
#import "SentrySession.h"
#import "SentrySpan.h"
#import "SentryTracer.h"
#import "SentryUser.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryScope ()

/**
 * Set global user -> thus will be sent with every event
 */
@property (atomic, strong) SentryUser *_Nullable userObject;

/**
 * Set global tags -> these will be sent with every event
 */
@property (atomic, strong) NSMutableDictionary<NSString *, NSString *> *tagDictionary;

/**
 * Set global extra -> these will be sent with every event
 */
@property (atomic, strong) NSMutableDictionary<NSString *, id> *extraDictionary;

/**
 * used to add values in event context.
 */
@property (atomic, strong)
    NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *contextDictionary;

/**
 * Contains the breadcrumbs which will be sent with the event
 */
@property (atomic, strong) NSMutableArray<SentryBreadcrumb *> *breadcrumbArray;

/**
 * This distribution of the application.
 */
@property (atomic, copy) NSString *_Nullable distString;

/**
 * The environment used in this scope.
 */
@property (atomic, copy) NSString *_Nullable environmentString;

/**
 * Set the fingerprint of an event to determine the grouping
 */
@property (atomic, strong) NSMutableArray<NSString *> *fingerprintArray;

/**
 * SentryLevel of the event
 */
@property (atomic) enum SentryLevel levelEnum;

@property (atomic) NSInteger maxBreadcrumbs;

@property (atomic, strong) NSMutableArray<SentryAttachment *> *attachmentArray;

@property (nonatomic, retain) NSMutableArray<id<SentryScopeObserver>> *observers;

@end

@implementation SentryScope {
    NSObject *_spanLock;
}

#pragma mark Initializer

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs
{
    if (self = [super init]) {
        self.maxBreadcrumbs = maxBreadcrumbs;
        self.breadcrumbArray = [NSMutableArray new];
        self.tagDictionary = [NSMutableDictionary new];
        self.extraDictionary = [NSMutableDictionary new];
        self.contextDictionary = [NSMutableDictionary new];
        self.attachmentArray = [NSMutableArray new];
        self.fingerprintArray = [NSMutableArray new];
        _spanLock = [[NSObject alloc] init];
        self.observers = [NSMutableArray new];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithMaxBreadcrumbs:defaultMaxBreadcrumbs];
}

- (instancetype)initWithScope:(SentryScope *)scope
{
    if (self = [self init]) {
        [_extraDictionary addEntriesFromDictionary:[scope extras]];
        [_tagDictionary addEntriesFromDictionary:[scope tags]];
        [_contextDictionary addEntriesFromDictionary:[scope context]];
        [_breadcrumbArray addObjectsFromArray:[scope breadcrumbs]];
        [_fingerprintArray addObjectsFromArray:[scope fingerprints]];
        [_attachmentArray addObjectsFromArray:[scope attachments]];

        self.maxBreadcrumbs = scope.maxBreadcrumbs;
        self.userObject = scope.userObject.copy;
        self.distString = scope.distString;
        self.environmentString = scope.environmentString;
        self.levelEnum = scope.levelEnum;
    }
    return self;
}

#pragma mark Global properties

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb
{
    if (self.maxBreadcrumbs < 1) {
        return;
    }
    [SentryLog logWithMessage:[NSString stringWithFormat:@"Add breadcrumb: %@", crumb]
                     andLevel:kSentryLevelDebug];
    @synchronized(_breadcrumbArray) {
        [_breadcrumbArray addObject:crumb];
        if ([_breadcrumbArray count] > self.maxBreadcrumbs) {
            [_breadcrumbArray removeObjectAtIndex:0];
        }

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer addBreadcrumb:crumb];
        }
    }
}

- (void)setSpan:(nullable id<SentrySpan>)span
{
    @synchronized(_spanLock) {
        _span = span;
    }
}

- (void)useSpan:(SentrySpanCallback)callback
{
    @synchronized(_spanLock) {
        callback(_span);
    }
}

- (void)clear
{
    // As we need to synchronize the accesses of the arrays and dictionaries and we use the
    // references instead of self we remove all objects instead of creating new instances. Removing
    // all objects is usually O(n). This is acceptable as we don't expect a huge amount of elements
    // in the arrays or dictionaries, that would slow down the performance.
    @synchronized(_breadcrumbArray) {
        [_breadcrumbArray removeAllObjects];
    }
    @synchronized(_tagDictionary) {
        [_tagDictionary removeAllObjects];
    }
    @synchronized(_extraDictionary) {
        [_extraDictionary removeAllObjects];
    }
    @synchronized(_contextDictionary) {
        [_contextDictionary removeAllObjects];
    }
    @synchronized(_fingerprintArray) {
        [_fingerprintArray removeAllObjects];
    }
    [self clearAttachments];
    @synchronized(_spanLock) {
        _span = nil;
    }

    self.userObject = nil;
    self.distString = nil;
    self.environmentString = nil;
    self.levelEnum = kSentryLevelNone;

    for (id<SentryScopeObserver> observer in self.observers) {
        [observer clear];
    }
}

- (void)clearBreadcrumbs
{
    @synchronized(_breadcrumbArray) {
        [_breadcrumbArray removeAllObjects];

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer clearBreadcrumbs];
        }
    }
}

- (NSArray<SentryBreadcrumb *> *)breadcrumbs
{
    @synchronized(_breadcrumbArray) {
        return _breadcrumbArray.copy;
    }
}

- (void)setContextValue:(NSDictionary<NSString *, id> *)value forKey:(NSString *)key
{
    @synchronized(_contextDictionary) {
        [_contextDictionary setValue:value forKey:key];

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setContext:_contextDictionary];
        }
    }
}

- (void)removeContextForKey:(NSString *)key
{
    @synchronized(_contextDictionary) {
        [_contextDictionary removeObjectForKey:key];

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setExtras:_contextDictionary];
        }
    }
}

- (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)context
{
    @synchronized(_contextDictionary) {
        return _contextDictionary.copy;
    }
}

- (void)setExtraValue:(id _Nullable)value forKey:(NSString *)key
{
    @synchronized(_extraDictionary) {
        [_extraDictionary setValue:value forKey:key];

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setExtras:_extraDictionary];
        }
    }
}

- (void)removeExtraForKey:(NSString *)key
{
    @synchronized(_extraDictionary) {
        [_extraDictionary removeObjectForKey:key];

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setExtras:_extraDictionary];
        }
    }
}

- (void)setExtras:(NSDictionary<NSString *, id> *_Nullable)extras
{
    if (extras == nil) {
        return;
    }
    @synchronized(_extraDictionary) {
        [_extraDictionary addEntriesFromDictionary:extras];

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setExtras:_extraDictionary];
        }
    }
}

- (NSDictionary<NSString *, id> *)extras
{
    @synchronized(_extraDictionary) {
        return _extraDictionary.copy;
    }
}

- (void)setTagValue:(NSString *)value forKey:(NSString *)key
{
    @synchronized(_tagDictionary) {
        _tagDictionary[key] = value;

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setTags:_tagDictionary];
        }
    }
}

- (void)removeTagForKey:(NSString *)key
{
    @synchronized(_tagDictionary) {
        [_tagDictionary removeObjectForKey:key];

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setTags:_tagDictionary];
        }
    }
}

- (void)setTags:(NSDictionary<NSString *, NSString *> *_Nullable)tags
{
    if (tags == nil) {
        return;
    }
    @synchronized(_tagDictionary) {
        [_tagDictionary addEntriesFromDictionary:tags];

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setTags:_tagDictionary];
        }
    }
}

- (NSDictionary<NSString *, NSString *> *)tags
{
    @synchronized(_tagDictionary) {
        return _tagDictionary.copy;
    }
}

- (void)setUser:(SentryUser *_Nullable)user
{
    self.userObject = user;

    for (id<SentryScopeObserver> observer in self.observers) {
        [observer setUser:user];
    }
}

- (void)setDist:(NSString *_Nullable)dist
{
    self.distString = dist;

    for (id<SentryScopeObserver> observer in self.observers) {
        [observer setDist:dist];
    }
}

- (void)setEnvironment:(NSString *_Nullable)environment
{
    self.environmentString = environment;

    for (id<SentryScopeObserver> observer in self.observers) {
        [observer setEnvironment:environment];
    }
}

- (void)setFingerprint:(NSArray<NSString *> *_Nullable)fingerprint
{
    @synchronized(_fingerprintArray) {
        [_fingerprintArray removeAllObjects];
        if (fingerprint != nil) {
            [_fingerprintArray addObjectsFromArray:fingerprint];
        }

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setFingerprint:_fingerprintArray];
        }
    }
}

- (NSArray<NSString *> *)fingerprints
{
    @synchronized(_fingerprintArray) {
        return _fingerprintArray.copy;
    }
}

- (void)setLevel:(enum SentryLevel)level
{
    self.levelEnum = level;

    for (id<SentryScopeObserver> observer in self.observers) {
        [observer setLevel:level];
    }
}

- (void)addAttachment:(SentryAttachment *)attachment
{
    @synchronized(_attachmentArray) {
        [_attachmentArray addObject:attachment];
    }
}

- (void)clearAttachments
{
    @synchronized(_attachmentArray) {
        [_attachmentArray removeAllObjects];
    }
}

- (NSArray<SentryAttachment *> *)attachments
{
    @synchronized(_attachmentArray) {
        return _attachmentArray.copy;
    }
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [NSMutableDictionary new];
    if (self.tags.count > 0) {
        [serializedData setValue:[self tags] forKey:@"tags"];
    }
    if (self.extras.count > 0) {
        [serializedData setValue:[self extras] forKey:@"extra"];
    }
    if (self.context.count > 0) {
        [serializedData setValue:[self context] forKey:@"context"];
    }
    [serializedData setValue:[self.userObject serialize] forKey:@"user"];
    [serializedData setValue:self.distString forKey:@"dist"];
    [serializedData setValue:self.environmentString forKey:@"environment"];
    if (self.fingerprints.count > 0) {
        [serializedData setValue:[self fingerprints] forKey:@"fingerprint"];
    }

    SentryLevel level = self.levelEnum;
    if (level != kSentryLevelNone) {
        [serializedData setValue:SentryLevelNames[level] forKey:@"level"];
    }
    NSArray *crumbs = [self serializeBreadcrumbs];
    if (crumbs.count > 0) {
        [serializedData setValue:crumbs forKey:@"breadcrumbs"];
    }
    return serializedData;
}

- (NSArray *)serializeBreadcrumbs
{
    NSMutableArray *serializedCrumbs = [NSMutableArray new];

    NSArray<SentryBreadcrumb *> *crumbs = [self breadcrumbs];
    for (SentryBreadcrumb *crumb in crumbs) {
        [serializedCrumbs addObject:[crumb serialize]];
    }

    return serializedCrumbs;
}

- (void)applyToSession:(SentrySession *)session
{
    SentryUser *userObject = self.userObject;
    if (nil != userObject) {
        session.user = userObject.copy;
    }

    NSString *environment = self.environmentString;
    if (nil != environment) {
        // TODO: Make sure environment set on options is applied to the
        // scope so it's available now
        session.environment = environment;
    }
}

- (SentryEvent *__nullable)applyToEvent:(SentryEvent *)event
                          maxBreadcrumb:(NSUInteger)maxBreadcrumbs
{
    if (nil == event.tags) {
        event.tags = [self tags];
    } else {
        NSMutableDictionary *newTags = [NSMutableDictionary new];
        [newTags addEntriesFromDictionary:[self tags]];
        [newTags addEntriesFromDictionary:event.tags];
        event.tags = newTags;
    }

    if (nil == event.extra) {
        event.extra = [self extras];
    } else {
        NSMutableDictionary *newExtra = [NSMutableDictionary new];
        [newExtra addEntriesFromDictionary:[self extras]];
        [newExtra addEntriesFromDictionary:event.extra];
        event.extra = newExtra;
    }

    NSArray *fingerprints = [self fingerprints];
    if (fingerprints.count > 0 && nil == event.fingerprint) {
        event.fingerprint = fingerprints;
    }

    if (nil == event.breadcrumbs) {
        NSArray *breadcrumbs = [self breadcrumbs];
        event.breadcrumbs = [breadcrumbs
            subarrayWithRange:NSMakeRange(0, MIN(maxBreadcrumbs, [breadcrumbs count]))];
    }

    SentryUser *user = self.userObject.copy;
    if (nil != user) {
        event.user = user;
    }

    NSString *dist = self.distString;
    if (nil != dist && nil == event.dist) {
        // dist can also be set via options but scope takes precedence.
        event.dist = dist;
    }

    NSString *environment = self.environmentString;
    if (nil != environment && nil == event.environment) {
        // environment can also be set via options but scope takes
        // precedence.
        event.environment = environment;
    }

    SentryLevel level = self.levelEnum;
    if (level != kSentryLevelNone) {
        // We always want to set the level from the scope since this has
        // been set on purpose
        event.level = level;
    }

    NSMutableDictionary *newContext;
    if (nil == event.context) {
        newContext = [self context].mutableCopy;
    } else {
        newContext = [NSMutableDictionary new];
        [newContext addEntriesFromDictionary:[self context]];
        [newContext addEntriesFromDictionary:event.context];
    }

    if (self.span != nil) {
        id<SentrySpan> span;
        @synchronized(_spanLock) {
            span = self.span;
        }

        // Span could be nil as we do the first check outside the synchronize
        if (span != nil) {
            if (![event.type isEqualToString:SentryEnvelopeItemTypeTransaction] &&
                [span isKindOfClass:[SentryTracer class]]) {
                event.transaction = [(SentryTracer *)span name];
            }
            newContext[@"trace"] = [span.context serialize];
        }
    }
    event.context = newContext;
    return event;
}

- (void)addObserver:(id<SentryScopeObserver>)observer
{
    [self.observers addObject:observer];
}

@end

NS_ASSUME_NONNULL_END
