#import "SentryFileManager.h"
#import "SentryAppState.h"
#import "SentryDataCategoryMapper.h"
#import "SentryDateUtils.h"
#import "SentryDependencyContainer.h"
#import "SentryDsn.h"
#import "SentryEnvelope.h"
#import "SentryEnvelopeItemHeader.h"
#import "SentryError.h"
#import "SentryEvent.h"
#import "SentryInternalDefines.h"
#import "SentryLogC.h"
#import "SentryMigrateSessionInit.h"
#import "SentryOptions.h"
#import "SentrySerialization.h"
#import "SentrySwift.h"

NS_ASSUME_NONNULL_BEGIN

NSString *const EnvelopesPathComponent = @"envelopes";

#pragma mark - Helper Methods

BOOL
isErrorPathTooLong(NSError *error)
{
    NSError *underlyingError = NULL;
    if (@available(macOS 11.3, iOS 14.5, watchOS 7.4, tvOS 14.5, *)) {
        underlyingError = error.underlyingErrors.firstObject;
    }
    if (underlyingError == NULL) {
        id errorInUserInfo = [error.userInfo valueForKey:NSUnderlyingErrorKey];
        if (errorInUserInfo && [errorInUserInfo isKindOfClass:[NSError class]]) {
            underlyingError = errorInUserInfo;
        }
    }
    if (underlyingError == NULL) {
        underlyingError = error;
    }
    BOOL isEnameTooLong
        = underlyingError.domain == NSPOSIXErrorDomain && underlyingError.code == ENAMETOOLONG;
    // On older OS versions the error code is NSFileWriteUnknown
    // Reference: https://developer.apple.com/forums/thread/128927?answerId=631839022#631839022
    BOOL isUnknownError = underlyingError.domain == NSCocoaErrorDomain
        && underlyingError.code == NSFileWriteUnknownError;

    return isEnameTooLong || isUnknownError;
}

BOOL
createDirectoryIfNotExists(NSString *path, NSError **error)
{
    BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:path
                                             withIntermediateDirectories:YES
                                                              attributes:nil
                                                                   error:error];
    if (success) {
        return YES;
    }

    if (isErrorPathTooLong(*error)) {
        SENTRY_LOG_FATAL(@"Failed to create directory, path is too long: %@", path);
    }
    *error = NSErrorFromSentryErrorWithUnderlyingError(kSentryErrorFileIO,
        [NSString stringWithFormat:@"Failed to create the directory at path %@.", path], *error);
    return NO;
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
    if ([fileManager removeItemAtPath:path error:&error]) {
        SENTRY_LOG_DEBUG(@"Successfully deleted file at %@", path);
    } else if (error.code == NSFileNoSuchFileError) {
        SENTRY_LOG_DEBUG(@"No file to delete at %@", path);
    } else if (isErrorPathTooLong(error)) {
        SENTRY_LOG_FATAL(@"Failed to remove file, path is too long: %@", path);
    } else {
        SENTRY_LOG_ERROR(@"Error occurred while deleting file at %@ because of %@", path, error);
    }
}

#pragma mark - SentryFileManager

@interface SentryFileManager ()

@property (nonatomic, strong) SentryDispatchQueueWrapper *dispatchQueue;
@property (nonatomic, copy) NSString *basePath;
@property (nonatomic, copy) NSString *sentryPath;
@property (nonatomic, copy) NSString *eventsPath;
@property (nonatomic, copy) NSString *envelopesPath;
@property (nonatomic, copy) NSString *currentSessionFilePath;
@property (nonatomic, copy) NSString *crashedSessionFilePath;
@property (nonatomic, copy) NSString *abnormalSessionFilePath;
@property (nonatomic, copy) NSString *lastInForegroundFilePath;
@property (nonatomic, copy) NSString *previousAppStateFilePath;
@property (nonatomic, copy) NSString *appStateFilePath;
@property (nonatomic, copy) NSString *previousBreadcrumbsFilePathOne;
@property (nonatomic, copy) NSString *previousBreadcrumbsFilePathTwo;
@property (nonatomic, copy) NSString *breadcrumbsFilePathOne;
@property (nonatomic, copy) NSString *breadcrumbsFilePathTwo;
@property (nonatomic, copy) NSString *timezoneOffsetFilePath;
@property (nonatomic, copy) NSString *appHangEventFilePath;
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
            SENTRY_LOG_FATAL(@"Failed to create Sentry SDK working directory: %@", self.sentryPath);
            return nil;
        }
        if (!createDirectoryIfNotExists(self.envelopesPath, error)) {
            SENTRY_LOG_FATAL(
                @"Failed to create Sentry SDK envelopes directory: %@", self.envelopesPath);
            return nil;
        }

        self.currentFileCounter = 0;
        self.maxEnvelopes = options.maxCacheItems;
    }
    return self;
}

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
    self.abnormalSessionFilePath =
        [self.sentryPath stringByAppendingPathComponent:@"session.abnormal"];
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
    self.appHangEventFilePath =
        [self.sentryPath stringByAppendingPathComponent:@"app.hang.event.json"];
    self.envelopesPath = [self.sentryPath stringByAppendingPathComponent:EnvelopesPathComponent];
}

- (void)setDelegate:(id<SentryFileManagerDelegate>)delegate
{
    _delegate = delegate;
}

#pragma mark - Convenience Accessors

- (NSURL *)getSentryPathAsURL
{
    return [NSURL fileURLWithPath:self.sentryPath];
}

#pragma mark - Envelope

- (nullable NSString *)storeEnvelope:(SentryEnvelope *)envelope
{
    NSData *envelopeData = [SentrySerialization dataWithEnvelope:envelope];

    if (envelopeData == nil) {
        SENTRY_LOG_ERROR(@"Serialization of envelope failed. Can't store envelope.");
        return nil;
    }

    @synchronized(self) {
        NSString *path =
            [self.envelopesPath stringByAppendingPathComponent:[self uniqueAscendingJsonName]];
        SENTRY_LOG_DEBUG(@"Writing envelope to path: %@", path);

        if (![self writeData:envelopeData toPath:path]) {
            SENTRY_LOG_WARN(@"Failed to store envelope.");
            return nil;
        }

        [self handleEnvelopesLimit];
        return path;
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

- (void)deleteAllEnvelopes
{
    [self removeFileAtPath:self.envelopesPath];
    NSError *error;
    if (!createDirectoryIfNotExists(self.envelopesPath, &error)) {
        SENTRY_LOG_ERROR(@"Couldn't create envelopes path.");
    }
}

#pragma mark - Session

- (void)storeCurrentSession:(SentrySession *)session
{
    [self storeSession:session sessionFilePath:self.currentSessionFilePath];
}

- (SentrySession *_Nullable)readCurrentSession
{
    return [self readSession:self.currentSessionFilePath];
}

- (void)deleteCurrentSession
{
    [self deleteSession:self.currentSessionFilePath];
}

- (void)storeCrashedSession:(SentrySession *)session
{
    [self storeSession:session sessionFilePath:self.crashedSessionFilePath];
}

- (SentrySession *_Nullable)readCrashedSession
{
    return [self readSession:self.crashedSessionFilePath];
}

- (void)deleteCrashedSession
{
    [self deleteSession:self.crashedSessionFilePath];
}

- (void)storeAbnormalSession:(SentrySession *)session
{
    [self storeSession:session sessionFilePath:self.abnormalSessionFilePath];
}

- (SentrySession *_Nullable)readAbnormalSession
{
    return [self readSession:self.abnormalSessionFilePath];
}

- (void)deleteAbnormalSession
{
    [self deleteSession:self.abnormalSessionFilePath];
}

#pragma mark - LastInForeground

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

#pragma mark - App State

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

- (void)deleteAppState
{
    @synchronized(self.appStateFilePath) {
        [self deleteAppStateFrom:self.appStateFilePath];
        [self deleteAppStateFrom:self.previousAppStateFilePath];
    }
}

#pragma mark - Breadcrumbs

- (void)moveBreadcrumbsToPreviousBreadcrumbs
{
    @synchronized(self.breadcrumbsFilePathOne) {
        [self moveState:self.breadcrumbsFilePathOne
            toPreviousState:self.previousBreadcrumbsFilePathOne];
        [self moveState:self.breadcrumbsFilePathTwo
            toPreviousState:self.previousBreadcrumbsFilePathTwo];
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

#pragma mark - TimezoneOffset

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

#pragma mark - AppHangs

- (void)storeAppHangEvent:(SentryEvent *)appHangEvent
{
    NSData *jsonData = [SentrySerialization dataWithJSONObject:[appHangEvent serialize]];
    if (jsonData == nil) {
        SENTRY_LOG_ERROR(@"Failed to store app hang event, because of an error in serialization.");
        return;
    }

    @synchronized(self.appHangEventFilePath) {
        [self writeData:jsonData toPath:self.appHangEventFilePath];
    }
}

- (nullable SentryEvent *)readAppHangEvent
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSData *appHangEventJSONData = nil;
    @synchronized(self.appHangEventFilePath) {
        appHangEventJSONData = [fileManager contentsAtPath:self.appHangEventFilePath];
    }
    if (nil == appHangEventJSONData) {
        SENTRY_LOG_DEBUG(@"No app hang event found.");
        return nil;
    }

    return [SentryEventDecoder decodeEventWithJsonData:appHangEventJSONData];
}

- (BOOL)appHangEventExists
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    @synchronized(self.appHangEventFilePath) {
        return [fileManager fileExistsAtPath:self.appHangEventFilePath];
    }
}

- (void)deleteAppHangEvent
{
    @synchronized(self.appHangEventFilePath) {
        [self removeFileAtPath:self.appHangEventFilePath];
    }
}

#pragma mark - File Operations

+ (BOOL)createDirectoryAtPath:(NSString *)path withError:(NSError **)error
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return [fileManager createDirectoryAtPath:path
                  withIntermediateDirectories:YES
                                   attributes:nil
                                        error:error];
}

- (nullable NSData *)readDataFromPath:(NSString *)path
                                error:(NSError *__autoreleasing _Nullable *)error
{
    return [NSData dataWithContentsOfFile:path options:0 error:error];
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

- (void)deleteAllFolders
{
    [self removeFileAtPath:self.sentryPath];
}

- (void)removeFileAtPath:(NSString *)path
{
    @synchronized(self) {
        _non_thread_safe_removeFileAtPath(path);
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

- (BOOL)isDirectory:(NSString *)path
{
    BOOL isDir = NO;
    return [NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDir] && isDir;
}

/**
 * @note This method must be statically accessible because it will be called during app launch,
 * before any instance of  ``SentryFileManager`` exists, and so wouldn't be able to access this path
 * from an objc property on it like the other paths.
 */
NSString *_Nullable sentryStaticCachesPath(void)
{
    static NSString *_Nullable sentryStaticCachesPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // We request the users cache directory from Foundation.
        // For iOS apps and macOS apps with sandboxing, this path will be scoped for the current
        // app. For macOS apps without sandboxing, this path is not scoped and will be shared
        // between all apps.
        NSString *_Nullable cachesDirectory
            = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)
                  .firstObject;
        if (cachesDirectory == nil) {
            SENTRY_LOG_WARN(@"No caches directory location reported.");
            return;
        }

        // We need to ensure our own scoped directory so that this path is not shared between other
        // apps on the same system.
        NSString *_Nullable scopedCachesDirectory = sentryGetScopedCachesDirectory(cachesDirectory);
        if (!scopedCachesDirectory) {
            SENTRY_LOG_WARN(@"Failed to get scoped static caches directory.");
            return;
        }
        sentryStaticCachesPath = scopedCachesDirectory;
        SENTRY_LOG_DEBUG(@"Using static cache directory: %@", sentryStaticCachesPath);
    });
    return sentryStaticCachesPath;
}

NSString *_Nullable sentryGetScopedCachesDirectory(NSString *cachesDirectory)
{
#if !TARGET_OS_OSX
    // iOS apps are always sandboxed, therefore we can just early-return with the provided caches
    // directory.
    return cachesDirectory;
#else

    // For macOS apps, we need to ensure our own sandbox so that this path is not shared between
    // all apps that ship the SDK.

    // We can not use the SentryNSProcessInfoWrapper here because this method is called before
    // the SentryDependencyContainer is initialized.
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];

    // Only apps running in a sandboxed environment have the `APP_SANDBOX_CONTAINER_ID` set as a
    // process environment variable. Reference implementation:
    // https://github.com/realm/realm-js/blob/a03127726939f08f608edbdb2341605938f25708/packages/realm/binding/apple/platform.mm#L58-L74
    BOOL isSandboxed = processInfo.environment[@"APP_SANDBOX_CONTAINER_ID"] != nil;

    // The bundle identifier is used to create a unique cache directory for the app.
    // If the bundle identifier is not available, we use the name of the executable.
    // Note: `SentryCrash.getBundleName` is using `CFBundleName` to create a scoped directory.
    //       That value can be absent, therefore we use a more stable approach here.
    NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    NSString *lastPathComponent = [[[NSBundle mainBundle] executablePath] lastPathComponent];

    // Due to `NSProcessInfo` and `NSBundle` not being mockable in unit tests, we extract only the
    // logic to a separate function.
    return sentryBuildScopedCachesDirectoryPath(
        cachesDirectory, isSandboxed, bundleIdentifier, lastPathComponent);
#endif
}

NSString *_Nullable sentryBuildScopedCachesDirectoryPath(NSString *cachesDirectory,
    BOOL isSandboxed, NSString *_Nullable bundleIdentifier, NSString *_Nullable lastPathComponent)
{
    // If the app is sandboxed, we can just use the provided caches directory.
    if (isSandboxed) {
        return cachesDirectory;
    }

    // If the macOS app is not sandboxed, we need to manually create a scoped cache
    // directory. The cache path must be unique an stable over app launches, therefore we
    // can not use any changing identifier.
    SENTRY_LOG_DEBUG(
        @"App is not sandboxed, extending default cache directory with bundle identifier.");
    NSString *_Nullable identifier = bundleIdentifier;
    if (identifier == nil) {
        SENTRY_LOG_WARN(@"No bundle identifier found, using main bundle executable name.");
        identifier = lastPathComponent;
    } else if (identifier.length == 0) {
        SENTRY_LOG_WARN(@"Bundle identifier exists but is zero length, using main bundle "
                        @"executable name.");
        identifier = lastPathComponent;
    }

    // If neither the bundle identifier nor the executable name are available, we can't
    // create a unique and stable cache directory.
    // We do not fall back to any default path, because it could be shared with other apps
    // and cause leaks impacting other apps.
    if (identifier == nil) {
        SENTRY_LOG_ERROR(@"No bundle identifier found, cannot create cache directory.");
        return nil;
    }

    // It's unlikely that the executable name will be zero length, but we'll cover this case anyways
    if (identifier.length == 0) {
        SENTRY_LOG_ERROR(@"Executable name was zero length.");
        return nil;
    }

    return [cachesDirectory stringByAppendingPathComponent:identifier];
}

NSString *_Nullable sentryStaticBasePath(void)
{
    static NSString *_Nullable sentryStaticBasePath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *cachesDirectory = sentryStaticCachesPath();
        if (cachesDirectory == nil) {
            SENTRY_LOG_WARN(@"No caches directory location reported.");
            return;
        }
        sentryStaticBasePath = [cachesDirectory stringByAppendingPathComponent:@"io.sentry"];
    });
    return sentryStaticBasePath;
}

#if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
void
removeSentryStaticBasePath(void)
{
    _non_thread_safe_removeFileAtPath(sentryStaticBasePath());
}
#endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

#pragma mark - Profiling

#if SENTRY_TARGET_PROFILING_SUPPORTED

NSURL *_Nullable sentryLaunchConfigFileURL = nil;

NSURL *_Nullable launchProfileConfigFileURL(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *basePath = sentryStaticBasePath();
        if (basePath == nil) {
            SENTRY_LOG_WARN(@"No location available to write a launch profiling config.");
            return;
        }
        NSError *error;
        if (!createDirectoryIfNotExists(basePath, &error)) {
            SENTRY_LOG_ERROR(
                @"Can't create base path to store launch profile config file: %@", error);
            return;
        }
        sentryLaunchConfigFileURL =
            [NSURL fileURLWithPath:[basePath stringByAppendingPathComponent:@"profileLaunch"]];
        SENTRY_LOG_DEBUG(@"Launch profile config file URL: %@", sentryLaunchConfigFileURL);
    });
    return sentryLaunchConfigFileURL;
}

NSDictionary<NSString *, NSNumber *> *_Nullable sentry_appLaunchProfileConfiguration(void)
{
    NSURL *url = launchProfileConfigFileURL();
    if (![[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        return nil;
    }

    NSError *error;
    NSDictionary<NSString *, NSNumber *> *config =
        [NSDictionary<NSString *, NSNumber *> dictionaryWithContentsOfURL:url error:&error];

    if (error != nil) {
        SENTRY_LOG_ERROR(
            @"Encountered error trying to retrieve app launch profile config: %@", error);
        return nil;
    }

    return config;
}

BOOL
appLaunchProfileConfigFileExists(void)
{
    NSString *path = launchProfileConfigFileURL().path;
    if (path == nil) {
        SENTRY_LOG_DEBUG(@"Failed to construct the path to check for launch profile configs.")
        return NO;
    }

    return access(path.UTF8String, F_OK) == 0;
}

void
writeAppLaunchProfilingConfigFile(NSMutableDictionary<NSString *, NSNumber *> *config)
{
    NSError *error;
    SENTRY_LOG_DEBUG(@"Writing launch profiling config file.");
    SENTRY_CASSERT([config writeToURL:launchProfileConfigFileURL() error:&error],
        @"Failed to write launch profile config file: %@.", error);
}

void
removeAppLaunchProfilingConfigFile(void)
{
    _non_thread_safe_removeFileAtPath(launchProfileConfigFileURL().path);
}
#endif // SENTRY_TARGET_PROFILING_SUPPORTED

#pragma mark - Private Session

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

- (void)deleteSession:(NSString *)sessionFilePath
{
    SENTRY_LOG_DEBUG(@"Deleting session: %@", sessionFilePath);
    @synchronized(self.currentSessionFilePath) {
        [self removeFileAtPath:sessionFilePath];
    }
}

- (nullable SentrySession *)readSession:(NSString *)sessionFilePath
{
    [SentrySDKLog
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

#pragma mark - Private App State

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

- (void)deleteAppStateFrom:(NSString *)path
{
    [self removeFileAtPath:path];
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

#pragma mark - Private Envelope

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

#pragma mark - Private Others

- (NSString *)uniqueAscendingJsonName
{
    // %f = double
    // %05lu = unsigned with always 5 digits and leading zeros if number is too small. We
    //      need this because otherwise 10 would be sorted before 2 for example.
    // %@ = NSString
    // For example 978307200.000000-00001-3FE8C3AE-EB9C-4BEB-868C-14B8D47C33DD.json
    return [NSString stringWithFormat:@"%f-%05lu-%@.json",
        [[SentryDependencyContainer.sharedInstance.dateProvider date] timeIntervalSince1970],
        (unsigned long)self.currentFileCounter++, [NSUUID UUID].UUIDString];
}

- (SentryFileContents *_Nullable)getFileContents:(NSString *)folderPath
                                        filePath:(NSString *)filePath
{

    NSString *finalPath = [folderPath stringByAppendingPathComponent:filePath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSData *content = [fileManager contentsAtPath:finalPath];
    if (nil != content) {
        return [[SentryFileContents alloc] initWithPath:finalPath contents:content];
    } else {
        return nil;
    }
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

- (void)clearDiskState
{
    [self removeFileAtPath:self.basePath];
}

@end

NS_ASSUME_NONNULL_END
