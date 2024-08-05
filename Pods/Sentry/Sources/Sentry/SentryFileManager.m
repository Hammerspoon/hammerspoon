#import "SentryFileManager.h"
#import "SentryAppState.h"
#import "SentryDataCategoryMapper.h"
#import "SentryDateUtils.h"
#import "SentryDependencyContainer.h"
#import "SentryDispatchQueueWrapper.h"
#import "SentryDsn.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeItemHeader.h"
#import "SentryError.h"
#import "SentryEvent.h"
#import "SentryFileContents.h"
#import "SentryInternalDefines.h"
#import "SentryLog.h"
#import "SentryMigrateSessionInit.h"
#import "SentryOptions.h"
#import "SentrySerialization.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const EnvelopesPathComponent = @"envelopes";

BOOL
createDirectoryIfNotExists(NSString *path, NSError **error)
{
    if (![[NSFileManager defaultManager] createDirectoryAtPath:path
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:error]) {
        *error = NSErrorFromSentryErrorWithUnderlyingError(kSentryErrorFileIO,
            [NSString stringWithFormat:@"Failed to create the directory at path %@.", path],
            *error);
        return NO;
    }
    return YES;
}

/**
 * @warning This is called from a `@synchronized` context in instance methods, but doesn't require
 * that when calling from other static functions. Make sure you pay attention to where this is used
 * from.
 */
void
_non_thread_safe_removeFileAtPath(NSString *path)
{
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager removeItemAtPath:path error:&error]) {
        if (error.code == NSFileNoSuchFileError) {
            SENTRY_LOG_DEBUG(@"No file to delete at %@", path);
        } else {
            SENTRY_LOG_ERROR(
                @"Error occurred while deleting file at %@ because of %@", path, error);
        }
    } else {
        SENTRY_LOG_DEBUG(@"Successfully deleted file at %@", path);
    }
}

@interface
SentryFileManager ()

@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;
@property (nonatomic, copy) NSString *basePath;
@property (nonatomic, copy) NSString *sentryPath;
@property (nonatomic, copy) NSString *eventsPath;
@property (nonatomic, copy) NSString *envelopesPath;
@property (nonatomic, copy) NSString *currentSessionFilePath;
@property (nonatomic, copy) NSString *crashedSessionFilePath;
@property (nonatomic, copy) NSString *lastInForegroundFilePath;
@property (nonatomic, copy) NSString *previousAppStateFilePath;
@property (nonatomic, copy) NSString *appStateFilePath;
@property (nonatomic, copy) NSString *previousBreadcrumbsFilePathOne;
@property (nonatomic, copy) NSString *previousBreadcrumbsFilePathTwo;
@property (nonatomic, copy) NSString *breadcrumbsFilePathOne;
@property (nonatomic, copy) NSString *breadcrumbsFilePathTwo;
@property (nonatomic, copy) NSString *timezoneOffsetFilePath;
@property (nonatomic, assign) NSUInteger currentFileCounter;
@property (nonatomic, assign) NSUInteger maxEnvelopes;
@property (nonatomic, weak) id<SentryFileManagerDelegate> delegate;

@end

@implementation SentryFileManager

- (nullable instancetype)initWithOptions:(SentryOptions *)options error:(NSError **)error
{
    return [self initWithOptions:options
            dispatchQueueWrapper:SentryDependencyContainer.sharedInstance.dispatchQueueWrapper
                           error:error];
}

- (nullable instancetype)initWithOptions:(SentryOptions *)options
                    dispatchQueueWrapper:(SentryDispatchQueueWrapper *)dispatchQueueWrapper
                                   error:(NSError **)error
{
    if (self = [super init]) {
        self.dispatchQueue = dispatchQueueWrapper;
        [self createPathsWithOptions:options];

        // Remove old cached events for versions before 6.0.0
        self.eventsPath = [self.sentryPath stringByAppendingPathComponent:@"events"];
        [self removeFileAtPath:self.eventsPath];

        if (!createDirectoryIfNotExists(self.sentryPath, error)) {
            return nil;
        }
        if (!createDirectoryIfNotExists(self.envelopesPath, error)) {
            return nil;
        }
#if SENTRY_TARGET_PROFILING_SUPPORTED
        if (!createDirectoryIfNotExists(sentryApplicationSupportPath(), error)) {
            return nil;
        }
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

        self.currentFileCounter = 0;
        self.maxEnvelopes = options.maxCacheItems;
    }
    return self;
}

- (void)setDelegate:(id<SentryFileManagerDelegate>)delegate
{
    _delegate = delegate;
}

- (void)deleteOldEnvelopeItems
{
    __weak SentryFileManager *weakSelf = self;
    [self.dispatchQueue dispatchAsyncWithBlock:^{
        if (weakSelf == nil) {
            return;
        }
        SENTRY_LOG_DEBUG(@"Dispatched deletion of old envelopes from %@", weakSelf);
        [weakSelf deleteOldEnvelopesFromAllSentryPaths];
    }];
}

- (void)deleteAllFolders
{
    [self removeFileAtPath:self.sentryPath];
}

- (NSString *)uniqueAscendingJsonName
{
    // %f = double
    // %05lu = unsigned with always 5 digits and leading zeros if number is too small. We
    //      need this because otherwise 10 would be sorted before 2 for example.
    // %@ = NSString
    // For example 978307200.000000-00001-3FE8C3AE-EB9C-4BEB-868C-14B8D47C33DD.json
    return [NSString
        stringWithFormat:@"%f-%05lu-%@.json",
        [[SentryDependencyContainer.sharedInstance.dateProvider date] timeIntervalSince1970],
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

// Delete every envelope in self.basePath older than 90 days,
// as Sentry only retains data for 90 days.
- (void)deleteOldEnvelopesFromAllSentryPaths
{
    // First we find all directories in the base path, these are all the various hashed DSN paths
    for (NSString *filePath in [self allFilesInFolder:self.basePath]) {
        NSString *envelopesPath = [self getEnvelopesPath:filePath];

        // Then we will remove all old items from the envelopes subdirectory
        [self deleteOldEnvelopesFromPath:envelopesPath];
    }
}

- (nullable NSString *)getEnvelopesPath:(NSString *)filePath
{
    NSString *fullPath = [self.basePath stringByAppendingPathComponent:filePath];

    if ([fullPath hasSuffix:@".DS_Store"]) {
        SENTRY_LOG_DEBUG(
            @"Ignoring .DS_Store file when building envelopes path at path: %@", fullPath);
        return nil;
    }

    NSError *error = nil;
    NSDictionary *dict = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath
                                                                          error:&error];
    if (error != nil) {
        SENTRY_LOG_WARN(
            @"Could not get attributes of item at path: %@. Error: %@", fullPath, error);
        return nil;
    }

    if (dict[NSFileType] != NSFileTypeDirectory) {
        SENTRY_LOG_DEBUG(
            @"Ignoring non directory when deleting old envelopes at path: %@", fullPath);
        return nil;
    }

    // If the options don't have a DSN the sentry path doesn't contain a hash and the envelopes
    // folder is stored in the base path.
    NSString *envelopesPath;
    if ([fullPath hasSuffix:EnvelopesPathComponent]) {
        envelopesPath = fullPath;
    } else {
        envelopesPath = [fullPath stringByAppendingPathComponent:EnvelopesPathComponent];
    }

    return envelopesPath;
}

- (void)deleteOldEnvelopesFromPath:(NSString *)envelopesPath
{
    NSTimeInterval now =
        [[SentryDependencyContainer.sharedInstance.dateProvider date] timeIntervalSince1970];

    for (NSString *path in [self allFilesInFolder:envelopesPath]) {
        NSString *fullPath = [envelopesPath stringByAppendingPathComponent:path];
        NSDictionary *dict = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath
                                                                              error:nil];
        if (!dict || !dict[NSFileCreationDate]) {
            SENTRY_LOG_WARN(@"Could not get NSFileCreationDate from %@", fullPath);
            continue;
        }

        NSTimeInterval age = now - [dict[NSFileCreationDate] timeIntervalSince1970];
        if (age > 90 * 24 * 60 * 60) {
            [self removeFileAtPath:fullPath];
            SENTRY_LOG_DEBUG(
                @"Removed envelope at path %@ because it was older than 90 days", fullPath);
        }
    }
}

- (void)deleteAllEnvelopes
{
    [self removeFileAtPath:self.envelopesPath];
    NSError *error;
    if (!createDirectoryIfNotExists(self.envelopesPath, &error)) {
        SENTRY_LOG_ERROR(@"Couldn't create envelopes path.");
    }
}

- (NSArray<NSString *> *)allFilesInFolder:(NSString *)path
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:path]) {
        SENTRY_LOG_INFO(@"Returning empty files list, as folder doesn't exist at path: %@", path);
        return @[];
    }

    NSError *error = nil;
    NSArray<NSString *> *storedFiles = [fileManager contentsOfDirectoryAtPath:path error:&error];
    if (error != nil) {
        SENTRY_LOG_ERROR(@"Couldn't load files in folder %@: %@", path, error);
        return @[];
    }
    return [storedFiles sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (void)removeFileAtPath:(NSString *)path
{
    @synchronized(self) {
        _non_thread_safe_removeFileAtPath(path);
    }
}

- (NSString *)storeEnvelope:(SentryEnvelope *)envelope
{
    NSData *envelopeData = [SentrySerialization dataWithEnvelope:envelope error:nil];

    @synchronized(self) {
        NSString *path =
            [self.envelopesPath stringByAppendingPathComponent:[self uniqueAscendingJsonName]];
        SENTRY_LOG_DEBUG(@"Writing envelope to path: %@", path);

        if (![self writeData:envelopeData toPath:path]) {
            SENTRY_LOG_WARN(@"Failed to store envelope.");
        }

        [self handleEnvelopesLimit];
        return path;
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

        NSData *envelopeData = [[NSFileManager defaultManager] contentsAtPath:envelopeFilePath];
        SentryEnvelope *envelope = [SentrySerialization envelopeWithData:envelopeData];

        BOOL didMigrateSessionInit =
            [SentryMigrateSessionInit migrateSessionInit:envelope
                                        envelopesDirPath:self.envelopesPath
                                       envelopeFilePaths:envelopePathsCopy];

        for (SentryEnvelopeItem *item in envelope.items) {
            SentryDataCategory rateLimitCategory
                = sentryDataCategoryForEnvelopItemType(item.header.type);

            // When migrating the session init, the envelope to delete still contains the session
            // migrated to another envelope. Therefore, the envelope item is not deleted but
            // migrated.
            if (didMigrateSessionInit && rateLimitCategory == kSentryDataCategorySession) {
                continue;
            }

            [_delegate envelopeItemDeleted:item withCategory:rateLimitCategory];
        }

        [self removeFileAtPath:envelopeFilePath];
    }

    SENTRY_LOG_DEBUG(@"Removed %ld file(s) from <%@>", (long)numberOfEnvelopesToRemove,
        [self.envelopesPath lastPathComponent]);
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
    NSData *sessionData = [SentrySerialization dataWithSession:session];
    SENTRY_LOG_DEBUG(@"Writing session: %@", sessionFilePath);
    @synchronized(self.currentSessionFilePath) {
        if (![self writeData:sessionData toPath:sessionFilePath]) {
            SENTRY_LOG_WARN(@"Failed to write session data.");
        }
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
    SENTRY_LOG_DEBUG(@"Deleting session: %@", sessionFilePath);
    @synchronized(self.currentSessionFilePath) {
        [self removeFileAtPath:sessionFilePath];
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

- (nullable SentrySession *)readSession:(NSString *)sessionFilePath
{
    [SentryLog
        logWithMessage:[NSString stringWithFormat:@"Reading from session: %@", sessionFilePath]
              andLevel:kSentryLevelDebug];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSData *currentData = nil;
    @synchronized(self.currentSessionFilePath) {
        currentData = [fileManager contentsAtPath:sessionFilePath];
        if (nil == currentData) {
            SENTRY_LOG_WARN(@"No data found at %@", sessionFilePath);
            return nil;
        }
    }
    SentrySession *currentSession = [SentrySerialization sessionWithData:currentData];
    if (nil == currentSession) {
        SENTRY_LOG_ERROR(
            @"Data stored in session: '%@' was not parsed as session.", sessionFilePath);
        return nil;
    }
    return currentSession;
}

- (void)storeTimestampLastInForeground:(NSDate *)timestamp
{
    NSString *timestampString = sentry_toIso8601String(timestamp);
    SENTRY_LOG_DEBUG(@"Persisting lastInForeground: %@", timestampString);
    @synchronized(self.lastInForegroundFilePath) {
        if (![self writeData:[timestampString dataUsingEncoding:NSUTF8StringEncoding]
                      toPath:self.lastInForegroundFilePath]) {
            SENTRY_LOG_WARN(@"Failed to store timestamp of last foreground event.");
        }
    }
}

- (void)deleteTimestampLastInForeground
{
    SENTRY_LOG_DEBUG(@"Deleting LastInForeground at: %@", self.lastInForegroundFilePath);
    @synchronized(self.lastInForegroundFilePath) {
        [self removeFileAtPath:self.lastInForegroundFilePath];
    }
}

- (NSDate *_Nullable)readTimestampLastInForeground
{
    SENTRY_LOG_DEBUG(
        @"Reading timestamp of last in foreground at: %@", self.lastInForegroundFilePath);
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSData *lastInForegroundData = nil;
    @synchronized(self.lastInForegroundFilePath) {
        lastInForegroundData = [fileManager contentsAtPath:self.lastInForegroundFilePath];
    }
    if (nil == lastInForegroundData) {
        SENTRY_LOG_DEBUG(@"No lastInForeground found.");
        return nil;
    }
    NSString *timestampString = [[NSString alloc] initWithData:lastInForegroundData
                                                      encoding:NSUTF8StringEncoding];
    return sentry_fromIso8601String(timestampString);
}

- (BOOL)writeData:(NSData *)data toPath:(NSString *)path
{
    NSError *error;
    if (!createDirectoryIfNotExists(self.sentryPath, &error)) {
        SENTRY_LOG_ERROR(@"File I/O not available at path %@: %@", path, error);
        return NO;
    }
    if (![data writeToFile:path options:NSDataWritingAtomic error:&error]) {
        SENTRY_LOG_ERROR(@"Failed to write data to path %@: %@", path, error);
        return NO;
    }
    return YES;
}

- (void)storeAppState:(SentryAppState *)appState
{
    NSData *data = [SentrySerialization dataWithJSONObject:[appState serialize]];

    if (data == nil) {
        SENTRY_LOG_ERROR(@"Failed to store app state, because of an error in serialization");
        return;
    }

    @synchronized(self.appStateFilePath) {
        if (![self writeData:data toPath:self.appStateFilePath]) {
            SENTRY_LOG_WARN(@"Failed to store app state.");
        }
    }
}

- (void)moveAppStateToPreviousAppState
{
    @synchronized(self.appStateFilePath) {
        [self moveState:self.appStateFilePath toPreviousState:self.previousAppStateFilePath];
    }
}

- (void)moveBreadcrumbsToPreviousBreadcrumbs
{
    @synchronized(self.breadcrumbsFilePathOne) {
        [self moveState:self.breadcrumbsFilePathOne
            toPreviousState:self.previousBreadcrumbsFilePathOne];
        [self moveState:self.breadcrumbsFilePathTwo
            toPreviousState:self.previousBreadcrumbsFilePathTwo];
    }
}

- (void)moveState:(NSString *)stateFilePath toPreviousState:(NSString *)previousStateFilePath
{
    SENTRY_LOG_DEBUG(@"Moving state %@ to previous %@.", stateFilePath, previousStateFilePath);
    NSFileManager *fileManager = [NSFileManager defaultManager];

    // We first need to remove the old previous state file,
    // or we can't move the current state file to it.
    [self removeFileAtPath:previousStateFilePath];
    NSError *error = nil;
    if (![fileManager moveItemAtPath:stateFilePath toPath:previousStateFilePath error:&error]) {
        // We don't want to log an error if the file doesn't exist.
        if (nil != error && error.code != NSFileNoSuchFileError) {
            SENTRY_LOG_ERROR(@"Failed to move %@ to previous state file: %@", stateFilePath, error);
        }
    }
}

- (NSArray *)readPreviousBreadcrumbs
{
    NSArray *fileOneLines = @[];
    NSArray *fileTwoLines = @[];

    if ([[NSFileManager defaultManager] fileExistsAtPath:self.previousBreadcrumbsFilePathOne]) {
        NSString *fileContents =
            [NSString stringWithContentsOfFile:self.previousBreadcrumbsFilePathOne
                                      encoding:NSUTF8StringEncoding
                                         error:nil];
        fileOneLines = [fileContents
            componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    }

    if ([[NSFileManager defaultManager] fileExistsAtPath:self.previousBreadcrumbsFilePathTwo]) {
        NSString *fileContents =
            [NSString stringWithContentsOfFile:self.previousBreadcrumbsFilePathTwo
                                      encoding:NSUTF8StringEncoding
                                         error:nil];
        fileTwoLines = [fileContents
            componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    }

    NSMutableArray *breadcrumbs = [NSMutableArray array];

    if (fileOneLines.count > 0 || fileTwoLines.count > 0) {
        NSArray *combinedLines;

        if (fileOneLines.count > fileTwoLines.count) {
            // If file one has more lines than file two, then file one contains the older crumbs,
            // and thus needs to come first.
            combinedLines = [fileOneLines arrayByAddingObjectsFromArray:fileTwoLines];
        } else {
            combinedLines = [fileTwoLines arrayByAddingObjectsFromArray:fileOneLines];
        }

        for (NSString *line in combinedLines) {
            NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];

            if (data == nil) {
                SENTRY_LOG_WARN(@"Received nil data from breadcrumb file.");
                continue;
            }

            NSError *error;
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data
                                                                 options:0
                                                                   error:&error];

            if (error) {
                SENTRY_LOG_ERROR(@"Error deserializing breadcrumb: %@", error);
            } else {
                [breadcrumbs addObject:dict];
            }
        }
    }

    return breadcrumbs;
}

- (SentryAppState *_Nullable)readAppState
{
    @synchronized(self.appStateFilePath) {
        return [self readAppStateFrom:self.appStateFilePath];
    }
}

- (SentryAppState *_Nullable)readPreviousAppState
{
    @synchronized(self.previousAppStateFilePath) {
        return [self readAppStateFrom:self.previousAppStateFilePath];
    }
}

- (SentryAppState *_Nullable)readAppStateFrom:(NSString *)path
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSData *currentData = [fileManager contentsAtPath:path];
    if (nil == currentData) {
        SENTRY_LOG_WARN(@"No app state data found at %@", path);
        return nil;
    }
    return [SentrySerialization appStateWithData:currentData];
}

- (void)deleteAppState
{
    @synchronized(self.appStateFilePath) {
        [self deleteAppStateFrom:self.appStateFilePath];
        [self deleteAppStateFrom:self.previousAppStateFilePath];
    }
}

- (void)deleteAppStateFrom:(NSString *)path
{
    [self removeFileAtPath:path];
}

- (NSNumber *_Nullable)readTimezoneOffset
{
    SENTRY_LOG_DEBUG(@"Reading timezone offset");
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSData *timezoneOffsetData = nil;
    @synchronized(self.timezoneOffsetFilePath) {
        timezoneOffsetData = [fileManager contentsAtPath:self.timezoneOffsetFilePath];
    }
    if (nil == timezoneOffsetData) {
        SENTRY_LOG_DEBUG(@"No timezone offset found.");
        return nil;
    }
    NSString *timezoneOffsetString = [[NSString alloc] initWithData:timezoneOffsetData
                                                           encoding:NSUTF8StringEncoding];

    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;

    return [formatter numberFromString:timezoneOffsetString];
}

- (void)storeTimezoneOffset:(NSInteger)offset
{
    NSString *timezoneOffsetString = [NSString stringWithFormat:@"%ld", (long)offset];
    SENTRY_LOG_DEBUG(@"Persisting timezone offset: %@", timezoneOffsetString);
    @synchronized(self.timezoneOffsetFilePath) {
        if (![self writeData:[timezoneOffsetString dataUsingEncoding:NSUTF8StringEncoding]
                      toPath:self.timezoneOffsetFilePath]) {
            SENTRY_LOG_WARN(@"Failed to store timezone offset.");
        }
    }
}

- (void)deleteTimezoneOffset
{
    @synchronized(self.timezoneOffsetFilePath) {
        [self removeFileAtPath:self.timezoneOffsetFilePath];
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

- (void)createPathsWithOptions:(SentryOptions *)options
{
    NSString *cachePath = options.cacheDirectoryPath;

    SENTRY_LOG_DEBUG(@"SentryFileManager.cachePath: %@", cachePath);

    self.basePath = [cachePath stringByAppendingPathComponent:@"io.sentry"];
    self.sentryPath = [self.basePath stringByAppendingPathComponent:[options.parsedDsn getHash]];
    self.currentSessionFilePath =
        [self.sentryPath stringByAppendingPathComponent:@"session.current"];
    self.crashedSessionFilePath =
        [self.sentryPath stringByAppendingPathComponent:@"session.crashed"];
    self.lastInForegroundFilePath =
        [self.sentryPath stringByAppendingPathComponent:@"lastInForeground.timestamp"];
    self.previousAppStateFilePath =
        [self.sentryPath stringByAppendingPathComponent:@"previous.app.state"];
    self.appStateFilePath = [self.sentryPath stringByAppendingPathComponent:@"app.state"];
    self.previousBreadcrumbsFilePathOne =
        [self.sentryPath stringByAppendingPathComponent:@"previous.breadcrumbs.1.state"];
    self.previousBreadcrumbsFilePathTwo =
        [self.sentryPath stringByAppendingPathComponent:@"previous.breadcrumbs.2.state"];
    self.breadcrumbsFilePathOne =
        [self.sentryPath stringByAppendingPathComponent:@"breadcrumbs.1.state"];
    self.breadcrumbsFilePathTwo =
        [self.sentryPath stringByAppendingPathComponent:@"breadcrumbs.2.state"];
    self.timezoneOffsetFilePath =
        [self.sentryPath stringByAppendingPathComponent:@"timezone.offset"];
    self.envelopesPath = [self.sentryPath stringByAppendingPathComponent:EnvelopesPathComponent];
}

/**
 * @note This method must be statically accessible because it will be called during app launch,
 * before any instance of @c SentryFileManager exists, and so wouldn't be able to access this path
 * from an objc property on it like the other paths.
 */
NSString *_Nullable sentryApplicationSupportPath(void)
{
    static NSString *_Nullable sentryApplicationSupportPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *paths = NSSearchPathForDirectoriesInDomains(
            NSApplicationSupportDirectory, NSUserDomainMask, YES);
        NSString *applicationSupportDirectory = [paths firstObject];
        if (applicationSupportDirectory == nil) {
            SENTRY_LOG_WARN(@"No application support directory location reported.");
            return;
        }
        sentryApplicationSupportPath =
            [applicationSupportDirectory stringByAppendingPathComponent:@"io.sentry"];
    });
    return sentryApplicationSupportPath;
}

#if SENTRY_TARGET_PROFILING_SUPPORTED

NSURL *_Nullable sentryLaunchConfigFileURL = nil;

NSURL *_Nullable launchProfileConfigFileURL(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *appSupportPath = sentryApplicationSupportPath();
        if (appSupportPath == nil) {
            SENTRY_LOG_WARN(@"No location available to write a launch profiling config.");
            return;
        }
        sentryLaunchConfigFileURL = [NSURL
            fileURLWithPath:[appSupportPath stringByAppendingPathComponent:@"profileLaunch"]];
    });
    return sentryLaunchConfigFileURL;
}

NSDictionary<NSString *, NSNumber *> *_Nullable appLaunchProfileConfiguration(void)
{
    NSURL *url = launchProfileConfigFileURL();
    if (![[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        return nil;
    }

    NSError *error;
    NSDictionary<NSString *, NSNumber *> *config =
        [NSDictionary<NSString *, NSNumber *> dictionaryWithContentsOfURL:url error:&error];
    SENTRY_CASSERT(
        error == nil, @"Encountered error trying to retrieve app launch profile config: %@", error);
    return config;
}

BOOL
appLaunchProfileConfigFileExists(void)
{
    NSString *path = launchProfileConfigFileURL().path;
    if (path == nil) {
        return NO;
    }

    return access(path.UTF8String, F_OK) == 0;
}

void
writeAppLaunchProfilingConfigFile(NSMutableDictionary<NSString *, NSNumber *> *config)
{
    NSError *error;
    SENTRY_CASSERT([config writeToURL:launchProfileConfigFileURL() error:&error],
        @"Failed to write launch profile config file: %@.", error);
}

void
removeAppLaunchProfilingConfigFile(void)
{
    _non_thread_safe_removeFileAtPath(launchProfileConfigFileURL().path);
}
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

- (void)clearDiskState
{
    [self removeFileAtPath:self.basePath];
#if SENTRY_TARGET_PROFILING_SUPPORTED
    [self removeFileAtPath:sentryApplicationSupportPath()];
#endif // SENTRY_TARGET_PROFILING_SUPPORTED
}

@end

NS_ASSUME_NONNULL_END
