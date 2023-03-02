//
//  SentryReachability.h
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

#import <Foundation/Foundation.h>

#if !TARGET_OS_WATCH
#    import <SystemConfiguration/SystemConfiguration.h>

NS_ASSUME_NONNULL_BEGIN

void SentryConnectivityCallback(
    SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *_Nullable);

NSString *SentryConnectivityFlagRepresentation(SCNetworkReachabilityFlags flags);

BOOL SentryConnectivityShouldReportChange(SCNetworkReachabilityFlags flags);

#endif

/**
 * Function signature to connectivity monitoring callback of SentryReachability
 *
 * @param connected YES if the monitored URL is reachable
 * @param typeDescription a textual representation of the connection type
 */
typedef void (^SentryConnectivityChangeBlock)(BOOL connected, NSString *typeDescription);

/**
 * Monitors network connectivity using SCNetworkReachability callbacks,
 * providing a customizable callback block invoked when connectivity changes.
 */
@interface SentryReachability : NSObject

#if !TARGET_OS_WATCH
/**
 * Invoke a block each time network connectivity changes
 *
 * @param URL   The URL monitored for changes. Should be equivalent to
 *              BugsnagConfiguration.notifyURL
 * @param block The block called when connectivity changes
 */
- (void)monitorURL:(NSURL *)URL usingCallback:(SentryConnectivityChangeBlock)block;

/**
 * Stop monitoring the URL previously configured with monitorURL:usingCallback:
 */
- (void)stopMonitoring;

- (NSString *)keyForInstance;

#endif

@end

#if !TARGET_OS_WATCH
NS_ASSUME_NONNULL_END
#endif
