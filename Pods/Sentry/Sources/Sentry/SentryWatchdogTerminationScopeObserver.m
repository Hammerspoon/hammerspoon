#import "SentryWatchdogTerminationScopeObserver.h"

#if SENTRY_HAS_UIKIT

#    import <SentryBreadcrumb.h>
#    import <SentryFileManager.h>
#    import <SentryLog.h>

@interface
SentryWatchdogTerminationScopeObserver ()

@property (strong, nonatomic) SentryFileManager *fileManager;
@property (strong, nonatomic) NSFileHandle *fileHandle;
@property (nonatomic) NSInteger maxBreadcrumbs;
@property (nonatomic) NSInteger breadcrumbCounter;
@property (strong, nonatomic) NSString *activeFilePath;

@end

@implementation SentryWatchdogTerminationScopeObserver

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs
                           fileManager:(SentryFileManager *)fileManager
{
    if (self = [super init]) {
        self.maxBreadcrumbs = maxBreadcrumbs;
        self.fileManager = fileManager;
        self.breadcrumbCounter = 0;

        [self switchFileHandle];
    }

    return self;
}

- (void)dealloc
{
    [self.fileHandle closeFile];
}

// PRAGMA MARK: - Helper methods

- (void)deleteFiles
{
    [self.fileHandle closeFile];
    self.fileHandle = nil;
    self.activeFilePath = nil;
    self.breadcrumbCounter = 0;

    [self.fileManager removeFileAtPath:self.fileManager.breadcrumbsFilePathOne];
    [self.fileManager removeFileAtPath:self.fileManager.breadcrumbsFilePathTwo];
}

- (void)switchFileHandle
{
    if ([self.activeFilePath isEqualToString:self.fileManager.breadcrumbsFilePathOne]) {
        self.activeFilePath = self.fileManager.breadcrumbsFilePathTwo;
    } else {
        self.activeFilePath = self.fileManager.breadcrumbsFilePathOne;
    }

    // Close the current filehandle (if any)
    [self.fileHandle closeFile];

    // Create a fresh file for the new active path
    [self.fileManager removeFileAtPath:self.activeFilePath];
    [[NSFileManager defaultManager] createFileAtPath:self.activeFilePath
                                            contents:nil
                                          attributes:nil];

    // Open the file for writing
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.activeFilePath];

    if (!self.fileHandle) {
        SENTRY_LOG_ERROR(@"Couldn't open file handle for %@", self.activeFilePath);
    }
}

- (void)store:(NSData *)data
{
    unsigned long long fileSize;
    @try {
        fileSize = [self.fileHandle seekToEndOfFile];

        [self.fileHandle writeData:data];
        [self.fileHandle writeData:[@"\n" dataUsingEncoding:NSASCIIStringEncoding]];

        self.breadcrumbCounter += 1;
    } @catch (NSException *exception) {
        SENTRY_LOG_ERROR(@"Error while writing data to end file with size (%llu): %@ ", fileSize,
            exception.description);
    } @finally {
        if (self.breadcrumbCounter >= self.maxBreadcrumbs) {
            [self switchFileHandle];
            self.breadcrumbCounter = 0;
        }
    }
}

// PRAGMA MARK: - SentryScopeObserver

- (void)addSerializedBreadcrumb:(NSDictionary *)crumb
{
    if (![NSJSONSerialization isValidJSONObject:crumb]) {
        SENTRY_LOG_ERROR(@"Breadcrumb is not a valid JSON object: %@", crumb);
        return;
    }

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:crumb options:0 error:&error];

    if (error) {
        SENTRY_LOG_ERROR(@"Error serializing breadcrumb: %@", error);
    } else {
        [self store:jsonData];
    }
}

- (void)clear
{
    [self clearBreadcrumbs];
}

- (void)clearBreadcrumbs
{
    [self deleteFiles];
    [self switchFileHandle];
}

- (void)setContext:(nullable NSDictionary<NSString *, id> *)context
{
    // Left blank on purpose
}

- (void)setDist:(nullable NSString *)dist
{
    // Left blank on purpose
}

- (void)setEnvironment:(nullable NSString *)environment
{
    // Left blank on purpose
}

- (void)setExtras:(nullable NSDictionary<NSString *, id> *)extras
{
    // Left blank on purpose
}

- (void)setFingerprint:(nullable NSArray<NSString *> *)fingerprint
{
    // Left blank on purpose
}

- (void)setLevel:(enum SentryLevel)level
{
    // Left blank on purpose
}

- (void)setTags:(nullable NSDictionary<NSString *, NSString *> *)tags
{
    // Left blank on purpose
}

- (void)setUser:(nullable SentryUser *)user
{
    // Left blank on purpose
}

@end

#endif // SENTRY_HAS_UIKIT
