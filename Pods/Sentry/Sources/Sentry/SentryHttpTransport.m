#import "SentryHttpTransport.h"
#import "SentrySDK.h"
#import "SentryLog.h"
#import "SentryDsn.h"
#import "SentryError.h"
#import "SentryUser.h"
#import "SentryEvent.h"
#import "SentryNSURLRequest.h"
#import "SentryCrashInstallationReporter.h"
#import "SentryFileManager.h"
#import "SentryBreadcrumbTracker.h"
#import "SentryCrash.h"
#import "SentryOptions.h"
#import "SentryScope.h"
#import "SentrySerialization.h"
#import "SentryDefaultRateLimits.h"
#import "SentryFileContents.h"
#import "SentryEnvelopeItemType.h"
#import "SentryRateLimitCategoryMapper.h"
#import "SentryEnvelopeRateLimit.h"

@interface SentryHttpTransport ()

@property(nonatomic, strong) SentryFileManager *fileManager;
@property(nonatomic, strong) id <SentryRequestManager> requestManager;
@property(nonatomic, weak) SentryOptions *options;
@property(nonatomic, strong) id <SentryRateLimits> rateLimits;
@property(nonatomic, strong) SentryEnvelopeRateLimit *envelopeRateLimit;

@end

@implementation SentryHttpTransport

- (id)initWithOptions:(SentryOptions *)options
    sentryFileManager:(SentryFileManager *)sentryFileManager
 sentryRequestManager:(id<SentryRequestManager>) sentryRequestManager
sentryRateLimits:(id<SentryRateLimits>) sentryRateLimits
sentryEnvelopeRateLimit:(SentryEnvelopeRateLimit *)envelopeRateLimit
{
  if (self = [super init]) {
      self.options = options;
      self.requestManager = sentryRequestManager;
      self.fileManager = sentryFileManager;
      self.rateLimits = sentryRateLimits;
      self.envelopeRateLimit = envelopeRateLimit;
      
      [self setupQueueing];
      [self sendCachedEventsAndEnvelopes];
  }
  return self;
}

// TODO: needs refactoring
- (void)    sendEvent:(SentryEvent *)event
withCompletionHandler:(_Nullable SentryRequestFinished)completionHandler {
    NSString *category = [SentryRateLimitCategoryMapper mapEventTypeToCategory:event.type];
    if (![self isReadyToSend:category]) {
        return;
    }
    
    NSError *requestError = nil;
    // TODO: We do multiple serializations here, we can improve this
    NSURLRequest *request = [[SentryNSURLRequest alloc] initStoreRequestWithDsn:self.options.dsn
                                                                             andEvent:event
                                                                     didFailWithError:&requestError];
    if (nil != requestError) {
        [SentryLog logWithMessage:requestError.localizedDescription andLevel:kSentryLogLevelError];
        if (completionHandler) {
            completionHandler(requestError);
        }
        return;
    }

    // TODO: We do multiple serializations here, we can improve this
    NSString *storedEventPath = [self.fileManager storeEvent:event];

    [self sendRequest:request storedPath:storedEventPath envelope:nil  completionHandler:completionHandler];
}

// TODO: needs refactoring
- (void)sendEnvelope:(SentryEnvelope *)envelope
   withCompletionHandler:(_Nullable SentryRequestFinished)completionHandler {
    
    if (![self.options.enabled boolValue]) {
        [SentryLog logWithMessage:@"SentryClient is disabled. (options.enabled = false)" andLevel:kSentryLogLevelDebug];
        return;
    }
    
    envelope = [self.envelopeRateLimit removeRateLimitedItems:envelope];
    
    if (envelope.items.count == 0) {
        [SentryLog logWithMessage:@"RateLimit is active for all envelope items." andLevel:kSentryLogLevelDebug];
        return;
    }
    
    NSError *requestError = nil;
    // TODO: We do multiple serializations here, we can improve this
    NSURLRequest *request = [self createEnvelopeRequest:envelope didFailWithError:requestError];
    
    if (nil != requestError) {
        [SentryLog logWithMessage:requestError.localizedDescription andLevel:kSentryLogLevelError];
        if (completionHandler) {
            completionHandler(requestError);
        }
        return;
    }

    // TODO: We do multiple serializations here, we can improve this
    NSString *storedEnvelopePath = [self.fileManager storeEnvelope:envelope];

    [self sendRequest:request storedPath:storedEnvelopePath envelope:envelope  completionHandler:completionHandler];
}

#pragma mark private methods

- (void)setupQueueing {
    self.shouldQueueEvent = ^BOOL(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
        // Taken from Apple Docs:
        // If a response from the server is received, regardless of whether the
        // request completes successfully or fails, the response parameter
        // contains that information.
        if (response == nil) {
            // In case response is nil, we want to queue the event locally since
            // this indicates no internet connection
            return YES;
        }
        // In all other cases we don't want to retry sending it and just discard the event
        return NO;
    };
}

- (NSURLRequest *)createEnvelopeRequest:(SentryEnvelope *)envelope
                        didFailWithError:(NSError *_Nullable)error {
    return [[SentryNSURLRequest alloc]
            initEnvelopeRequestWithDsn:self.options.dsn
            andData:[SentrySerialization dataWithEnvelope:envelope options:0 error:&error]
            didFailWithError:&error];
}

- (void)sendRequest:(NSURLRequest *)request
storedPath:(NSString *)storedPath
envelope:(SentryEnvelope *)envelope
completionHandler:(_Nullable SentryRequestFinished)completionHandler {
    __block SentryHttpTransport *_self = self;
    [self sendRequest:request withCompletionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
        if (self.shouldQueueEvent == nil || self.shouldQueueEvent(response, error) == NO) {
            // don't need to queue this -> it most likely got sent
            // thus we can remove the event from disk
            [_self.fileManager removeFileAtPath:storedPath];
            if (nil == error) {
                [_self sendCachedEventsAndEnvelopes];
            }
        }
        if (completionHandler) {
            completionHandler(error);
        }
    }];
}

- (void)sendRequest:(NSURLRequest *)request withCompletionHandler:(_Nullable SentryRequestOperationFinished)completionHandler {
    __block SentryHttpTransport *_self = self;
    [self.requestManager addRequest:request
                  completionHandler:^(NSHTTPURLResponse * _Nullable response, NSError * _Nullable error) {
        [_self.rateLimits update:response];
        if (completionHandler) {
            completionHandler(response, error);
        }
    }];
}

/**
 * validation for `sendEvent:...`
 *
 * @return BOOL NO if options.enabled = false or rate limit exceeded
 */
- (BOOL)isReadyToSend:(NSString *_Nonnull)category {
    if (![self.options.enabled boolValue]) {
        [SentryLog logWithMessage:@"SentryClient is disabled. (options.enabled = false)" andLevel:kSentryLogLevelDebug];
        return NO;
    }

    if ([self.rateLimits isRateLimitActive:category]) {
        return NO;
    }
    return YES;
}

// TODO: This has to move somewhere else, we are missing the whole beforeSend flow
- (void)sendCachedEventsAndEnvelopes {
    if (![self.requestManager isReady]) {
        return;
    }
    
    [self sendAllCachedEvents];
    [self sendAllCachedEnvelopes];
}

- (void)sendAllCachedEvents {
    for (SentryFileContents *fileContents in [self.fileManager getAllEventsAndMaybeEnvelopes]) {
        // The fileContents don't give insights on the event type. We would have
        // to deserialize the contents, which is unnecessary at the moment, because
        // we classify every event with the same category. We still call
        // SentryRateLimitCategoryMapper to keep the code stable if the category
        // for event changes.
        NSString *category = [SentryRateLimitCategoryMapper mapEventTypeToCategory:SentryEnvelopeItemTypeEvent];
        if (![self isReadyToSend:category]) {
            [self.fileManager removeFileAtPath:fileContents.path];
        } else {
            NSURLRequest *request = [[SentryNSURLRequest alloc]
            initStoreRequestWithDsn:self.options.dsn
            andData:fileContents.contents
            didFailWithError:nil];
            [self sendCached:request withFilePath:fileContents.path];
        }
    }
}

- (void)sendAllCachedEnvelopes {
    for (SentryFileContents *fileContents in [self.fileManager getAllEnvelopes]) {
        SentryEnvelope *envelope = [SentrySerialization envelopeWithData:fileContents.contents];
        if (nil == envelope) {
            [self.fileManager removeFileAtPath:fileContents.path];
            continue;
        }
        
        SentryEnvelope *rateLimitedEnvelope = [self.envelopeRateLimit removeRateLimitedItems:envelope];
        if (rateLimitedEnvelope.items.count == 0) {
            [self.fileManager removeFileAtPath:fileContents.path];
            continue;
        }
        
        NSError *requestError = nil;
        NSURLRequest *request = [self createEnvelopeRequest:envelope didFailWithError:requestError];
        
        if (nil != requestError) {
            [SentryLog logWithMessage:requestError.localizedDescription andLevel:kSentryLogLevelError];
            [self.fileManager removeFileAtPath:fileContents.path];
            continue;
        } else {
            [self sendCached:request withFilePath:fileContents.path];
        }
    }
}

- (void)sendCached:(NSURLRequest *)request withFilePath:(NSString *)filePath {
    [self sendRequest:request withCompletionHandler:^(NSHTTPURLResponse *_Nullable response, NSError *_Nullable error) {
        // TODO: How does beforeSend work here
        
        // If the response is not nil we had an internet connection.
        // We don't worry about errors here.
        if (nil != response) {
            [self.fileManager removeFileAtPath:filePath];
        }
    }];
}

@end
