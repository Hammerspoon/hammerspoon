#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryOptions;

static NSString *const SENTRY_NETWORK_REQUEST_OPERATION = @"http.client";
static NSString *const SENTRY_NETWORK_REQUEST_TRACKER_SPAN = @"SENTRY_NETWORK_REQUEST_TRACKER_SPAN";
static NSString *const SENTRY_NETWORK_REQUEST_START_DATE = @"SENTRY_NETWORK_REQUEST_START_DATE";
static NSString *const SENTRY_NETWORK_REQUEST_TRACKER_BREADCRUMB
    = @"SENTRY_NETWORK_REQUEST_TRACKER_BREADCRUMB";

@interface SentryNetworkTracker : NSObject

@property (class, readonly, nonatomic) SentryNetworkTracker *sharedInstance;

- (void)urlSessionTaskResume:(NSURLSessionTask *)sessionTask;
- (void)urlSessionTask:(NSURLSessionTask *)sessionTask setState:(NSURLSessionTaskState)newState;
- (void)enableNetworkTracking;
- (void)enableNetworkBreadcrumbs;
- (void)enableCaptureFailedRequests;
- (void)enableGraphQLOperationTracking;
- (BOOL)isTargetMatch:(NSURL *)URL withTargets:(NSArray *)targets;
- (void)disable;

@property (nonatomic, readonly) BOOL isNetworkTrackingEnabled;
@property (nonatomic, readonly) BOOL isNetworkBreadcrumbEnabled;
@property (nonatomic, readonly) BOOL isCaptureFailedRequestsEnabled;
@property (nonatomic, readonly) BOOL isGraphQLOperationTrackingEnabled;

@end

NS_ASSUME_NONNULL_END
