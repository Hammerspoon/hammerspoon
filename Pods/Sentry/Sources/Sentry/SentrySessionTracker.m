#import "SentryHub.h"
#import "SentrySDK.h"
#import "SentrySessionTracker.h"
#import "SentryOptions.h"
#import "SentryLog.h"

#if SENTRY_HAS_UIKIT
#import <UIKit/UIKit.h>
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
#import <Cocoa/Cocoa.h>
#endif

@interface SentrySessionTracker ()

@property(nonatomic, strong) SentryOptions *options;
@property(atomic, strong) NSDate *lastInForeground;

@end

@implementation SentrySessionTracker

- (instancetype)initWithOptions:(SentryOptions *)options {
    if (self = [super init]) {
        self.options = options;
    }
    return self;
}

- (void)start {
__block id blockSelf = self;
#if SENTRY_HAS_UIKIT
NSNotificationName foregroundNotificationName = UIApplicationDidBecomeActiveNotification;
NSNotificationName backgroundNotificationName = UIApplicationWillResignActiveNotification;
#elif TARGET_OS_OSX || TARGET_OS_MACCATALYST
NSNotificationName foregroundNotificationName = NSApplicationDidBecomeActiveNotification;
NSNotificationName backgroundNotificationName = NSApplicationWillResignActiveNotification;
#else
    [SentryLog logWithMessage:@"NO UIKit -> SentrySessionTracker will not track sessions automatically." andLevel:kSentryLogLevelDebug];
#endif
    
#if SENTRY_HAS_UIKIT || TARGET_OS_OSX || TARGET_OS_MACCATALYST
    SentryHub *hub = [SentrySDK currentHub];
    [hub closeCachedSession];
    [hub startSession];
    [NSNotificationCenter.defaultCenter addObserverForName:foregroundNotificationName
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *notification) {
                                                    [blockSelf didBecomeActive];
                                                }];
    [NSNotificationCenter.defaultCenter addObserverForName:backgroundNotificationName
                                                    object:nil
                                                     queue:nil
                                                usingBlock:^(NSNotification *notification) {
                                                    [blockSelf willResignActive];
                                                }];
#endif
}

- (void)didBecomeActive {
    NSDate *from = nil == self.lastInForeground ? [NSDate date] : self.lastInForeground;
    NSTimeInterval secondsInBackground = [[NSDate date] timeIntervalSinceDate:from];
    if (secondsInBackground * 1000 > (double)(self.options.sessionTrackingIntervalMillis)) {
        SentryHub *hub = [SentrySDK currentHub];
        [hub endSessionWithTimestamp:from];
        [hub startSession];
    }
    self.lastInForeground = nil;
}

- (void)willResignActive {
    self.lastInForeground = [NSDate date];
}

@end
