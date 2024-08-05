#import "SentryNetworkTracker.h"
#import "SentryBaggage.h"
#import "SentryBreadcrumb.h"
#import "SentryClient+Private.h"
#import "SentryDsn.h"
#import "SentryEvent.h"
#import "SentryException.h"
#import "SentryHttpStatusCodeRange+Private.h"
#import "SentryHttpStatusCodeRange.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentryMechanism.h"
#import "SentryNoOpSpan.h"
#import "SentryOptions.h"
#import "SentryPropagationContext.h"
#import "SentryRequest.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"
#import "SentrySerialization.h"
#import "SentryStacktrace.h"
#import "SentrySwift.h"
#import "SentryThread.h"
#import "SentryThreadInspector.h"
#import "SentryTraceContext.h"
#import "SentryTraceHeader.h"
#import "SentryTraceOrigins.h"
#import "SentryTracer.h"
#import "SentryUser.h"
#import <objc/runtime.h>

/**
 * WARNING: We had issues in the past with this code on older iOS versions. We don't run unit tests
 * on all the iOS versions our SDK supports. When adding this comment on April 12th, 2023, we
 * decided to remove running unit tests on iOS 12 simulators. Check the develop-docs decision log
 * for more information https://github.com/getsentry/sentry-cocoa/blob/main/develop-docs/README.md.
 * Back then, the code worked correctly on all iOS versions. Please evaluate if your changes could
 * break on specific iOS versions to ensure it works properly when modifying this file. If they
 * could, please add UI tests and run them on older iOS versions.
 */
@interface
SentryNetworkTracker ()

@property (nonatomic, assign) BOOL isNetworkTrackingEnabled;
@property (nonatomic, assign) BOOL isNetworkBreadcrumbEnabled;
@property (nonatomic, assign) BOOL isCaptureFailedRequestsEnabled;
@property (nonatomic, assign) BOOL isGraphQLOperationTrackingEnabled;

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
        _isNetworkTrackingEnabled = NO;
        _isNetworkBreadcrumbEnabled = NO;
        _isCaptureFailedRequestsEnabled = NO;
        _isGraphQLOperationTrackingEnabled = NO;
    }
    return self;
}

- (void)enableNetworkTracking
{
    @synchronized(self) {
        _isNetworkTrackingEnabled = YES;
    }
}

- (void)enableNetworkBreadcrumbs
{
    @synchronized(self) {
        _isNetworkBreadcrumbEnabled = YES;
    }
}

- (void)enableCaptureFailedRequests
{
    @synchronized(self) {
        _isCaptureFailedRequestsEnabled = YES;
    }
}

- (void)enableGraphQLOperationTracking
{
    @synchronized(self) {
        _isGraphQLOperationTrackingEnabled = YES;
    }
}

- (void)disable
{
    @synchronized(self) {
        _isNetworkBreadcrumbEnabled = NO;
        _isNetworkTrackingEnabled = NO;
        _isCaptureFailedRequestsEnabled = NO;
        _isGraphQLOperationTrackingEnabled = NO;
    }
}

- (BOOL)isTargetMatch:(NSURL *)URL withTargets:(NSArray *)targets
{
    for (id targetCheck in targets) {
        if ([targetCheck isKindOfClass:[NSRegularExpression class]]) {
            NSString *string = URL.absoluteString;
            NSUInteger numberOfMatches =
                [targetCheck numberOfMatchesInString:string
                                             options:0
                                               range:NSMakeRange(0, [string length])];
            if (numberOfMatches > 0) {
                return YES;
            }
        } else if ([targetCheck isKindOfClass:[NSString class]]) {
            if ([URL.absoluteString containsString:targetCheck]) {
                return YES;
            }
        }
    }

    return NO;
}

- (BOOL)sessionTaskRequiresPropagation:(NSURLSessionTask *)sessionTask
{
    return sessionTask.currentRequest != nil &&
        [self isTargetMatch:sessionTask.currentRequest.URL
                withTargets:SentrySDK.options.tracePropagationTargets];
}

- (void)urlSessionTaskResume:(NSURLSessionTask *)sessionTask
{
    NSURLSessionTaskState sessionState = sessionTask.state;
    if (sessionState == NSURLSessionTaskStateCompleted
        || sessionState == NSURLSessionTaskStateCanceling) {
        return;
    }

    if (![self isTaskSupported:sessionTask])
        return;

    // SDK not enabled no need to continue
    if (SentrySDK.options == nil) {
        return;
    }

    NSURL *url = [[sessionTask currentRequest] URL];

    if (url == nil) {
        return;
    }

    // Don't measure requests to Sentry's backend
    NSURL *apiUrl = SentrySDK.options.parsedDsn.url;
    if ([url.host isEqualToString:apiUrl.host] && [url.path containsString:apiUrl.path]) {
        return;
    }

    // Register request start date in the sessionTask to use for breadcrumb
    if (self.isNetworkBreadcrumbEnabled) {
        objc_setAssociatedObject(sessionTask, &SENTRY_NETWORK_REQUEST_START_DATE, [NSDate date],
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    @synchronized(self) {
        if (!self.isNetworkTrackingEnabled) {
            [self addTraceWithoutTransactionToTask:sessionTask];
            return;
        }
    }

    UrlSanitized *safeUrl = [[UrlSanitized alloc] initWithURL:url];
    @synchronized(sessionTask) {
        __block id<SentrySpan> span;
        __block id<SentrySpan> netSpan;
        netSpan = objc_getAssociatedObject(sessionTask, &SENTRY_NETWORK_REQUEST_TRACKER_SPAN);

        // The task already has a span. Nothing to do.
        if (netSpan != nil) {
            return;
        }

        [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> _Nullable innerSpan) {
            if (innerSpan != nil) {
                span = innerSpan;
                netSpan =
                    [span startChildWithOperation:SENTRY_NETWORK_REQUEST_OPERATION
                                      description:[NSString stringWithFormat:@"%@ %@",
                                                            sessionTask.currentRequest.HTTPMethod,
                                                            safeUrl.sanitizedUrl]];
                netSpan.origin = SentryTraceOriginAutoHttpNSURLSession;

                [netSpan setDataValue:sessionTask.currentRequest.HTTPMethod
                               forKey:@"http.request.method"];
                [netSpan setDataValue:safeUrl.sanitizedUrl forKey:@"url"];
                [netSpan setDataValue:@"fetch" forKey:@"type"];

                if (safeUrl.queryItems && safeUrl.queryItems.count > 0) {
                    [netSpan setDataValue:safeUrl.query forKey:@"http.query"];
                }
                if (safeUrl.fragment != nil) {
                    [netSpan setDataValue:safeUrl.fragment forKey:@"http.fragment"];
                }
            }
        }];

        // We only create a span if there is a transaction in the scope,
        // otherwise we have nothing else to do here.
        if (netSpan == nil || [netSpan isKindOfClass:[SentryNoOpSpan class]]) {
            SENTRY_LOG_DEBUG(@"No transaction bound to scope. Won't track network operation.");
            [self addTraceWithoutTransactionToTask:sessionTask];
            return;
        }

        SentryBaggage *baggage = [[[SentryTracer getTracer:span] traceContext] toBaggage];
        [self addBaggageHeader:baggage traceHeader:[netSpan toTraceHeader] toRequest:sessionTask];

        SENTRY_LOG_DEBUG(
            @"SentryNetworkTracker automatically started HTTP span for sessionTask: %@",
            netSpan.description);

        objc_setAssociatedObject(sessionTask, &SENTRY_NETWORK_REQUEST_TRACKER_SPAN, netSpan,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)addTraceWithoutTransactionToTask:(NSURLSessionTask *)sessionTask
{
    SentryPropagationContext *propagationContext = SentrySDK.currentHub.scope.propagationContext;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    SentryTraceContext *traceContext =
        [[SentryTraceContext alloc] initWithTraceId:propagationContext.traceId
                                            options:SentrySDK.currentHub.client.options
                                        userSegment:SentrySDK.currentHub.scope.userObject.segment];
#pragma clang diagnostic pop

    [self addBaggageHeader:[traceContext toBaggage]
               traceHeader:[propagationContext traceHeader]
                 toRequest:sessionTask];
}

- (void)addBaggageHeader:(SentryBaggage *)baggage
             traceHeader:(SentryTraceHeader *)traceHeader
               toRequest:(NSURLSessionTask *)sessionTask
{
    if (![self sessionTaskRequiresPropagation:sessionTask]) {
        SENTRY_LOG_DEBUG(@"Not adding trace_id and baggage headers for %@",
            sessionTask.currentRequest.URL.absoluteString);
        return;
    }
    NSString *baggageHeader = @"";

    if (baggage != nil) {
        NSDictionary *originalBaggage = [SentryBaggageSerialization
            decode:sessionTask.currentRequest.allHTTPHeaderFields[SENTRY_BAGGAGE_HEADER]];

        if (originalBaggage[@"sentry-trace_id"] == nil) {
            baggageHeader = [baggage toHTTPHeaderWithOriginalBaggage:originalBaggage];
        }
    }

    // First we check if the current request is mutable, so we could easily add a new
    // header. Otherwise we try to change the current request for a new one with the extra
    // header.
    if ([sessionTask.currentRequest isKindOfClass:[NSMutableURLRequest class]]) {
        NSMutableURLRequest *currentRequest = (NSMutableURLRequest *)sessionTask.currentRequest;

        if ([currentRequest valueForHTTPHeaderField:SENTRY_TRACE_HEADER] == nil) {
            [currentRequest setValue:traceHeader.value forHTTPHeaderField:SENTRY_TRACE_HEADER];
        }

        if (baggageHeader.length > 0) {
            [currentRequest setValue:baggageHeader forHTTPHeaderField:SENTRY_BAGGAGE_HEADER];
        }
    } else {
        // Even though NSURLSessionTask doesn't have 'setCurrentRequest', some subclasses
        // do. For those subclasses we replace the currentRequest with a mutable one with
        // the additional trace header. Since NSURLSessionTask is a public class and can be
        // override, we believe this is not considered a private api.
        SEL setCurrentRequestSelector = NSSelectorFromString(@"setCurrentRequest:");
        if ([sessionTask respondsToSelector:setCurrentRequestSelector]) {
            NSMutableURLRequest *newRequest = [sessionTask.currentRequest mutableCopy];

            if ([newRequest valueForHTTPHeaderField:SENTRY_TRACE_HEADER] == nil) {
                [newRequest setValue:traceHeader.value forHTTPHeaderField:SENTRY_TRACE_HEADER];
            }

            if (baggageHeader.length > 0) {
                [newRequest setValue:baggageHeader forHTTPHeaderField:SENTRY_BAGGAGE_HEADER];
            }

            void (*func)(id, SEL, id param)
                = (void *)[sessionTask methodForSelector:setCurrentRequestSelector];
            func(sessionTask, setCurrentRequestSelector, newRequest);
        }
    }
}

- (void)urlSessionTask:(NSURLSessionTask *)sessionTask setState:(NSURLSessionTaskState)newState
{
    if (!self.isNetworkTrackingEnabled && !self.isNetworkBreadcrumbEnabled
        && !self.isCaptureFailedRequestsEnabled) {
        return;
    }

    if (![self isTaskSupported:sessionTask]) {
        return;
    }

    if (newState == NSURLSessionTaskStateRunning) {
        return;
    }

    NSURL *url = [[sessionTask currentRequest] URL];

    if (url == nil) {
        return;
    }

    // Don't measure requests to Sentry's backend
    NSURL *apiUrl = SentrySDK.options.parsedDsn.url;
    if ([url.host isEqualToString:apiUrl.host] && [url.path containsString:apiUrl.path]) {
        return;
    }

    id<SentrySpan> netSpan;
    @synchronized(sessionTask) {
        netSpan = objc_getAssociatedObject(sessionTask, &SENTRY_NETWORK_REQUEST_TRACKER_SPAN);
        // We'll just go through once
        objc_setAssociatedObject(sessionTask, &SENTRY_NETWORK_REQUEST_TRACKER_SPAN, nil,
            OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (sessionTask.state == NSURLSessionTaskStateRunning) {
        [self captureFailedRequests:sessionTask];

        [self addBreadcrumbForSessionTask:sessionTask];

        NSInteger responseStatusCode = [self urlResponseStatusCode:sessionTask.response];

        if (responseStatusCode != -1) {
            NSNumber *statusCode = [NSNumber numberWithInteger:responseStatusCode];

            if (netSpan != nil) {
                [netSpan setDataValue:[NSString stringWithFormat:@"%@", statusCode]
                               forKey:@"http.response.status_code"];
            }
        }
    }

    if (netSpan == nil) {
        return;
    }

    [netSpan finishWithStatus:[self statusForSessionTask:sessionTask state:newState]];
    SENTRY_LOG_DEBUG(@"SentryNetworkTracker finished HTTP span for sessionTask");
}

- (void)captureFailedRequests:(NSURLSessionTask *)sessionTask
{
    @synchronized(self) {
        if (!self.isCaptureFailedRequestsEnabled) {
            SENTRY_LOG_DEBUG(
                @"captureFailedRequestsEnabled is disabled, not capturing HTTP Client errors.");
            return;
        }
    }

    // if request or response are null, we can't raise the event
    if (sessionTask.currentRequest == nil || sessionTask.response == nil) {
        SENTRY_LOG_DEBUG(@"Request or Response are null, not capturing HTTP Client errors.");
        return;
    }

    // some properties are only available if the response is of the NSHTTPURLResponse type
    // bail if not
    if (![sessionTask.response isKindOfClass:[NSHTTPURLResponse class]]) {
        SENTRY_LOG_DEBUG(@"Response isn't a known type, not capturing HTTP Client errors.");
        return;
    }
    NSHTTPURLResponse *myResponse = (NSHTTPURLResponse *)sessionTask.response;
    NSURLRequest *myRequest = sessionTask.currentRequest;
    NSNumber *responseStatusCode = @(myResponse.statusCode);

    if (![self containsStatusCode:myResponse.statusCode]) {
        SENTRY_LOG_DEBUG(@"Response status code isn't within the allowed ranges, not capturing "
                         @"HTTP Client errors.");
        return;
    }

    if (![self isTargetMatch:myRequest.URL withTargets:SentrySDK.options.failedRequestTargets]) {
        SENTRY_LOG_DEBUG(
            @"Request url isn't within the request targets, not capturing HTTP Client errors.");
        return;
    }

    NSString *message = [NSString
        stringWithFormat:@"HTTP Client Error with status code: %ld", (long)myResponse.statusCode];

    SentryEvent *event = [[SentryEvent alloc] initWithLevel:kSentryLevelError];

    SentryThreadInspector *threadInspector = SentrySDK.currentHub.getClient.threadInspector;
    NSArray<SentryThread *> *threads = [threadInspector getCurrentThreads];

    // sessionTask.error isn't used because it's not about network errors but rather
    // requests that are considered failed depending on the HTTP status code
    SentryException *sentryException = [[SentryException alloc] initWithValue:message
                                                                         type:@"HTTPClientError"];
    sentryException.mechanism = [[SentryMechanism alloc] initWithType:@"HTTPClientError"];

    for (SentryThread *thread in threads) {
        if ([thread.current boolValue]) {
            SentryStacktrace *sentryStacktrace = [thread stacktrace];
            sentryStacktrace.snapshot = @(YES);

            sentryException.stacktrace = sentryStacktrace;

            break;
        }
    }

    SentryRequest *request = [[SentryRequest alloc] init];

    UrlSanitized *url = [[UrlSanitized alloc] initWithURL:[[sessionTask currentRequest] URL]];

    request.url = url.sanitizedUrl;
    request.method = myRequest.HTTPMethod;
    request.fragment = url.fragment;
    request.queryString = url.query;
    request.bodySize = [NSNumber numberWithLongLong:sessionTask.countOfBytesSent];
    if (nil != myRequest.allHTTPHeaderFields) {
        NSDictionary<NSString *, NSString *> *headers = myRequest.allHTTPHeaderFields.copy;
        request.headers = [HTTPHeaderSanitizer sanitizeHeaders:headers];
    }

    event.exceptions = @[ sentryException ];
    event.request = request;

    NSMutableDictionary<NSString *, id> *context = [[NSMutableDictionary alloc] init];
    NSMutableDictionary<NSString *, id> *response = [[NSMutableDictionary alloc] init];

    [response setValue:responseStatusCode forKey:@"status_code"];
    if (nil != myResponse.allHeaderFields) {
        NSDictionary<NSString *, NSString *> *headers =
            [HTTPHeaderSanitizer sanitizeHeaders:myResponse.allHeaderFields];
        [response setValue:headers forKey:@"headers"];
    }
    if (sessionTask.countOfBytesReceived != 0) {
        [response setValue:[NSNumber numberWithLongLong:sessionTask.countOfBytesReceived]
                    forKey:@"body_size"];
    }

    context[@"response"] = response;

    if (self.isGraphQLOperationTrackingEnabled) {
        context[@"graphql_operation_name"] =
            [URLSessionTaskHelper getGraphQLOperationNameFrom:sessionTask];
    }

    event.context = context;

    [SentrySDK captureEvent:event];
}

- (BOOL)containsStatusCode:(NSInteger)statusCode
{
    for (SentryHttpStatusCodeRange *range in SentrySDK.options.failedRequestStatusCodes) {
        if ([range isInRange:statusCode]) {
            return YES;
        }
    }

    return NO;
}

- (void)addBreadcrumbForSessionTask:(NSURLSessionTask *)sessionTask
{
    if (!self.isNetworkBreadcrumbEnabled) {
        return;
    }

    id hasBreadcrumb
        = objc_getAssociatedObject(sessionTask, &SENTRY_NETWORK_REQUEST_TRACKER_BREADCRUMB);
    if (hasBreadcrumb && [hasBreadcrumb isKindOfClass:NSNumber.class] &&
        [hasBreadcrumb boolValue]) {
        return;
    }
    NSDate *requestStart
        = objc_getAssociatedObject(sessionTask, &SENTRY_NETWORK_REQUEST_START_DATE);

    SentryLevel breadcrumbLevel = sessionTask.error != nil ? kSentryLevelError : kSentryLevelInfo;
    SentryBreadcrumb *breadcrumb = [[SentryBreadcrumb alloc] initWithLevel:breadcrumbLevel
                                                                  category:@"http"];

    UrlSanitized *urlComponents = [[UrlSanitized alloc] initWithURL:sessionTask.currentRequest.URL];

    breadcrumb.type = @"http";
    NSMutableDictionary<NSString *, id> *breadcrumbData = [NSMutableDictionary new];
    breadcrumbData[@"url"] = urlComponents.sanitizedUrl;
    breadcrumbData[@"method"] = sessionTask.currentRequest.HTTPMethod;
    breadcrumbData[@"request_start"] = requestStart;
    breadcrumbData[@"request_body_size"] =
        [NSNumber numberWithLongLong:sessionTask.countOfBytesSent];
    breadcrumbData[@"response_body_size"] =
        [NSNumber numberWithLongLong:sessionTask.countOfBytesReceived];
    NSInteger responseStatusCode = [self urlResponseStatusCode:sessionTask.response];
    if (responseStatusCode != -1) {
        NSNumber *statusCode = [NSNumber numberWithInteger:responseStatusCode];
        breadcrumbData[@"status_code"] = statusCode;
        breadcrumbData[@"reason"] =
            [NSHTTPURLResponse localizedStringForStatusCode:responseStatusCode];

        if (self.isGraphQLOperationTrackingEnabled) {
            breadcrumbData[@"graphql_operation_name"] =
                [URLSessionTaskHelper getGraphQLOperationNameFrom:sessionTask];
        }
    }

    if (urlComponents.query != nil) {
        breadcrumbData[@"http.query"] = urlComponents.query;
    }

    if (urlComponents.fragment != nil) {
        breadcrumbData[@"http.fragment"] = urlComponents.fragment;
    }

    breadcrumb.data = breadcrumbData;
    [SentrySDK addBreadcrumb:breadcrumb];

    objc_setAssociatedObject(sessionTask, &SENTRY_NETWORK_REQUEST_TRACKER_BREADCRUMB,
        [NSNumber numberWithBool:YES], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSInteger)urlResponseStatusCode:(NSURLResponse *)response
{
    if (response != nil && [response isKindOfClass:[NSHTTPURLResponse class]]) {
        return ((NSHTTPURLResponse *)response).statusCode;
    }
    return -1;
}

- (SentrySpanStatus)statusForSessionTask:(NSURLSessionTask *)task state:(NSURLSessionTaskState)state
{
    switch (state) {
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

@end
