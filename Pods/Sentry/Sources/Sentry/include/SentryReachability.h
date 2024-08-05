// Adapted from
// https://github.com/bugsnag/bugsnag-cocoa/blob/2f373f21b965f1b13d7070662e2d35f46c17d975/Bugsnag/Delivery/BSGConnectivity.h
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

#import "SentryDefines.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_REACHABILITY
#    import <SystemConfiguration/SystemConfiguration.h>

NS_ASSUME_NONNULL_BEGIN

void SentryConnectivityCallback(SCNetworkReachabilityFlags flags);

#    if defined(TEST) || defined(TESTCI) || defined(DEBUG)
/**
 * Needed for testing.
 */
void SentrySetReachabilityIgnoreActualCallback(BOOL value);

#    endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)

NSString *SentryConnectivityFlagRepresentation(SCNetworkReachabilityFlags flags);

BOOL SentryConnectivityShouldReportChange(SCNetworkReachabilityFlags flags);

SENTRY_EXTERN NSString *const SentryConnectivityCellular;
SENTRY_EXTERN NSString *const SentryConnectivityWiFi;
SENTRY_EXTERN NSString *const SentryConnectivityNone;

@protocol SentryReachabilityObserver <NSObject>

/**
 * Called when network connectivity changes.
 *
 * @param connected @c YES if the monitored URL is reachable
 * @param typeDescription a textual representation of the connection type
 */
- (void)connectivityChanged:(BOOL)connected typeDescription:(NSString *)typeDescription;

@end

/**
 * Monitors network connectivity using @c SCNetworkReachability callbacks,
 * providing a customizable callback block invoked when connectivity changes.
 */
@interface SentryReachability : NSObject

#    if defined(TEST) || defined(TESTCI) || defined(DEBUG)

/**
 * Only needed for testing. Use this flag to skip registering and unregistering the actual callbacks
 * to SCNetworkReachability to minimize side effects.
 */
@property (nonatomic, assign) BOOL skipRegisteringActualCallbacks;

#    endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)

/**
 * Add an observer which is called each time network connectivity changes.
 */
- (void)addObserver:(id<SentryReachabilityObserver>)observer;

/**
 * Stop monitoring the URL previously configured with @c monitorURL:usingCallback:
 */
- (void)removeObserver:(id<SentryReachabilityObserver>)observer;

- (void)removeAllObservers;

@end

NS_ASSUME_NONNULL_END

#endif // !TARGET_OS_WATCH
