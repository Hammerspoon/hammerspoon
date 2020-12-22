#import "SentryScope.h"
#import "SentryBreadcrumb.h"
#import "SentryEvent.h"
#import "SentryGlobalEventProcessor.h"
#import "SentryLog.h"
#import "SentryScope+Private.h"
#import "SentrySession.h"
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
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *_Nullable tagDictionary;

/**
 * Set global extra -> these will be sent with every event
 */
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *_Nullable extraDictionary;

/**
 * used to add values in event context.
 */
@property (nonatomic, strong)
    NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *_Nullable contextDictionary;

/**
 * Contains the breadcrumbs which will be sent with the event
 */
@property (nonatomic, strong) NSMutableArray<SentryBreadcrumb *> *breadcrumbArray;

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
@property (atomic, strong) NSArray<NSString *> *_Nullable fingerprintArray;

/**
 * SentryLevel of the event
 */
@property (atomic) enum SentryLevel levelEnum;

@property (atomic) NSInteger maxBreadcrumbs;

@end

@implementation SentryScope

#pragma mark Initializer

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs
{
    if (self = [super init]) {
        self.listeners = [NSMutableArray new];
        self.maxBreadcrumbs = maxBreadcrumbs;
        [self clear];
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
        self.extraDictionary = scope.extraDictionary.mutableCopy;
        self.tagDictionary = scope.tagDictionary.mutableCopy;
        SentryUser *scopeUser = scope.userObject;
        SentryUser *user = nil;
        if (nil != scopeUser) {
            user = [[SentryUser alloc] init];
            user.userId = scopeUser.userId;
            user.data = scopeUser.data.mutableCopy;
            user.username = scopeUser.username;
            user.email = scopeUser.email;
        }
        self.maxBreadcrumbs = scope.maxBreadcrumbs;
        self.userObject = user;
        self.contextDictionary = scope.contextDictionary.mutableCopy;
        self.breadcrumbArray = scope.breadcrumbArray.mutableCopy;
        self.distString = scope.distString;
        self.environmentString = scope.environmentString;
        self.levelEnum = scope.levelEnum;
        self.fingerprintArray = scope.fingerprintArray.mutableCopy;
    }
    return self;
}

#pragma mark Global properties

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb
{
    [SentryLog logWithMessage:[NSString stringWithFormat:@"Add breadcrumb: %@", crumb]
                     andLevel:kSentryLogLevelDebug];
    @synchronized(self) {
        [self.breadcrumbArray addObject:crumb];
        if ([self.breadcrumbArray count] > self.maxBreadcrumbs) {
            [self.breadcrumbArray removeObjectAtIndex:0];
        }
    }
    [self notifyListeners];
}

- (void)clear
{
    @synchronized(self) {
        self.breadcrumbArray = [NSMutableArray new];
        self.userObject = nil;
        self.tagDictionary = [NSMutableDictionary new];
        self.extraDictionary = [NSMutableDictionary new];
        self.contextDictionary = [NSMutableDictionary new];
        self.distString = nil;
        self.environmentString = nil;
        self.levelEnum = kSentryLevelNone;
        self.fingerprintArray = [NSMutableArray new];
    }
    [self notifyListeners];
}

- (void)clearBreadcrumbs
{
    @synchronized(self) {
        [self.breadcrumbArray removeAllObjects];
    }
    [self notifyListeners];
}

- (void)setContextValue:(NSDictionary<NSString *, id> *)value forKey:(NSString *)key
{
    @synchronized(self) {
        [self.contextDictionary setValue:value forKey:key];
    }
    [self notifyListeners];
}

- (void)removeContextForKey:(NSString *)key
{
    @synchronized(self) {
        [self.contextDictionary removeObjectForKey:key];
    }
    [self notifyListeners];
}

- (void)setExtraValue:(id _Nullable)value forKey:(NSString *)key
{
    @synchronized(self) {
        [self.extraDictionary setValue:value forKey:key];
    }
    [self notifyListeners];
}

- (void)removeExtraForKey:(NSString *)key
{
    @synchronized(self) {
        [self.extraDictionary removeObjectForKey:key];
    }
    [self notifyListeners];
}

- (void)setExtras:(NSDictionary<NSString *, id> *_Nullable)extras
{
    if (extras == nil) {
        return;
    }
    @synchronized(self) {
        [self.extraDictionary addEntriesFromDictionary:extras];
    }
    [self notifyListeners];
}

- (void)setTagValue:(NSString *)value forKey:(NSString *)key
{
    @synchronized(self) {
        self.tagDictionary[key] = value;
    }
    [self notifyListeners];
}

- (void)removeTagForKey:(NSString *)key
{
    @synchronized(self) {
        [self.tagDictionary removeObjectForKey:key];
    }
    [self notifyListeners];
}

- (void)setTags:(NSDictionary<NSString *, NSString *> *_Nullable)tags
{
    if (tags == nil) {
        return;
    }
    @synchronized(self) {
        [self.tagDictionary addEntriesFromDictionary:tags];
    }
    [self notifyListeners];
}

- (void)setUser:(SentryUser *_Nullable)user
{
    self.userObject = user;
    [self notifyListeners];
}

- (void)setDist:(NSString *_Nullable)dist
{
    self.distString = dist;
    [self notifyListeners];
}

- (void)setEnvironment:(NSString *_Nullable)environment
{
    self.environmentString = environment;
    [self notifyListeners];
}

- (void)setFingerprint:(NSArray<NSString *> *_Nullable)fingerprint
{
    @synchronized(self) {
        if (fingerprint == nil) {
            self.fingerprintArray = [NSMutableArray new];
        } else {
            self.fingerprintArray = fingerprint.mutableCopy;
        }
        self.fingerprintArray = fingerprint;
    }
    [self notifyListeners];
}

- (void)setLevel:(enum SentryLevel)level
{
    self.levelEnum = level;
    [self notifyListeners];
}

- (NSDictionary<NSString *, id> *)serializeBreadcrumbs
{
    NSMutableArray *crumbs = [NSMutableArray new];

    for (SentryBreadcrumb *crumb in self.breadcrumbArray) {
        [crumbs addObject:[crumb serialize]];
    }

    NSMutableDictionary *serializedData = [NSMutableDictionary new];
    if (crumbs.count > 0) {
        [serializedData setValue:crumbs forKey:@"breadcrumbs"];
    }

    return serializedData;
}

- (NSDictionary<NSString *, id> *)serialize
{
    @synchronized(self) {
        NSMutableDictionary *serializedData = [[self serializeBreadcrumbs] mutableCopy];
        [serializedData setValue:self.tagDictionary forKey:@"tags"];
        [serializedData setValue:self.extraDictionary forKey:@"extra"];
        [serializedData setValue:self.contextDictionary forKey:@"context"];
        [serializedData setValue:[self.userObject serialize] forKey:@"user"];
        [serializedData setValue:self.distString forKey:@"dist"];
        [serializedData setValue:self.environmentString forKey:@"environment"];
        [serializedData setValue:self.fingerprintArray forKey:@"fingerprint"];
        if (self.levelEnum != kSentryLevelNone) {
            [serializedData setValue:SentryLevelNames[self.levelEnum] forKey:@"level"];
        }
        return serializedData;
    }
}

- (void)applyToSession:(SentrySession *)session
{
    @synchronized(self) {
        if (nil != self.userObject) {
            session.user = self.userObject.copy;
        }

        NSString *environment = self.environmentString;
        if (nil != environment) {
            // TODO: Make sure environment set on options is applied to the
            // scope so it's available now
            session.environment = environment;
        }
    }
}

- (SentryEvent *__nullable)applyToEvent:(SentryEvent *)event
                          maxBreadcrumb:(NSUInteger)maxBreadcrumbs
{
    @synchronized(self) {
        if (nil != self.tagDictionary) {
            if (nil == event.tags) {
                event.tags = self.tagDictionary.copy;
            } else {
                NSMutableDictionary *newTags = [NSMutableDictionary new];
                [newTags addEntriesFromDictionary:self.tagDictionary];
                [newTags addEntriesFromDictionary:event.tags];
                event.tags = newTags;
            }
        }

        if (nil != self.extraDictionary) {
            if (nil == event.extra) {
                event.extra = self.extraDictionary.copy;
            } else {
                NSMutableDictionary *newExtra = [NSMutableDictionary new];
                [newExtra addEntriesFromDictionary:self.extraDictionary];
                [newExtra addEntriesFromDictionary:event.extra];
                event.extra = newExtra;
            }
        }

        if (nil != self.userObject) {
            event.user = self.userObject.copy;
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

        NSArray *fingerprint = self.fingerprintArray;
        if (fingerprint.count > 0 && nil == event.fingerprint) {
            event.fingerprint = fingerprint.mutableCopy;
        }

        if (self.levelEnum != kSentryLevelNone) {
            // We always want to set the level from the scope since this has
            // benn set on purpose
            event.level = self.levelEnum;
        }

        if (nil != self.breadcrumbArray) {
            if (nil == event.breadcrumbs) {
                event.breadcrumbs = [self.breadcrumbArray
                    subarrayWithRange:NSMakeRange(
                                          0, MIN(maxBreadcrumbs, [self.breadcrumbArray count]))];
            }
        }

        if (nil != self.contextDictionary) {
            if (nil == event.context) {
                event.context = self.contextDictionary;
            } else {
                NSMutableDictionary *newContext = [NSMutableDictionary new];
                [newContext addEntriesFromDictionary:self.contextDictionary];
                [newContext addEntriesFromDictionary:event.context];
                event.context = newContext;
            }
        }

        return event;
    }
}

- (BOOL)isEqual:(id _Nullable)other
{
    if (other == self)
        return YES;
    if (!other || ![[other class] isEqual:[self class]])
        return NO;

    return [self isEqualToScope:other];
}

- (BOOL)isEqualToScope:(SentryScope *)scope
{
    if (self == scope)
        return YES;
    if (scope == nil)
        return NO;
    if (self.userObject != scope.userObject && ![self.userObject isEqualToUser:scope.userObject])
        return NO;
    if (self.tagDictionary != scope.tagDictionary
        && ![self.tagDictionary isEqualToDictionary:scope.tagDictionary])
        return NO;
    if (self.extraDictionary != scope.extraDictionary
        && ![self.extraDictionary isEqualToDictionary:scope.extraDictionary])
        return NO;
    if (self.contextDictionary != scope.contextDictionary
        && ![self.contextDictionary isEqualToDictionary:scope.contextDictionary])
        return NO;
    if (self.breadcrumbArray != scope.breadcrumbArray
        && ![self.breadcrumbArray isEqualToArray:scope.breadcrumbArray])
        return NO;
    if (self.distString != scope.distString && ![self.distString isEqualToString:scope.distString])
        return NO;
    if (self.environmentString != scope.environmentString
        && ![self.environmentString isEqualToString:scope.environmentString])
        return NO;
    if (self.fingerprintArray != scope.fingerprintArray
        && ![self.fingerprintArray isEqualToArray:scope.fingerprintArray])
        return NO;
    if (self.levelEnum != scope.levelEnum)
        return NO;
    if (self.maxBreadcrumbs != scope.maxBreadcrumbs)
        return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = [self.userObject hash];
    hash = hash * 23 + [self.tagDictionary hash];
    hash = hash * 23 + [self.extraDictionary hash];
    hash = hash * 23 + [self.contextDictionary hash];
    hash = hash * 23 + [self.breadcrumbArray hash];
    hash = hash * 23 + [self.distString hash];
    hash = hash * 23 + [self.environmentString hash];
    hash = hash * 23 + [self.fingerprintArray hash];
    hash = hash * 23 + (NSUInteger)self.levelEnum;
    hash = hash * 23 + self.maxBreadcrumbs;
    return hash;
}

@end

NS_ASSUME_NONNULL_END
