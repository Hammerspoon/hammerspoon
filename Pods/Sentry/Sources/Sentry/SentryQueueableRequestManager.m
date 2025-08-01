#import "SentryQueueableRequestManager.h"
#import "SentryLogC.h"
#import "SentryRequestOperation.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryQueueableRequestManager ()

@property (nonatomic, strong) NSOperationQueue *queue;
@property (nonatomic, strong) NSURLSession *session;

@end

@implementation SentryQueueableRequestManager

- (instancetype)initWithSession:(NSURLSession *)session
{
    self = [super init];
    if (self) {
        self.session = session;
        self.queue = [[NSOperationQueue alloc] init];
        self.queue.name = @"io.sentry.QueueableRequestManager.OperationQueue";
        self.queue.maxConcurrentOperationCount = 3;
    }
    return self;
}

- (BOOL)isReady
{
#if SENTRY_TEST || SENTRY_TEST_CI
    // force every envelope to be cached in UI tests so we can inspect what the SDK would've sent
    // for a given operation
    if ([NSProcessInfo.processInfo.environment[@"--io.sentry.sdk-environment"]
            isEqualToString:@"ui-tests"]) {
        return NO;
    }
#elif DEBUG
    if ([NSProcessInfo.processInfo.arguments
            containsObject:@"--io.sentry.disable-http-transport"]) {
        return NO;
    }
#endif // SENTRY_TEST || SENTRY_TEST_CI

    // We always have at least one operation in the queue when calling this
    return self.queue.operationCount <= 1;
}

- (void)addRequest:(NSURLRequest *)request
    completionHandler:(_Nullable SentryRequestOperationFinished)completionHandler
{
    SentryRequestOperation *operation = [[SentryRequestOperation alloc]
          initWithSession:self.session
                  request:request
        completionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
            SENTRY_LOG_DEBUG(@"Queued requests: %@", @(self.queue.operationCount - 1));
            if (completionHandler) {
                completionHandler(response, error);
            }
        }];
    [self.queue addOperation:operation];
}

@end

NS_ASSUME_NONNULL_END
