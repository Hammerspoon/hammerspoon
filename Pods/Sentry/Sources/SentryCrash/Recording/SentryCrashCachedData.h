// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashCachedData.h
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

/* Maintains a cache of difficult-to-retrieve data.
 */

#include "SentryCrashThread.h"

void sentrycrashccd_init(int pollingIntervalInSeconds);
void sentrycrashccd_close(void);
bool sentrycrashccd_hasThreadStarted(void);

void sentrycrashccd_freeze(void);
void sentrycrashccd_unfreeze(void);

SentryCrashThread *sentrycrashccd_getAllThreads(int *threadCount);

const char *sentrycrashccd_getThreadName(SentryCrashThread thread);

const char *sentrycrashccd_getQueueName(SentryCrashThread thread);
