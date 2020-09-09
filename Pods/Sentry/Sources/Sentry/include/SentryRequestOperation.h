#import <Foundation/Foundation.h>

#import "SentryAsynchronousOperation.h"
#import "SentryQueueableRequestManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryRequestOperation : SentryAsynchronousOperation

- (instancetype)initWithSession:(NSURLSession *)session
                        request:(NSURLRequest *)request
              completionHandler:(_Nullable SentryRequestOperationFinished)completionHandler;

@end

NS_ASSUME_NONNULL_END
