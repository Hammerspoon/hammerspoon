#import "SentryRequestOperation.h"
#import "SentryClient.h"
#import "SentryError.h"
#import "SentryHub.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryRequestOperation ()

@property (nonatomic, strong) NSURLSessionTask *task;
@property (nonatomic, strong) NSURLRequest *request;

@end

@implementation SentryRequestOperation

- (instancetype)initWithSession:(NSURLSession *)session
                        request:(NSURLRequest *)request
              completionHandler:(_Nullable SentryRequestOperationFinished)completionHandler
{
    self = [super init];
    if (self) {
        self.request = request;
        self.task = [session
            dataTaskWithRequest:self.request
              completionHandler:^(NSData *_Nullable data, NSURLResponse *_Nullable response,
                  NSError *_Nullable error) {
                  NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
                  NSInteger statusCode = [httpResponse statusCode];

                  // We only have these if's here because of performance reasons
                  [SentryLog logWithMessage:[NSString stringWithFormat:@"Request status: %ld",
                                                      (long)statusCode]
                                   andLevel:kSentryLevelDebug];
                  if ([SentrySDK.currentHub getClient].options.debug == YES) {
                      [SentryLog logWithMessage:[NSString stringWithFormat:@"Request response: %@",
                                                          [[NSString alloc]
                                                              initWithData:data
                                                                  encoding:NSUTF8StringEncoding]]
                                       andLevel:kSentryLevelDebug];
                  }

                  if (nil != error) {
                      [SentryLog
                          logWithMessage:[NSString stringWithFormat:@"Request failed: %@", error]
                                andLevel:kSentryLevelError];
                  }

                  if (completionHandler) {
                      completionHandler(httpResponse, error);
                  }

                  [self completeOperation];
              }];
    }
    return self;
}

- (void)cancel
{
    if (nil != self.task) {
        [self.task cancel];
    }
    [super cancel];
}

- (void)main
{
    if (nil != self.task) {
        [self.task resume];
    }
}

@end

NS_ASSUME_NONNULL_END
