// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashMonitorType.c
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

#include "SentryCrashMonitorType.h"

#include <stdlib.h>

static const struct {
    const SentryCrashMonitorType type;
    const char *const name;
} g_monitorTypes[] = {
#define MONITORTYPE(NAME) { NAME, #NAME }
    MONITORTYPE(SentryCrashMonitorTypeMachException),
    MONITORTYPE(SentryCrashMonitorTypeSignal),
    MONITORTYPE(SentryCrashMonitorTypeCPPException),
    MONITORTYPE(SentryCrashMonitorTypeNSException),
    MONITORTYPE(SentryCrashMonitorTypeSystem),
    MONITORTYPE(SentryCrashMonitorTypeApplicationState),
};
static const int g_monitorTypesCount = sizeof(g_monitorTypes) / sizeof(*g_monitorTypes);

const char *
sentrycrashmonitortype_name(const SentryCrashMonitorType monitorType)
{
    for (int i = 0; i < g_monitorTypesCount; i++) {
        if (g_monitorTypes[i].type == monitorType) {
            return g_monitorTypes[i].name;
        }
    }
    return NULL;
}
