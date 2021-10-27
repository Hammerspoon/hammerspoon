#import "SentryNetworkTracker.h"
#import "SentryBreadcrumb.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentryOptions+Private.h"
#import "SentryOptions.h"
#import "SentryPerformanceTracker.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"
#import "SentrySpan.h"
#import "SentryTraceHeader.h"
#import "SentryTraceState.h"
#import "SentryTracer.h"
#import <objc/runtime.h>

static NSString *const SENTRY_NETWORK_REQUEST_TRACKER_SPAN = @"SENTRY_NETWORK_REQUEST_TRACKER_SPAN";

@interface
SentryNetworkTracker ()

@property (nonatomic, assign) BOOL isEnabled;

@end

@implementation SentryNetworkTracker

+ (SentryNetworkTracker *)sharedInstance
{
    static SentryNetworkTracker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        _isEnabled = NO;
    }
    return self;
}

- (void)enable
{
    @synchronized(self) {
        _isEnabled = YES;
    }
}

- (void)disable
{
    @synchronized(self) {
        _isEnabled = NO;
    }
}

- (void)urlSessionTaskResume:(NSURLSessionTask *)sessionTask
{
    @synchronized(self) {
        if (!self.isEnabled) {
            return;
        }
    }

    if (![self isTaskSupported:sessionTask])
        return;

    // SDK not enabled no need to continue
    if (SentrySDK.options == nil) {
        return;
    }

    NSURL *url = [[sessionTask currentRequest] URL];

    if (url == nil)
        return;

    // Don't measure requests to Sentry's backend
    NSURL *apiUrl = [NSURL URLWithString:SentrySDK.options.dsn];
    if ([url.host isEqualToString:apiUrl.host] && [url.path containsString:apiUrl.path])
        return;

    @synchronized(sessionTask) {
        if (sessionTask.state == NSURLSessionTaskStateCompleted
            || sessionTask.state == NSURLSessionTaskStateCanceling) {
            return;
        }

        __block id<SentrySpan> netSpan;
        netSpan = objc_getAssociatedObject(sessionTask, &SENTRY_NETWORK_REQUEST_TRACKER_SPAN);

        // The task already has a span. Nothing to do.
        if (netSpan != nil) {
            return;
        }

        [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> _Nullable span) {
            if (span != nil) {
                netSpan = [span
                    startChildWithOperation:SENTRY_NETWORK_REQUEST_OPERATION
                                description:[NSString stringWithFormat:@"%@ %@",
                                                      sessionTask.currentRequest.HTTPMethod, url]];
            }
        }];

        // We only create a span if there is a transaction in the scope,
        // otherwise we have nothing else to do here.
        if (netSpan == nil)
            return;

        objc_setAssociatedObject(sessionTask, &SENTRY_NETWORK_REQUEST_TRACKER_SPAN, netSpan,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    NSString *statePath = NSStringFromSelector(@selector(state));
    [sessionTask addObserver:self
                  forKeyPath:statePath
                     options:NSKeyValueObservingOptionNew
                     context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context
{

    if (![keyPath isEqualToString:NSStringFromSelector(@selector(state))]) {
        return;
    }

    NSURLSessionTask *sessionTask = object;
    if (sessionTask.state == NSURLSessionTaskStateRunning) {
        return;
    }

    id<SentrySpan> netSpan;
    @synchronized(sessionTask) {
        // It is crucial always to remove the observer, as it does not automatically remove itself
        // when its object is deallocated. Therefore not removing the observer can result in a
        // memory access exception. Theoretically, the state of the NSURLSessionTask could change
        // concurrently. Even removing the observer in the synchronized block doesn't prevent us
        // from potentially calling remove twice, which would lead to an NSRangeException.
        // Therefore, we have to wrap the call into a try catch. See:
        // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/KeyValueObserving/Articles/KVOBasics.html#//apple_ref/doc/uid/20002252-178612
        @try {
            [sessionTask removeObserver:self forKeyPath:NSStringFromSelector(@selector(state))];
        } @catch (NSException *__unused exception) {
            // Safe to ignore
        }

        netSpan = objc_getAssociatedObject(sessionTask, &SENTRY_NETWORK_REQUEST_TRACKER_SPAN);
        // We'll just go through once
        objc_setAssociatedObject(sessionTask, &SENTRY_NETWORK_REQUEST_TRACKER_SPAN, nil,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    SentryLevel breadcrumbLevel = sessionTask.error != nil ? kSentryLevelError : kSentryLevelInfo;
    SentryBreadcrumb *breadcrumb = [[SentryBreadcrumb alloc] initWithLevel:breadcrumbLevel
                                                                  category:@"http"];
    breadcrumb.type = @"http";
    NSMutableDictionary<NSString *, id> *breadcrumbData = [NSMutableDictionary new];
    breadcrumbData[@"url"] = sessionTask.currentRequest.URL.absoluteString;
    breadcrumbData[@"method"] = sessionTask.currentRequest.HTTPMethod;
    breadcrumbData[@"request_body_size"] =
        [NSNumber numberWithLongLong:sessionTask.countOfBytesSent];
    breadcrumbData[@"response_body_size"] =
        [NSNumber numberWithLongLong:sessionTask.countOfBytesReceived];

    NSInteger responseStatusCode = [self urlResponseStatusCode:sessionTask.response];

    if (responseStatusCode != -1) {
        NSNumber *statusCode = [NSNumber numberWithInteger:responseStatusCode];

        if (netSpan != nil) {
            [netSpan setTagValue:[NSString stringWithFormat:@"%@", statusCode]
                          forKey:@"http.status_code"];
        }
        breadcrumbData[@"status_code"] = statusCode;
        breadcrumbData[@"reason"] =
            [NSHTTPURLResponse localizedStringForStatusCode:responseStatusCode];
    }

    breadcrumb.data = breadcrumbData;
    [SentrySDK addBreadcrumb:breadcrumb];

    if (netSpan == nil) {
        return;
    }

    [netSpan setDataValue:sessionTask.currentRequest.HTTPMethod forKey:@"method"];
    [netSpan setDataValue:sessionTask.currentRequest.URL.path forKey:@"url"];
    [netSpan setDataValue:@"fetch" forKey:@"type"];

    [netSpan finishWithStatus:[self statusForSessionTask:sessionTask]];
    [SentryLog logWithMessage:@"Finished HTTP span for sessionTask" andLevel:kSentryLevelDebug];
}

- (NSInteger)urlResponseStatusCode:(NSURLResponse *)response
{
    if (response != nil && [response isKindOfClass:[NSHTTPURLResponse class]]) {
        return ((NSHTTPURLResponse *)response).statusCode;
    }
    return -1;
}

- (SentrySpanStatus)statusForSessionTask:(NSURLSessionTask *)task
{
    switch (task.state) {
    case NSURLSessionTaskStateSuspended:
        return kSentrySpanStatusAborted;
    case NSURLSessionTaskStateCanceling:
        return kSentrySpanStatusCancelled;
    case NSURLSessionTaskStateCompleted:
        return task.error != nil
            ? kSentrySpanStatusUnknownError
            : [self spanStatusForHttpResponseStatusCode:[self urlResponseStatusCode:task.response]];
    case NSURLSessionTaskStateRunning:
        break;
    }
    return kSentrySpanStatusUndefined;
}

- (BOOL)isTaskSupported:(NSURLSessionTask *)task
{
    // Since streams are usually created to stay connected we don't measure this type of data
    // transfer.
    return [task isKindOfClass:[NSURLSessionDataTask class]] ||
        [task isKindOfClass:[NSURLSessionDownloadTask class]] ||
        [task isKindOfClass:[NSURLSessionUploadTask class]];
}

// https://develop.sentry.dev/sdk/event-payloads/span/
- (SentrySpanStatus)spanStatusForHttpResponseStatusCode:(NSInteger)statusCode
{
    if (statusCode >= 200 && statusCode < 300) {
        return kSentrySpanStatusOk;
    }

    switch (statusCode) {
    case 400:
        return kSentrySpanStatusInvalidArgument;
    case 401:
        return kSentrySpanStatusUnauthenticated;
    case 403:
        return kSentrySpanStatusPermissionDenied;
    case 404:
        return kSentrySpanStatusNotFound;
    case 409:
        return kSentrySpanStatusAborted;
    case 429:
        return kSentrySpanStatusResourceExhausted;
    case 500:
        return kSentrySpanStatusInternalError;
    case 501:
        return kSentrySpanStatusUnimplemented;
    case 503:
        return kSentrySpanStatusUnavailable;
    case 504:
        return kSentrySpanStatusDeadlineExceeded;
    }
    return kSentrySpanStatusUndefined;
}

- (nullable NSDictionary *)addTraceHeader:(nullable NSDictionary *)headers
{
    @synchronized(self) {
        if (!self.isEnabled) {
            return headers;
        }
    }

    id<SentrySpan> span = SentrySDK.currentHub.scope.span;
    if (span == nil) {
        return headers;
    }

    NSMutableDictionary *result = [[NSMutableDictionary alloc] initWithDictionary:headers];
    result[SENTRY_TRACE_HEADER] = [span toTraceHeader].value;

    SentryTracer *tracer = [SentryTracer getTracer:span];
    if (tracer != nil) {
        result[SENTRY_TRACESTATE_HEADER] = [tracer.traceState toHTTPHeader];
    }

    return [[NSDictionary alloc] initWithDictionary:result];
}

@end
