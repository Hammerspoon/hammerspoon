//
//  SentryCrashCPU.h
//
//  Created by Karl Stenerud on 2012-01-29.
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


#include "SentryCrashCPU.h"

#include "SentryCrashSystemCapabilities.h"

#include <mach/mach.h>
#include <mach-o/arch.h>

//#define SentryCrashLogger_LocalLevel TRACE
#include "SentryCrashLogger.h"


const char* sentrycrashcpu_currentArch(void)
{
    const NXArchInfo* archInfo = NXGetLocalArchInfo();
    return archInfo == NULL ? NULL : archInfo->name;
}

#if SentryCrashCRASH_HAS_THREADS_API
bool sentrycrashcpu_i_fillState(const thread_t thread,
                       const thread_state_t state,
                       const thread_state_flavor_t flavor,
                       const mach_msg_type_number_t stateCount)
{
    SentryCrashLOG_TRACE("Filling thread state with flavor %x.", flavor);
    mach_msg_type_number_t stateCountBuff = stateCount;
    kern_return_t kr;

    kr = thread_get_state(thread, flavor, state, &stateCountBuff);
    if(kr != KERN_SUCCESS)
    {
        SentryCrashLOG_ERROR("thread_get_state: %s", mach_error_string(kr));
        return false;
    }
    return true;
}
#else
bool sentrycrashcpu_i_fillState(__unused const thread_t thread,
                       __unused const thread_state_t state,
                       __unused const thread_state_flavor_t flavor,
                       __unused const mach_msg_type_number_t stateCount)
{
    return false;
}

#endif
