#import "SentryFileManager.h"
#import "NSDate+SentryExtras.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryEvent.h"
#import "SentryFileContents.h"
#import "SentryLog.h"
#import "SentrySerialization.h"

NS_ASSUME_NONNULL_BEGIN

NSInteger const defaultMaxEvents = 10;
NSInteger const defaultMaxEnvelopes = 100;

@interface
SentryFileManager ()

@property (nonatomic, strong) id<SentryCurrentDateProvider> currentDateProvider;
@property (nonatomic, copy) NSString *sentryPath;
@property (nonatomic, copy) NSString *eventsPath;
@property (nonatomic, copy) NSString *envelopesPath;
@property (nonatomic, copy) NSString *currentSessionFilePath;
@property (nonatomic, copy) NSString *lastInForegroundFilePath;
@property (nonatomic, assign) NSUInteger currentFileCounter;

@end

@implementation SentryFileManager

- (_Nullable instancetype)initWithDsn:(SentryDsn *)dsn
               andCurrentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
                     didFailWithError:(NSError **)error
{
    self = [super init];
    if (self) {
        self.currentDateProvider = currentDateProvider;

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *cachePath
            = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)
                  .firstObject;

        self.sentryPath = [cachePath stringByAppendingPathComponent:@"io.sentry"];
        self.sentryPath = [self.sentryPath stringByAppendingPathComponent:[dsn getHash]];

        if (![fileManager fileExistsAtPath:self.sentryPath]) {
            [self.class createDirectoryAtPath:self.sentryPath withError:error];
        }

        self.currentSessionFilePath =
            [self.sentryPath stringByAppendingPathComponent:@"session.current"];

        self.lastInForegroundFilePath =
            [self.sentryPath stringByAppendingPathComponent:@"lastInForeground.timestamp"];

        self.eventsPath = [self.sentryPath stringByAppendingPathComponent:@"events"];
        [self createDirectoryIfNotExists:self.eventsPath didFailWithError:error];

        self.envelopesPath = [self.sentryPath stringByAppendingPathComponent:@"envelopes"];
        [self createDirectoryIfNotExists:self.envelopesPath didFailWithError:error];

        self.currentFileCounter = 0;
        self.maxEvents = defaultMaxEvents;
        self.maxEnvelopes = defaultMaxEnvelopes;
    }
    return self;
}

- (void)deleteAllFolders
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:self.eventsPath error:nil];
    [fileManager removeItemAtPath:self.envelopesPath error:nil];
    [fileManager removeItemAtPath:self.sentryPath error:nil];
}

- (NSString *)uniqueAcendingJsonName
{
    // %f = double, %lu = unsigned long, %@ = NSString
    // For example 978307200.000000-0-3FE8C3AE-EB9C-4BEB-868C-14B8D47C33DD.json
    return [NSString stringWithFormat:@"%f-%lu-%@.json",
                     [[self.currentDateProvider date] timeIntervalSince1970],
                     (unsigned long)self.currentFileCounter++, [NSUUID UUID].UUIDString];
}

- (NSArray<SentryFileContents *> *)getAllEventsAndMaybeEnvelopes
{
    return [self allFilesContentInFolder:self.eventsPath];
}

- (NSArray<SentryFileContents *> *)getAllEnvelopes
{
    return [self allFilesContentInFolder:self.envelopesPath];
}

- (NSArray<SentryFileContents *> *)getAllStoredEventsAndEnvelopes
{
    return
        [[self getAllEventsAndMaybeEnvelopes] arrayByAddingObjectsFromArray:[self getAllEnvelopes]];
}

- (NSArray<SentryFileContents *> *)allFilesContentInFolder:(NSString *)path
{
    @synchronized(self) {
        NSMutableArray<SentryFileContents *> *contents = [NSMutableArray new];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        for (NSString *filePath in [self allFilesInFolder:path]) {
            NSString *finalPath = [path stringByAppendingPathComponent:filePath];
            NSData *content = [fileManager contentsAtPath:finalPath];
            if (nil != content) {
                [contents addObject:[[SentryFileContents alloc] initWithPath:finalPath
                                                                 andContents:content]];
            }
        }
        return contents;
    }
}

- (void)deleteAllStoredEventsAndEnvelopes
{
    for (NSString *path in [self allFilesInFolder:self.eventsPath]) {
        [self removeFileAtPath:[self.eventsPath stringByAppendingPathComponent:path]];
    }

    for (NSString *path in [self allFilesInFolder:self.envelopesPath]) {
        [self removeFileAtPath:[self.envelopesPath stringByAppendingPathComponent:path]];
    }
}

- (NSArray<NSString *> *)allFilesInFolder:(NSString *)path
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    NSArray<NSString *> *storedFiles = [fileManager contentsOfDirectoryAtPath:path error:&error];
    if (nil != error) {
        [SentryLog
            logWithMessage:[NSString stringWithFormat:@"Couldn't load files in folder %@: %@", path,
                                     error]
                  andLevel:kSentryLogLevelError];
        return [NSArray new];
    }
    return [storedFiles sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (BOOL)removeFileAtPath:(NSString *)path
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    @synchronized(self) {
        [fileManager removeItemAtPath:path error:&error];
        if (nil != error) {
            [SentryLog logWithMessage:[NSString stringWithFormat:@"Couldn't delete file %@: %@",
                                                path, error]
                             andLevel:kSentryLogLevelError];
            return NO;
        }
    }
    return YES;
}

- (NSString *)storeEvent:(SentryEvent *)event
{
    return [self storeEvent:event maxCount:self.maxEvents];
}

- (NSString *)storeEvent:(SentryEvent *)event maxCount:(NSUInteger)maxCount
{
    @synchronized(self) {
        NSString *result;
        if (nil != event.json) {
            result = [self storeData:event.json toPath:self.eventsPath];
        } else {
            result = [self storeDictionary:[event serialize] toPath:self.eventsPath];
        }
        [self handleFileManagerLimit:self.eventsPath maxCount:maxCount];
        return result;
    }
}

- (NSString *)storeEnvelope:(SentryEnvelope *)envelope
{
    @synchronized(self) {
        NSString *result = [self storeData:[SentrySerialization dataWithEnvelope:envelope error:nil]
                                    toPath:self.envelopesPath];
        [self handleFileManagerLimit:self.envelopesPath maxCount:self.maxEnvelopes];
        return result;
    }
}

- (void)storeCurrentSession:(SentrySession *)session
{
    NSData *sessionData = [SentrySerialization dataWithSession:session error:nil];
    [SentryLog logWithMessage:[NSString stringWithFormat:@"Writing to current session: %@",
                                        self.currentSessionFilePath]
                     andLevel:kSentryLogLevelDebug];
    @synchronized(self.currentSessionFilePath) {
        [sessionData writeToFile:self.currentSessionFilePath options:NSDataWritingAtomic error:nil];
    }
}

- (void)deleteCurrentSession
{
    [SentryLog logWithMessage:[NSString stringWithFormat:@"Deleting current session: %@",
                                        self.currentSessionFilePath]
                     andLevel:kSentryLogLevelDebug];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    @synchronized(self.currentSessionFilePath) {
        [fileManager removeItemAtPath:self.currentSessionFilePath error:nil];
    }
}

- (SentrySession *_Nullable)readCurrentSession
{
    [SentryLog logWithMessage:[NSString stringWithFormat:@"Reading from current session: %@",
                                        self.currentSessionFilePath]
                     andLevel:kSentryLogLevelDebug];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSData *currentSessionData = nil;
    @synchronized(self.currentSessionFilePath) {
        currentSessionData = [fileManager contentsAtPath:self.currentSessionFilePath];
        if (nil == currentSessionData) {
            return nil;
        }
        SentrySession *currentSession = [SentrySerialization sessionWithData:currentSessionData];
        if (nil == currentSession) {
            [SentryLog logWithMessage:[NSString stringWithFormat:@"Data stored in current session: "
                                                                 @"'%@' was not parsed as session.",
                                                self.currentSessionFilePath]
                             andLevel:kSentryLogLevelError];
            return nil;
        }
        return currentSession;
    }
}

- (void)storeTimestampLastInForeground:(NSDate *)timestamp
{
    NSString *timestampString = [timestamp sentry_toIso8601String];
    NSString *logMessage =
        [NSString stringWithFormat:@"Persisting lastInForeground: %@", timestampString];
    [SentryLog logWithMessage:logMessage andLevel:kSentryLogLevelDebug];
    @synchronized(self.lastInForegroundFilePath) {
        [[timestampString dataUsingEncoding:NSUTF8StringEncoding]
            writeToFile:self.lastInForegroundFilePath
                options:NSDataWritingAtomic
                  error:nil];
    }
}

- (void)deleteTimestampLastInForeground
{
    [SentryLog logWithMessage:[NSString stringWithFormat:@"Deleting LastInForeground at: %@",
                                        self.lastInForegroundFilePath]
                     andLevel:kSentryLogLevelDebug];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    @synchronized(self.lastInForegroundFilePath) {
        [fileManager removeItemAtPath:self.lastInForegroundFilePath error:nil];
    }
}

- (NSDate *_Nullable)readTimestampLastInForeground
{
    [SentryLog logWithMessage:[NSString stringWithFormat:@"Reading timestamp of last "
                                                         @"in foreground at: %@",
                                        self.lastInForegroundFilePath]
                     andLevel:kSentryLogLevelDebug];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSData *lastInForegroundData = nil;
    @synchronized(self.lastInForegroundFilePath) {
        lastInForegroundData = [fileManager contentsAtPath:self.lastInForegroundFilePath];
    }
    if (nil == lastInForegroundData) {
        [SentryLog logWithMessage:@"No lastInForeground found." andLevel:kSentryLogLevelDebug];
        return nil;
    }
    NSString *timestampString = [[NSString alloc] initWithData:lastInForegroundData
                                                      encoding:NSUTF8StringEncoding];
    return [NSDate sentry_fromIso8601String:timestampString];
}

- (NSString *)storeData:(NSData *)data toPath:(NSString *)path
{
    @synchronized(self) {
        NSString *finalPath = [path stringByAppendingPathComponent:[self uniqueAcendingJsonName]];
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Writing to file: %@", finalPath]
                         andLevel:kSentryLogLevelDebug];
        [data writeToFile:finalPath options:NSDataWritingAtomic error:nil];
        return finalPath;
    }
}

- (NSString *)storeDictionary:(NSDictionary *)dictionary toPath:(NSString *)path
{
    NSData *saveData = [SentrySerialization dataWithJSONObject:dictionary error:nil];
    return nil != saveData ? [self storeData:saveData toPath:path]
                           : path; // TODO: Should we return null instead? Whoever is using this
                                   // return value is being tricked.
}

- (void)handleFileManagerLimit:(NSString *)path maxCount:(NSUInteger)maxCount
{
    NSArray<NSString *> *files = [self allFilesInFolder:path];
    NSInteger numbersOfFilesToRemove = ((NSInteger)files.count) - maxCount;
    if (numbersOfFilesToRemove > 0) {
        for (NSUInteger i = 0; i < numbersOfFilesToRemove; i++) {
            [self removeFileAtPath:[path stringByAppendingPathComponent:[files objectAtIndex:i]]];
        }
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Removed %ld file(s) from <%@>",
                                            (long)numbersOfFilesToRemove, [path lastPathComponent]]
                         andLevel:kSentryLogLevelDebug];
    }
}

+ (BOOL)createDirectoryAtPath:(NSString *)path withError:(NSError **)error
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return [fileManager createDirectoryAtPath:path
                  withIntermediateDirectories:YES
                                   attributes:nil
                                        error:error];
}

#pragma mark private methods

- (BOOL)createDirectoryIfNotExists:(NSString *)path didFailWithError:(NSError **)error
{
    return [[NSFileManager defaultManager] createDirectoryAtPath:path
                                     withIntermediateDirectories:YES
                                                      attributes:nil
                                                           error:error];
}

@end

NS_ASSUME_NONNULL_END
