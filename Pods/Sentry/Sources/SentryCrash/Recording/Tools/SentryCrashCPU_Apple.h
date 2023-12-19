// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashCPU_Apple.h
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

#ifndef HDR_SentryCrashCPU_Apple_h
#define HDR_SentryCrashCPU_Apple_h

#ifdef __cplusplus
extern "C" {
#endif

#include <mach/mach_types.h>

/** Fill in state information about a thread.
 *
 * @param thread The thread to get information about.
 *
 * @param state Pointer to buffer for state information.
 *
 * @param flavor The kind of information to get (arch specific).
 *
 * @param stateCount Number of entries in the state information buffer.
 *
 * @return true if state fetching was successful.
 */
bool sentrycrashcpu_i_fillState(thread_t thread, thread_state_t state, thread_state_flavor_t flavor,
    mach_msg_type_number_t stateCount);

#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashCPU_Apple_h
