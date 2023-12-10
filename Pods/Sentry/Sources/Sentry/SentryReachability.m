//
//  SentryReachability.m
//
//  Created by Jamie Lynch on 2017-09-04.
//
//  Copyright (c) 2017 Bugsnag, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "SentryReachability.h"

#if !TARGET_OS_WATCH

static const SCNetworkReachabilityFlags kSCNetworkReachabilityFlagsUninitialized = UINT32_MAX;

static SCNetworkReachabilityRef sentry_reachability_ref;
static NSMutableDictionary<NSString *, SentryConnectivityChangeBlock>
    *sentry_reachability_change_blocks;
static SCNetworkReachabilityFlags sentry_current_reachability_state
    = kSCNetworkReachabilityFlagsUninitialized;

static NSString *const SentryConnectivityCellular = @"cellular";
static NSString *const SentryConnectivityWiFi = @"wifi";
static NSString *const SentryConnectivityNone = @"none";

/**
 * Check whether the connectivity change should be noted or ignored.
 *
 * @return YES if the connectivity change should be reported
 */
BOOL
SentryConnectivityShouldReportChange(SCNetworkReachabilityFlags flags)
{
#    if SENTRY_HAS_UIDEVICE
    // kSCNetworkReachabilityFlagsIsWWAN does not exist on macOS
    const SCNetworkReachabilityFlags importantFlags
        = kSCNetworkReachabilityFlagsIsWWAN | kSCNetworkReachabilityFlagsReachable;
#    else
    const SCNetworkReachabilityFlags importantFlags = kSCNetworkReachabilityFlagsReachable;
#    endif
    __block BOOL shouldReport = YES;
    // Check if the reported state is different from the last known state (if any)
    SCNetworkReachabilityFlags newFlags = flags & importantFlags;
    SCNetworkReachabilityFlags oldFlags = sentry_current_reachability_state & importantFlags;
    if (newFlags != oldFlags) {
        // When first subscribing to be notified of changes, the callback is
        // invoked immmediately even if nothing has changed. So this block
        // ignores the very first check, reporting all others.
        if (sentry_current_reachability_state == kSCNetworkReachabilityFlagsUninitialized) {
            shouldReport = NO;
        }
        // Cache the reachability state to report the previous value representation
        sentry_current_reachability_state = flags;
    } else {
        shouldReport = NO;
    }
    return shouldReport;
}

/**
 * Textual representation of a connection type
 */
NSString *
SentryConnectivityFlagRepresentation(SCNetworkReachabilityFlags flags)
{
    BOOL connected = (flags & kSCNetworkReachabilityFlagsReachable) != 0;
#    if SENTRY_HAS_UIDEVICE
    return connected ? ((flags & kSCNetworkReachabilityFlagsIsWWAN) ? SentryConnectivityCellular
                                                                    : SentryConnectivityWiFi)
                     : SentryConnectivityNone;
#    else
    return connected ? SentryConnectivityWiFi : SentryConnectivityNone;
#    endif
}

/**
 * Callback invoked by SCNetworkReachability, which calls an Objective-C block
 * that handles the connection change.
 */
void
SentryConnectivityCallback(
    __unused SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, __unused void *info)
{
    if (sentry_reachability_change_blocks && SentryConnectivityShouldReportChange(flags)) {
        BOOL connected = (flags & kSCNetworkReachabilityFlagsReachable) != 0;

        for (SentryConnectivityChangeBlock block in sentry_reachability_change_blocks.allValues) {
            block(connected, SentryConnectivityFlagRepresentation(flags));
        }
    }
}

#endif

@implementation SentryReachability

#if !TARGET_OS_WATCH

+ (void)initialize
{
    if (self == [SentryReachability class]) {
        sentry_reachability_change_blocks = [NSMutableDictionary new];
    }
}

- (void)dealloc
{
    [self stopMonitoring];
}

- (void)monitorURL:(NSURL *)URL usingCallback:(SentryConnectivityChangeBlock)block
{
    static dispatch_once_t once_t;
    static dispatch_queue_t reachabilityQueue;
    dispatch_once(&once_t, ^{
        reachabilityQueue
            = dispatch_queue_create("io.sentry.cocoa.connectivity", DISPATCH_QUEUE_SERIAL);
    });

    sentry_reachability_change_blocks[[self keyForInstance]] = block;

    const char *nodename = URL.host.UTF8String;
    if (!nodename) {
        return;
    }

    sentry_reachability_ref = SCNetworkReachabilityCreateWithName(NULL, nodename);
    if (sentry_reachability_ref) { // Can be null if a bad hostname was specified
        SCNetworkReachabilitySetCallback(sentry_reachability_ref, SentryConnectivityCallback, NULL);
        SCNetworkReachabilitySetDispatchQueue(sentry_reachability_ref, reachabilityQueue);
    }
}

- (void)stopMonitoring
{
    [sentry_reachability_change_blocks removeObjectForKey:[self keyForInstance]];
    if (sentry_reachability_ref) {
        SCNetworkReachabilitySetCallback(sentry_reachability_ref, NULL, NULL);
        SCNetworkReachabilitySetDispatchQueue(sentry_reachability_ref, NULL);
    }
    sentry_current_reachability_state = kSCNetworkReachabilityFlagsUninitialized;
}

- (NSString *)keyForInstance
{
    return [self description];
}

#endif

@end
