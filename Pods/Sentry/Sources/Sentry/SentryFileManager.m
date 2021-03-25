#import "SentryFileManager.h"
#import "NSDate+SentryExtras.h"
#import "SentryAppState.h"
#import "SentryDefaultCurrentDateProvider.h"
#import "SentryDsn.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeItemType.h"
#import "SentryError.h"
#import "SentryEvent.h"
#import "SentryFileContents.h"
#import "SentryLog.h"
#import "SentryMigrateSessionInit.h"
#import "SentryOptions.h"
#import "SentrySerialization.h"
#import "SentrySession+Private.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryFileManager ()

@property (nonatomic, strong) id<SentryCurrentDateProvider> currentDateProvider;
@property (nonatomic, copy) NSString *sentryPath;
@property (nonatomic, copy) NSString *eventsPath;
@property (nonatomic, copy) NSString *envelopesPath;
@property (nonatomic, copy) NSString *currentSessionFilePath;
@property (nonatomic, copy) NSString *crashedSessionFilePath;
@property (nonatomic, copy) NSString *lastInForegroundFilePath;
@property (nonatomic, copy) NSString *appStateFilePath;
@property (nonatomic, assign) NSUInteger currentFileCounter;
@property (nonatomic, assign) NSUInteger maxEnvelopes;

@end

@implementation SentryFileManager

- (nullable instancetype)initWithOptions:(SentryOptions *)options
                  andCurrentDateProvider:(id<SentryCurrentDateProvider>)currentDateProvider
                                   error:(NSError **)error
{
    self = [super init];
    if (self) {
        self.currentDateProvider = currentDateProvider;

        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSString *cachePath
            = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)
                  .firstObject;

        self.sentryPath = [cachePath stringByAppendingPathComponent:@"io.sentry"];
        self.sentryPath =
            [self.sentryPath stringByAppendingPathComponent:[options.parsedDsn getHash]];

        if (![fileManager fileExistsAtPath:self.sentryPath]) {
            [self.class createDirectoryAtPath:self.sentryPath withError:error];
        }

        self.currentSessionFilePath =
            [self.sentryPath stringByAppendingPathComponent:@"session.current"];

        self.crashedSessionFilePath =
            [self.sentryPath stringByAppendingPathComponent:@"session.crashed"];

        self.lastInForegroundFilePath =
            [self.sentryPath stringByAppendingPathComponent:@"lastInForeground.timestamp"];

        self.appStateFilePath = [self.sentryPath stringByAppendingPathComponent:@"app.state"];

        // Remove old cached events for versions before 6.0.0
        self.eventsPath = [self.sentryPath stringByAppendingPathComponent:@"events"];
        [fileManager removeItemAtPath:self.eventsPath error:nil];

        self.envelopesPath = [self.sentryPath stringByAppendingPathComponent:@"envelopes"];
        [self createDirectoryIfNotExists:self.envelopesPath didFailWithError:error];

        self.currentFileCounter = 0;
        self.maxEnvelopes = options.maxCacheItems;
    }
    return self;
}

- (void)deleteAllFolders
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:self.envelopesPath error:nil];
    [fileManager removeItemAtPath:self.sentryPath error:nil];
}

- (NSString *)uniqueAcendingJsonName
{
    // %f = double
    // %05lu = unsigned with always 5 digits and leading zeros if number is too small. We
    //      need this because otherwise 10 would be sorted before 2 for example.
    // %@ = NSString
    // For example 978307200.000000-00001-3FE8C3AE-EB9C-4BEB-868C-14B8D47C33DD.json
    return [NSString stringWithFormat:@"%f-%05lu-%@.json",
                     [[self.currentDateProvider date] timeIntervalSince1970],
                     (unsigned long)self.currentFileCounter++, [NSUUID UUID].UUIDString];
}

- (NSArray<SentryFileContents *> *)getAllEnvelopes
{
    return [self allFilesContentInFolder:self.envelopesPath];
}

- (SentryFileContents *_Nullable)getOldestEnvelope
{
    NSArray<NSString *> *pathsOfAllEnvelopes;
    @synchronized(self) {
        pathsOfAllEnvelopes = [self allFilesInFolder:self.envelopesPath];
    }

    if (pathsOfAllEnvelopes.count > 0) {
        NSString *filePath = pathsOfAllEnvelopes[0];
        return [self getFileContents:self.envelopesPath filePath:filePath];
    }

    return nil;
}

- (NSArray<SentryFileContents *> *)allFilesContentInFolder:(NSString *)path
{
    @synchronized(self) {
        NSMutableArray<SentryFileContents *> *contents = [NSMutableArray new];
        for (NSString *filePath in [self allFilesInFolder:path]) {
            SentryFileContents *fileContents = [self getFileContents:path filePath:filePath];

            if (nil != fileContents) {
                [contents addObject:fileContents];
            }
        }
        return contents;
    }
}

- (SentryFileContents *_Nullable)getFileContents:(NSString *)folderPath
                                        filePath:(NSString *)filePath
{

    NSString *finalPath = [folderPath stringByAppendingPathComponent:filePath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSData *content = [fileManager contentsAtPath:finalPath];
    if (nil != content) {
        return [[SentryFileContents alloc] initWithPath:finalPath andContents:content];
    } else {
        return nil;
    }
}

- (void)deleteAllEnvelopes
{
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
                  andLevel:kSentryLevelError];
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
                             andLevel:kSentryLevelError];
            return NO;
        }
    }
    return YES;
}

- (NSString *)storeEnvelope:(SentryEnvelope *)envelope
{
    @synchronized(self) {
        NSString *result = [self storeData:[SentrySerialization dataWithEnvelope:envelope error:nil]
                                    toPath:self.envelopesPath];
        [self handleEnvelopesLimit];
        return result;
    }
}

- (void)handleEnvelopesLimit
{
    NSArray<NSString *> *envelopeFilePaths = [self allFilesInFolder:self.envelopesPath];
    NSInteger numberOfEnvelopesToRemove = envelopeFilePaths.count - self.maxEnvelopes;
    if (numberOfEnvelopesToRemove <= 0) {
        return;
    }

    for (NSUInteger i = 0; i < numberOfEnvelopesToRemove; i++) {
        NSString *envelopeFilePath =
            [self.envelopesPath stringByAppendingPathComponent:envelopeFilePaths[i]];

        // Remove current envelope path
        NSMutableArray<NSString *> *envelopePathsCopy =
            [[NSMutableArray alloc] initWithArray:[envelopeFilePaths copy]];
        [envelopePathsCopy removeObjectAtIndex:i];

        [SentryMigrateSessionInit migrateSessionInit:envelopeFilePath
                                    envelopesDirPath:self.envelopesPath
                                   envelopeFilePaths:envelopePathsCopy];

        [self removeFileAtPath:envelopeFilePath];
    }

    [SentryLog logWithMessage:[NSString stringWithFormat:@"Removed %ld file(s) from <%@>",
                                        (long)numberOfEnvelopesToRemove,
                                        [self.envelopesPath lastPathComponent]]
                     andLevel:kSentryLevelDebug];
}

- (void)storeCurrentSession:(SentrySession *)session
{
    [self storeSession:session sessionFilePath:self.currentSessionFilePath];
}

- (void)storeCrashedSession:(SentrySession *)session
{
    [self storeSession:session sessionFilePath:self.crashedSessionFilePath];
}

- (void)storeSession:(SentrySession *)session sessionFilePath:(NSString *)sessionFilePath
{
    NSData *sessionData = [SentrySerialization dataWithSession:session error:nil];
    [SentryLog logWithMessage:[NSString stringWithFormat:@"Writing session: %@", sessionFilePath]
                     andLevel:kSentryLevelDebug];
    @synchronized(self.currentSessionFilePath) {
        [sessionData writeToFile:sessionFilePath options:NSDataWritingAtomic error:nil];
    }
}

- (void)deleteCurrentSession
{
    [self deleteSession:self.currentSessionFilePath];
}

- (void)deleteCrashedSession
{
    [self deleteSession:self.crashedSessionFilePath];
}

- (void)deleteSession:(NSString *)sessionFilePath
{
    [SentryLog logWithMessage:[NSString stringWithFormat:@"Deleting session: %@", sessionFilePath]
                     andLevel:kSentryLevelDebug];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    @synchronized(self.currentSessionFilePath) {
        [fileManager removeItemAtPath:sessionFilePath error:nil];
    }
}

- (SentrySession *_Nullable)readCurrentSession
{
    return [self readSession:self.currentSessionFilePath];
}

- (SentrySession *_Nullable)readCrashedSession
{
    return [self readSession:self.crashedSessionFilePath];
}

- (SentrySession *)readSession:(NSString *)sessionFilePath
{
    [SentryLog
        logWithMessage:[NSString stringWithFormat:@"Reading from session: %@", sessionFilePath]
              andLevel:kSentryLevelDebug];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSData *currentData = nil;
    @synchronized(self.currentSessionFilePath) {
        currentData = [fileManager contentsAtPath:sessionFilePath];
        if (nil == currentData) {
            return nil;
        }
    }
    SentrySession *currentSession = [SentrySerialization sessionWithData:currentData];
    if (nil == currentSession) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Data stored in session: "
                                                             @"'%@' was not parsed as session.",
                                            sessionFilePath]
                         andLevel:kSentryLevelError];
        return nil;
    }
    return currentSession;
}

- (void)storeTimestampLastInForeground:(NSDate *)timestamp
{
    NSString *timestampString = [timestamp sentry_toIso8601String];
    NSString *logMessage =
        [NSString stringWithFormat:@"Persisting lastInForeground: %@", timestampString];
    [SentryLog logWithMessage:logMessage andLevel:kSentryLevelDebug];
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
                     andLevel:kSentryLevelDebug];
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
                     andLevel:kSentryLevelDebug];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSData *lastInForegroundData = nil;
    @synchronized(self.lastInForegroundFilePath) {
        lastInForegroundData = [fileManager contentsAtPath:self.lastInForegroundFilePath];
    }
    if (nil == lastInForegroundData) {
        [SentryLog logWithMessage:@"No lastInForeground found." andLevel:kSentryLevelDebug];
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
                         andLevel:kSentryLevelDebug];
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

- (void)storeAppState:(SentryAppState *)appState
{
    NSError *error = nil;
    NSData *data = [SentrySerialization dataWithJSONObject:[appState serialize] error:&error];

    if (nil != error) {
        [SentryLog logWithMessage:[NSString stringWithFormat:@"Failed to store app state, because "
                                                             @"of an error in serialization: %@",
                                            error]
                         andLevel:kSentryLevelError];
        return;
    }

    @synchronized(self.appStateFilePath) {
        [data writeToFile:self.appStateFilePath options:NSDataWritingAtomic error:&error];
        if (nil != error) {
            [SentryLog
                logWithMessage:[NSString stringWithFormat:@"Failed to store app state %@", error]
                      andLevel:kSentryLevelError];
        }
    }
}

- (SentryAppState *_Nullable)readAppState
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSData *currentData = nil;
    @synchronized(self.appStateFilePath) {
        currentData = [fileManager contentsAtPath:self.appStateFilePath];
        if (nil == currentData) {
            return nil;
        }
    }
    return [SentrySerialization appStateWithData:currentData];
}

- (void)deleteAppState
{
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    @synchronized(self.appStateFilePath) {
        [fileManager removeItemAtPath:self.appStateFilePath error:&error];

        // We don't want to log an error if the file doesn't exist.
        if (nil != error && error.code != NSFileNoSuchFileError) {
            [SentryLog
                logWithMessage:[NSString stringWithFormat:@"Failed to delete app state %@", error]
                      andLevel:kSentryLevelError];
        }
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
