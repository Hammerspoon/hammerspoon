// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashReportFilter.h
//
//  Created by Karl Stenerud on 2012-02-18.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
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

/** Callback for filter operations.
 *
 * @param filteredReports The filtered reports (may be incomplete if "completed"
 *                        is false).
 * @param completed True if filtering completed.
 *                  Can be false due to a non-erroneous condition (such as a
 *                  user cancelling the operation).
 * @param error Non-nil if an error occurred.
 */
typedef void (^SentryCrashReportFilterCompletion)(
    NSArray *filteredReports, BOOL completed, NSError *error);

/**
 * A filter receives a set of reports, possibly transforms them, and then
 * calls a completion method.
 */
@protocol SentryCrashReportFilter <NSObject>

/** Filter the specified reports.
 *
 * @param reports The reports to process.
 * @param onCompletion Block to call when processing is complete.
 */
- (void)filterReports:(NSArray *)reports
         onCompletion:(SentryCrashReportFilterCompletion)onCompletion;

@end

/** Conditionally call a completion method if it's not nil.
 *
 * @param onCompletion The completion block. If nil, this function does nothing.
 * @param filteredReports The parameter to send as "filteredReports".
 * @param completed The parameter to send as "completed".
 * @param error The parameter to send as "error".
 */
static inline void
sentrycrash_callCompletion(SentryCrashReportFilterCompletion onCompletion, NSArray *filteredReports,
    BOOL completed, NSError *error)
{
    if (onCompletion) {
        onCompletion(filteredReports, completed, error);
    }
}
