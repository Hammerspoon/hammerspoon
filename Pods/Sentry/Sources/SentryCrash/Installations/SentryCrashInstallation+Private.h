// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashReportFieldProperties.h
//
//  Created by Karl Stenerud on 2013-02-10.
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

#import "SentryCrashInstallation.h"

typedef struct {
    const char *key;
    const char *value;
} ReportField;

typedef struct {
    SentryCrashReportWriteCallback userCrashCallback;
    int reportFieldsCount;
    ReportField *reportFields[0];
} CrashHandlerData;

@interface
SentryCrashInstallation ()

/** Initializer.
 *
 * @param requiredProperties Properties that MUST be set when sending reports.
 */
- (id)initWithRequiredProperties:(NSArray *)requiredProperties;

/** Create a new sink. Subclasses must implement this.
 */
- (id<SentryCrashReportFilter>)sink;

/** Make an absolute key path if the specified path is not already absolute. */
- (NSString *)makeKeyPath:(NSString *)keyPath;

/** Make an absolute key paths from the specified paths. */
- (NSArray *)makeKeyPaths:(NSArray *)keyPaths;

/** Only needed for testing */
- (CrashHandlerData *)g_crashHandlerData;

@end
