#import "SentryWatchdogTerminationBreadcrumbProcessor.h"
#import "SentryFileManager.h"
#import "SentryLogC.h"
#import "SentrySerialization.h"

@interface SentryWatchdogTerminationBreadcrumbProcessor ()

@property (strong, nonatomic) SentryFileManager *fileManager;

@property (strong, nonatomic) NSFileHandle *fileHandle;
@property (strong, nonatomic) NSString *activeFilePath;
@property (nonatomic) NSInteger maxBreadcrumbs;
@property (nonatomic) NSInteger breadcrumbCounter;

@end

@implementation SentryWatchdogTerminationBreadcrumbProcessor

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs
                           fileManager:(SentryFileManager *)fileManager
{
    if (self = [super init]) {
        self.fileManager = fileManager;

        self.breadcrumbCounter = 0;
        self.maxBreadcrumbs = maxBreadcrumbs;

        [self switchFileHandle];
    }

    return self;
}

- (void)dealloc
{
    [self.fileHandle closeFile];
}

- (void)addSerializedBreadcrumb:(NSDictionary *)crumb
{
    SENTRY_LOG_DEBUG(@"Adding breadcrumb: %@", crumb);
    NSData *_Nullable jsonData = [SentrySerialization dataWithJSONObject:crumb];
    if (jsonData == nil) {
        SENTRY_LOG_ERROR(@"Error serializing breadcrumb to JSON");
        return;
    }
    [self storeBreadcrumb:jsonData];
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

// MARK: - Helpers

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

- (void)deleteFiles
{
    [self.fileHandle closeFile];
    self.fileHandle = nil;
    self.activeFilePath = nil;
    self.breadcrumbCounter = 0;

    [self.fileManager removeFileAtPath:self.fileManager.breadcrumbsFilePathOne];
    [self.fileManager removeFileAtPath:self.fileManager.breadcrumbsFilePathTwo];
}

- (void)storeBreadcrumb:(NSData *_Nonnull)data
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

@end
