#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions;

static NSString *const SENTRY_NETWORK_REQUEST_OPERATION = @"http.client";

@interface SentryNetworkTracker : NSObject

@property (class, readonly, nonatomic) SentryNetworkTracker *sharedInstance;

- (void)urlSessionTaskResume:(NSURLSessionTask *)sessionTask;

- (nullable NSDictionary *)addTraceHeader:(nullable NSDictionary *)headers;

- (void)enable;

- (void)disable;

@property (nonatomic, assign, readonly) BOOL isEnabled;

@end

NS_ASSUME_NONNULL_END
